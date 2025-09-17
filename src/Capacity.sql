SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableCapacity bit;

	SET @enableCapacity = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing Capacity', 0, 1) WITH NOWAIT;
END;

--
-- Declare variables
--
BEGIN
	DECLARE @edition nvarchar(128);
	DECLARE @myUserName nvarchar(128);
	DECLARE @nowUTC datetime;
	DECLARE @nowUTCStr nvarchar(128);
	DECLARE @objectName nvarchar(128);
	DECLARE @objName nvarchar(128);
	DECLARE @pbiSchema nvarchar(128);
	DECLARE @productEndPos int;
	DECLARE @productStartPos int;
	DECLARE @productVersion nvarchar(128);
	DECLARE @productVersion1 int;
	DECLARE @productVersion2 int;
	DECLARE @productVersion3 int;
	DECLARE @returnValue int;
	DECLARE @schName nvarchar(128);
	DECLARE @stmt nvarchar(max);
	DECLARE @tableCompressionStmt nvarchar(max);
	DECLARE @version nvarchar(128);
END;

--
-- Test if we are in a database with FHSM registered
--
BEGIN
	SET @returnValue = 0;

	IF OBJECT_ID('dbo.fhsmFNIsValidInstallation') IS NOT NULL
	BEGIN
		SET @returnValue = dbo.fhsmFNIsValidInstallation();
	END;
END;

IF (@returnValue = 0)
BEGIN
	RAISERROR('Can not install as it appears the database is not correct installed', 0, 1) WITH NOWAIT;
END
ELSE BEGIN
	--
	-- Initialize variables
	--
	BEGIN
		SET @myUserName = SUSER_NAME();
		SET @nowUTC = SYSUTCDATETIME();
		SET @nowUTCStr = CONVERT(nvarchar(128), @nowUTC, 126);
		SET @pbiSchema = dbo.fhsmFNGetConfiguration('PBISchema');
		SET @version = '2.11.0';

		SET @productVersion = CAST(SERVERPROPERTY('ProductVersion') AS nvarchar);
		SET @productStartPos = 1;
		SET @productEndPos = CHARINDEX('.', @productVersion, @productStartPos);
		SET @productVersion1 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));
		SET @productStartPos = @productEndPos + 1;
		SET @productEndPos = CHARINDEX('.', @productVersion, @productStartPos);
		SET @productVersion2 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));
		SET @productStartPos = @productEndPos + 1;
		SET @productEndPos = CHARINDEX('.', @productVersion, @productStartPos);
		SET @productVersion3 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));
	END;

	--
	-- Check if SQL is 2008
	--
	IF ((@productVersion1 = 10) AND (@productVersion2 = 0))
	BEGIN
		RAISERROR('!!!', 0, 1) WITH NOWAIT;
		RAISERROR('!!! Can not install the Disk size part on SQL version SQL2008', 0, 1) WITH NOWAIT;
		RAISERROR('!!!', 0, 1) WITH NOWAIT;
	END;

	--
	-- Check if SQL is lower than 2016 SP2
	--
	IF
		(@productVersion1 < 13)
		OR ((@productVersion1 = 13) AND (@productVersion2 = 0) AND (@productVersion3 < 5026))
	BEGIN
		RAISERROR('!!!', 0, 1) WITH NOWAIT;
		RAISERROR('!!! Can not install the VLF part on SQL versions lower than SQL2016 SP2', 0, 1) WITH NOWAIT;
		RAISERROR('!!!', 0, 1) WITH NOWAIT;
	END;

	--
	-- Check if SQL version allows to use data compression
	--
	BEGIN
		SET @tableCompressionStmt = '';

		SET @edition = CAST(SERVERPROPERTY('Edition') AS nvarchar);

		IF (@edition = 'SQL Azure')
			OR (SUBSTRING(@edition, 1, CHARINDEX(' ', @edition)) = 'Developer')
			OR (SUBSTRING(@edition, 1, CHARINDEX(' ', @edition)) = 'Enterprise')
			OR (@productVersion1 > 13)
			OR ((@productVersion1 = 13) AND (@productVersion2 >= 1))
			OR ((@productVersion1 = 13) AND (@productVersion2 = 0) AND (@productVersion3 >= 4001))
		BEGIN
			SET @tableCompressionStmt = ' WITH (DATA_COMPRESSION = PAGE)';
		END;
	END;

	--
	-- The services 'Database size', 'Partitioned indexes', and 'Table size' will be marked as disabled and deprecated as this Capacity service takes over
	--
	BEGIN
		UPDATE s
		SET
			s.Enabled = 0,
			s.DeploymentStatus = -1
		FROM dbo.fhsmSchedules AS s
		WHERE (s.Name IN ('Database size', 'Partitioned indexes', 'Table size'))
			AND ((s.Enabled <> 0) OR (s.DeploymentStatus <> -1));
	END;

	--
	-- Create tables
	--
	BEGIN
		--
		-- Create table dbo.fhsmAllocationUnits and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmAllocationUnits', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmAllocationUnits', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmAllocationUnits(
						Id int identity(1,1) NOT NULL
						,DatabaseName nvarchar(128) NOT NULL
						,FilegroupName sysname NOT NULL
						,SchemaName sysname NOT NULL
						,ObjectName sysname NOT NULL
						,IndexName sysname NULL
						,PartitionNumber int NOT NULL
						,AllocationUnitType tinyint NOT NULL
						,TotalPages bigint NULL
						,UsedPages bigint NULL
						,DataPages bigint NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmAllocationUnits PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAllocationUnits')) AND (i.name = 'NC_fhsmAllocationUnits_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAllocationUnits_TimestampUTC] to table dbo.fhsmAllocationUnits', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAllocationUnits_TimestampUTC ON dbo.fhsmAllocationUnits(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAllocationUnits')) AND (i.name = 'NC_fhsmAllocationUnits_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAllocationUnits_Timestamp] to table dbo.fhsmAllocationUnits', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAllocationUnits_Timestamp ON dbo.fhsmAllocationUnits(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmAllocationUnits
			--
			BEGIN
				SET @objectName = 'dbo.fhsmAllocationUnits';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create table dbo.fhsmDatabaseSize and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmDatabaseSize', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmDatabaseSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmDatabaseSize(
						Id int identity(1,1) NOT NULL
						,DatabaseName nvarchar(128) NOT NULL
						,LogicalName nvarchar(128) NOT NULL
						,PhysicalName nvarchar(260) NULL
						,Type tinyint NOT NULL
						,VolumeMountPoint nvarchar(512) NULL
						,LogicalVolumeName nvarchar(512) NULL
						,FilegroupName nvarchar(128) NULL
						,FileGroupType char(2) NULL
						,CurrentSize int NOT NULL
						,UsedSize int NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmDatabaseSize PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			--
			-- Adding column PhysicalName to table dbo.fhsmDatabaseSize if it not already exists
			--
			IF NOT EXISTS (SELECT * FROM sys.columns AS c WHERE (c.object_id = OBJECT_ID('dbo.fhsmDatabaseSize')) AND (c.name = 'PhysicalName'))
			BEGIN
				RAISERROR('Adding column [PhysicalName] to table dbo.fhsmDatabaseSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					ALTER TABLE dbo.fhsmDatabaseSize
						ADD PhysicalName nvarchar(260) NULL;
				';
				EXEC(@stmt);
			END;

			--
			-- Adding column VolumeMountPoint to table dbo.fhsmDatabaseSize if it not already exists
			--
			IF NOT EXISTS (SELECT * FROM sys.columns AS c WHERE (c.object_id = OBJECT_ID('dbo.fhsmDatabaseSize')) AND (c.name = 'VolumeMountPoint'))
			BEGIN
				RAISERROR('Adding column [VolumeMountPoint] to table dbo.fhsmDatabaseSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					ALTER TABLE dbo.fhsmDatabaseSize
						ADD VolumeMountPoint nvarchar(512) NULL;
				';
				EXEC(@stmt);
			END;

			--
			-- Adding column LogicalVolumeName to table dbo.fhsmDatabaseSize if it not already exists
			--
			IF NOT EXISTS (SELECT * FROM sys.columns AS c WHERE (c.object_id = OBJECT_ID('dbo.fhsmDatabaseSize')) AND (c.name = 'LogicalVolumeName'))
			BEGIN
				RAISERROR('Adding column [LogicalVolumeName] to table dbo.fhsmDatabaseSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					ALTER TABLE dbo.fhsmDatabaseSize
						ADD LogicalVolumeName nvarchar(512) NULL;
				';
				EXEC(@stmt);
			END;

			--
			-- Adding column FilegroupName to table dbo.fhsmDatabaseSize if it not already exists
			--
			IF NOT EXISTS (SELECT * FROM sys.columns AS c WHERE (c.object_id = OBJECT_ID('dbo.fhsmDatabaseSize')) AND (c.name = 'FilegroupName'))
			BEGIN
				RAISERROR('Adding column [FilegroupName] to table dbo.fhsmDatabaseSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					ALTER TABLE dbo.fhsmDatabaseSize
						ADD FilegroupName nvarchar(128) NULL;
				';
				EXEC(@stmt);
			END;

			--
			-- Adding column FileGroupType to table dbo.fhsmDatabaseSize if it not already exists
			--
			IF NOT EXISTS (SELECT * FROM sys.columns AS c WHERE (c.object_id = OBJECT_ID('dbo.fhsmDatabaseSize')) AND (c.name = 'FileGroupType'))
			BEGIN
				RAISERROR('Adding column [FileGroupType] to table dbo.fhsmDatabaseSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					ALTER TABLE dbo.fhsmDatabaseSize
						ADD FileGroupType char(2) NULL;
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmDatabaseSize')) AND (i.name = 'NC_fhsmDatabaseSize_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmDatabaseSize_TimestampUTC] to table dbo.fhsmDatabaseSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmDatabaseSize_TimestampUTC ON dbo.fhsmDatabaseSize(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmDatabaseSize')) AND (i.name = 'NC_fhsmDatabaseSize_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmDatabaseSize_Timestamp] to table dbo.fhsmDatabaseSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmDatabaseSize_Timestamp ON dbo.fhsmDatabaseSize(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmDatabaseSize')) AND (i.name = 'NC_fhsmDatabaseSize_DatabaseName_LogicalName_Type'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmDatabaseSize_DatabaseName_LogicalName_Type] to table dbo.fhsmDatabaseSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmDatabaseSize_DatabaseName_LogicalName_Type ON dbo.fhsmDatabaseSize(DatabaseName, LogicalName, Type)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmDatabaseSize
			--
			BEGIN
				SET @objectName = 'dbo.fhsmDatabaseSize';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create table dbo.fhsmDiskSize and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmDiskSize', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmDiskSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmDiskSize(
						Id int identity(1,1) NOT NULL
						,VolumeMountPoint nvarchar(512) NULL
						,LogicalVolumeName nvarchar(512) NULL
						,FileSystemType nvarchar(512) NULL
						,TotalBytes bigint NOT NULL
						,FreeBytes bigint NOT NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmDiskSize PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmDiskSize')) AND (i.name = 'NC_fhsmDiskSize_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmDiskSize_TimestampUTC] to table dbo.fhsmDiskSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmDiskSize_TimestampUTC ON dbo.fhsmDiskSize(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmDiskSize')) AND (i.name = 'NC_fhsmDiskSize_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmDiskSize_Timestamp] to table dbo.fhsmDiskSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmDiskSize_Timestamp ON dbo.fhsmDiskSize(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmDiskSize
			--
			BEGIN
				SET @objectName = 'dbo.fhsmDiskSize';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create table dbo.fhsmPartitionedIndexes and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmPartitionedIndexes', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmPartitionedIndexes', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmPartitionedIndexes(
						Id int identity(1,1) NOT NULL
						,DatabaseName nvarchar(128) NOT NULL
						,SchemaName nvarchar(128) NOT NULL
						,ObjectName nvarchar(128) NOT NULL
						,IndexName nvarchar(128) NULL
						,IndexTypeDesc nvarchar(60) NOT NULL
						,PartitionSchemeName nvarchar(128) NOT NULL
						,PartitionFilegroupName nvarchar(128) NOT NULL
						,PartitionFunctionName nvarchar(128) NOT NULL
						,PartitionFunctionValueOnRight bit NOT NULL
						,PartitionFunctionCreateDate datetime NOT NULL
						,PartitionFunctionModifyDate datetime NOT NULL
						,PartitionBoundaryValue sql_variant NULL
						,PartitionColumn nvarchar(128) NOT NULL
						,PartitionNumber int NOT NULL
						,PartitionCompressionTypeDesc nvarchar(60) NOT NULL
						,PartitionRowCount bigint NOT NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmPartitionedIndexes PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmPartitionedIndexes')) AND (i.name = 'NC_fhsmPartitionedIndexes_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmPartitionedIndexes_TimestampUTC] to table dbo.fhsmPartitionedIndexes', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmPartitionedIndexes_TimestampUTC ON dbo.fhsmPartitionedIndexes(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmPartitionedIndexes')) AND (i.name = 'NC_fhsmPartitionedIndexes_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmPartitionedIndexes_Timestamp] to table dbo.fhsmPartitionedIndexes', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmPartitionedIndexes_Timestamp ON dbo.fhsmPartitionedIndexes(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmPartitionedIndexes')) AND (i.name = 'NC_fhsmPartitionedIndexes_DatabaseName'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmPartitionedIndexes_DatabaseName] to table dbo.fhsmPartitionedIndexes', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmPartitionedIndexes_DatabaseName ON dbo.fhsmPartitionedIndexes(DatabaseName)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmPartitionedIndexes
			--
			BEGIN
				SET @objectName = 'dbo.fhsmPartitionedIndexes';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create table dbo.fhsmTableSize and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmTableSize', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmTableSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmTableSize(
						Id int identity(1,1) NOT NULL
						,DatabaseName nvarchar(128) NOT NULL
						,SchemaName nvarchar(128) NOT NULL
						,ObjectName nvarchar(128) NOT NULL
						,IndexName nvarchar(128) NULL
						,PartitionNumber int NOT NULL
						,IsMemoryOptimized bit NOT NULL
						,Rows bigint NOT NULL
						,Reserved int NULL
						,Data int NULL
						,IndexSize int NULL
						,Unused int NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmTableSize PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmTableSize')) AND (i.name = 'NC_fhsmTableSize_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmTableSize_TimestampUTC] to table dbo.fhsmTableSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmTableSize_TimestampUTC ON dbo.fhsmTableSize(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmTableSize')) AND (i.name = 'NC_fhsmTableSize_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmTableSize_Timestamp] to table dbo.fhsmTableSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmTableSize_Timestamp ON dbo.fhsmTableSize(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmTableSize')) AND (i.name = 'NC_fhsmTableSize_DatabaseName_SchemaName_ObjectName_IndexName'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmTableSize_DatabaseName_SchemaName_ObjectName_IndexName] to table dbo.fhsmTableSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmTableSize_DatabaseName_SchemaName_ObjectName_IndexName ON dbo.fhsmTableSize(DatabaseName, SchemaName, ObjectName, IndexName)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmTableSize
			--
			BEGIN
				SET @objectName = 'dbo.fhsmTableSize';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create table dbo.fhsmVLFSize and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmVLFSize', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmVLFSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmVLFSize(
						Id int identity(1,1) NOT NULL
						,DatabaseName nvarchar(128) NOT NULL
						,VLFCount int NOT NULL
						,ActiveVLF int NOT NULL
						,VLFSizeMB float NOT NULL
						,ActiveVLFSizeMB float NOT NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmVLFSize PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmVLFSize')) AND (i.name = 'NC_fhsmVLFSize_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmVLFSize_TimestampUTC] to table dbo.fhsmVLFSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmVLFSize_TimestampUTC ON dbo.fhsmVLFSize(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmVLFSize')) AND (i.name = 'NC_fhsmVLFSize_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmVLFSize_Timestamp] to table dbo.fhsmVLFSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmVLFSize_Timestamp ON dbo.fhsmVLFSize(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmVLFSize')) AND (i.name = 'NC_fhsmVLFSize_DatabaseName'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmVLFSize_DatabaseName] to table dbo.fhsmVLFSize', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmVLFSize_DatabaseName ON dbo.fhsmVLFSize(DatabaseName)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmVLFSize
			--
			BEGIN
				SET @objectName = 'dbo.fhsmVLFSize';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;
	END;

	--
	-- Create functions
	--

	--
	-- Create views
	--
	BEGIN
		--
		-- Create fact view @pbiSchema.[Allocation units]
		--
		BEGIN
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Allocation units') + ''', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Allocation units') + ' AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Allocation units') + '
					AS
					SELECT
						au.PartitionNumber
						,CASE au.AllocationUnitType
							WHEN 0 THEN ''Dropped''
							WHEN 1 THEN ''IN_ROW_DATA''
							WHEN 2 THEN ''LOB_DATA''
							WHEN 3 THEN ''ROW_OVERFLOW_DATA''
						END AS AllocationUnitTypeDesc
						,au.TotalPages * 8 AS TotalSpaceKB
						,au.UsedPages * 8 AS UsedSpaceKB
						,au.DataPages * 8 AS DataSpaceKB
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(au.DatabaseName, au.SchemaName,    au.ObjectName, COALESCE(au.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(au.DatabaseName, au.FilegroupName, DEFAULT,       DEFAULT,                          DEFAULT, DEFAULT) AS k) AS FileGroupKey
						FROM dbo.fhsmAllocationUnits AS au
						WHERE
							(au.TimestampUTC = (
								SELECT MAX(au2.TimestampUTC)
								FROM dbo.fhsmAllocationUnits AS au2
							))
							AND (
								(au.TotalPages <> 0)
								OR (au.UsedPages <> 0)
								OR (au.DataPages <> 0)
							);
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on fact view @pbiSchema.[Allocation units]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Allocation units');
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create fact view @pbiSchema.[Database size]
		--
		BEGIN
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database size') + ''', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database size') + ' AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database size') + '
					AS
					SELECT
						ds.CurrentSize
						,ds.UsedSize
						,CAST(ds.Timestamp AS date) AS Date
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ds.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ds.DatabaseName, ds.LogicalName, ds.PhysicalName,
							CASE ds.Type
								WHEN 0 THEN ''Data''
								WHEN 1 THEN ''Log''
								WHEN 2 THEN ''Filestream''
								WHEN 4 THEN ''Fulltext''
								ELSE ''Other''
							END,
						ds.FilegroupName, DEFAULT) AS k) AS DatabaseFileKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ds.VolumeMountPoint, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DiskKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ds.DatabaseName, ds.FilegroupName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS FileGroupKey
					FROM dbo.fhsmDatabaseSize AS ds
					WHERE (ds.Timestamp IN (
						SELECT a.Timestamp
						FROM (
							SELECT
								ds2.Timestamp
								,ROW_NUMBER() OVER(PARTITION BY CAST(ds2.Timestamp AS date) ORDER BY ds2.Timestamp DESC) AS _Rnk_
							FROM dbo.fhsmDatabaseSize AS ds2
						) AS a
						WHERE (a._Rnk_ = 1)
					));
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on fact view @pbiSchema.[Database size]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database size');
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create fact view @pbiSchema.[Disk size]
		--
		BEGIN
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Disk size') + ''', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Disk size') + ' AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Disk size') + '
					AS
					SELECT
						ds.TotalBytes
						,ds.FreeBytes
						,CAST(ds.Timestamp AS date) AS Date
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ds.VolumeMountPoint, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DiskKey
					FROM dbo.fhsmDiskSize AS ds
					WHERE (ds.Timestamp IN (
						SELECT a.Timestamp
						FROM (
							SELECT
								ds2.Timestamp
								,ROW_NUMBER() OVER(PARTITION BY CAST(ds2.Timestamp AS date) ORDER BY ds2.Timestamp DESC) AS _Rnk_
							FROM dbo.fhsmDiskSize AS ds2
						) AS a
						WHERE (a._Rnk_ = 1)
					));
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on fact view @pbiSchema.[Disk size]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Disk size');
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create fact view @pbiSchema.[Partitioned indexes]
		--
		BEGIN
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Partitioned indexes') + ''', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Partitioned indexes') + ' AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Partitioned indexes') + '
					AS
				';
				IF (@productVersion1 <= 10)
				BEGIN
					-- SQL Versions SQL2008R2 or lower

					SET @stmt += '
						WITH partitionedIndexes AS (
							SELECT
								pi.DatabaseName
								,pi.SchemaName 
								,pi.ObjectName
								,pi.IndexName
								,pi.IndexTypeDesc
								,pi.PartitionSchemeName
								,pi.PartitionFilegroupName
								,pi.PartitionFunctionName
								,pi.PartitionFunctionValueOnRight
								,pi.PartitionFunctionCreateDate
								,pi.PartitionFunctionModifyDate
								,pi.PartitionBoundaryValue
								,pi.PartitionColumn
								,pi.PartitionNumber
								,pi.PartitionCompressionTypeDesc
								,pi.PartitionRowCount
								,pi.Timestamp
								,ROW_NUMBER() OVER(PARTITION BY pi.TimestampUTC, pi.DatabaseName, pi.SchemaName, pi.ObjectName, pi.IndexName ORDER BY pi.PartitionNumber) AS Idx
							FROM dbo.fhsmPartitionedIndexes AS pi
							WHERE (pi.Timestamp IN (
								SELECT a.Timestamp
								FROM (
									SELECT
										pi2.Timestamp
										,ROW_NUMBER() OVER(PARTITION BY CAST(pi2.Timestamp AS date) ORDER BY pi2.Timestamp DESC) AS _Rnk_
									FROM dbo.fhsmPartitionedIndexes AS pi2
								) AS a
								WHERE (a._Rnk_ = 1)
							))
						)
					';
					SET @stmt += '
						SELECT
							pi.IndexTypeDesc
							,pi.PartitionSchemeName
							,pi.PartitionFilegroupName
							,pi.PartitionFunctionName
							,pi.PartitionFunctionValueOnRight
							,CASE 
								WHEN pi.PartitionFunctionValueOnRight = 0 
								THEN
									pi.PartitionColumn
									+ '' > ''
									+ CAST(ISNULL(lagPI.PartitionBoundaryValue, ''Infinity'') AS nvarchar)
									+ '' and ''
									+ pi.PartitionColumn
									+ '' <= ''
									+ CAST(ISNULL(pi.PartitionBoundaryValue, ''Infinity'') AS nvarchar) 
								ELSE
									pi.PartitionColumn
									+ '' >= ''
									+ CAST(ISNULL(pi.PartitionBoundaryValue, ''Infinity'') AS nvarchar)
									+ '' and ''
									+ pi.PartitionColumn
									+ '' < ''
									+ CAST(ISNULL(leadPI.PartitionBoundaryValue, ''Infinity'') AS nvarchar)
							END AS PartitionRange
							,ROW_NUMBER() OVER(ORDER BY pi.Timestamp DESC, pi.DatabaseName, pi.SchemaName, pi.ObjectName, pi.IndexName, CASE WHEN pi.PartitionFunctionValueOnRight = 0 THEN CASE WHEN pi.PartitionBoundaryValue IS NULL THEN 2 ELSE 1 END ELSE CASE WHEN pi.PartitionBoundaryValue IS NULL THEN 1 ELSE 2 END END, pi.PartitionBoundaryValue) AS SortOrder
							,pi.PartitionFunctionCreateDate
							,pi.PartitionFunctionModifyDate
							,pi.PartitionBoundaryValue
							,pi.PartitionColumn
							,pi.PartitionNumber
							,pi.PartitionCompressionTypeDesc
							,pi.PartitionRowCount
							,CAST(pi.Timestamp AS date) AS Date
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, DEFAULT,                   DEFAULT,       DEFAULT,                          DEFAULT, DEFAULT) AS k) AS DatabaseKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.SchemaName,             DEFAULT,       DEFAULT,                          DEFAULT, DEFAULT) AS k) AS SchemaKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.SchemaName,             pi.ObjectName, DEFAULT,                          DEFAULT, DEFAULT) AS k) AS ObjectKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.SchemaName,             pi.ObjectName, COALESCE(pi.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.PartitionFilegroupName, DEFAULT,       DEFAULT,                          DEFAULT, DEFAULT) AS k) AS FileGroupKey
						FROM partitionedIndexes AS pi
						LEFT OUTER JOIN partitionedIndexes AS lagPI ON
							(lagPI.Timestamp = pi.Timestamp)
							AND (lagPI.DatabaseName = pi.DatabaseName)
							AND (lagPI.SchemaName = pi.SchemaName)
							AND (lagPI.ObjectName = pi.ObjectName)
							AND ((lagPI.IndexName = pi.IndexName) OR ((lagPI.IndexName IS NULL) AND (pi.IndexName IS NULL)))
							AND (lagPI.Idx = pi.Idx - 1)
						LEFT OUTER JOIN partitionedIndexes AS leadPI ON
							(leadPI.Timestamp = pi.Timestamp)
							AND (leadPI.DatabaseName = pi.DatabaseName)
							AND (leadPI.SchemaName = pi.SchemaName)
							AND (leadPI.ObjectName = pi.ObjectName)
							AND ((leadPI.IndexName = pi.IndexName) OR ((leadPI.IndexName IS NULL) AND (pi.IndexName IS NULL)))
							AND (leadPI.Idx = pi.Idx + 1);
					';
				END
				ELSE BEGIN
					-- SQL Versions SQL2012 or higher

					SET @stmt += '
						SELECT
							pi.IndexTypeDesc
							,pi.PartitionSchemeName
							,pi.PartitionFilegroupName
							,pi.PartitionFunctionName
							,pi.PartitionFunctionValueOnRight
							,CASE 
								WHEN pi.PartitionFunctionValueOnRight = 0 
								THEN
									pi.PartitionColumn
									+ '' > ''
									+ CAST(ISNULL(LAG(pi.PartitionBoundaryValue) OVER(PARTITION BY pi.Timestamp, pi.DatabaseName, pi.SchemaName, pi.ObjectName, pi.IndexName ORDER BY pi.PartitionNumber), ''Infinity'') AS nvarchar)
									+ '' and ''
									+ pi.PartitionColumn
									+ '' <= ''
									+ CAST(ISNULL(pi.PartitionBoundaryValue, ''Infinity'') AS nvarchar) 
								ELSE
									pi.PartitionColumn
									+ '' >= ''
									+ CAST(ISNULL(pi.PartitionBoundaryValue, ''Infinity'') AS nvarchar)
									+ '' and ''
									+ pi.PartitionColumn
									+ '' < ''
									+ CAST(ISNULL(LEAD(pi.PartitionBoundaryValue) OVER(PARTITION BY pi.Timestamp, pi.DatabaseName, pi.SchemaName, pi.ObjectName, pi.IndexName ORDER BY pi.PartitionNumber), ''Infinity'') AS nvarchar)
							END AS PartitionRange
							,ROW_NUMBER() OVER(ORDER BY pi.Timestamp DESC, pi.DatabaseName, pi.SchemaName, pi.ObjectName, pi.IndexName, CASE WHEN pi.PartitionFunctionValueOnRight = 0 THEN CASE WHEN pi.PartitionBoundaryValue IS NULL THEN 2 ELSE 1 END ELSE CASE WHEN pi.PartitionBoundaryValue IS NULL THEN 1 ELSE 2 END END, pi.PartitionBoundaryValue) AS SortOrder
							,pi.PartitionFunctionCreateDate
							,pi.PartitionFunctionModifyDate
							,pi.PartitionBoundaryValue
							,pi.PartitionColumn
							,pi.PartitionNumber
							,pi.PartitionCompressionTypeDesc
							,pi.PartitionRowCount
							,CAST(pi.Timestamp AS date) AS Date
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, DEFAULT,                   DEFAULT,       DEFAULT,                          DEFAULT, DEFAULT) AS k) AS DatabaseKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.SchemaName,             DEFAULT,       DEFAULT,                          DEFAULT, DEFAULT) AS k) AS SchemaKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.SchemaName,             pi.ObjectName, DEFAULT,                          DEFAULT, DEFAULT) AS k) AS ObjectKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.SchemaName,             pi.ObjectName, COALESCE(pi.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.PartitionFilegroupName, DEFAULT,       DEFAULT,                          DEFAULT, DEFAULT) AS k) AS FileGroupKey
						FROM dbo.fhsmPartitionedIndexes AS pi
						WHERE (pi.Timestamp IN (
							SELECT a.Timestamp
							FROM (
								SELECT
									pi2.Timestamp
									,ROW_NUMBER() OVER(PARTITION BY CAST(pi2.Timestamp AS date) ORDER BY pi2.Timestamp DESC) AS _Rnk_
								FROM dbo.fhsmPartitionedIndexes AS pi2
							) AS a
							WHERE (a._Rnk_ = 1)
						));
					';
				END;
				SET @stmt += '
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on fact view @pbiSchema.[Partitioned indexes]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Partitioned indexes');
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create fact view @pbiSchema.[Table size]
		--
		BEGIN
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Table size') + ''', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Table size') + ' AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Table size') + '
					AS
					SELECT
						ts.Rows
						,ts.Reserved
						,ts.Data
						,ts.IndexSize
						,ts.Unused
						,CAST(ts.Timestamp AS date) AS Date
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ts.DatabaseName, DEFAULT,       DEFAULT,       DEFAULT,                          DEFAULT,            DEFAULT) AS k) AS DatabaseKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ts.DatabaseName, ts.SchemaName, DEFAULT,       DEFAULT,                          DEFAULT,            DEFAULT) AS k) AS SchemaKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ts.DatabaseName, ts.SchemaName, ts.ObjectName, DEFAULT,                          DEFAULT,            DEFAULT) AS k) AS ObjectKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ts.DatabaseName, ts.SchemaName, ts.ObjectName, COALESCE(ts.IndexName, ''N.A.''), DEFAULT,            DEFAULT) AS k) AS IndexKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ts.DatabaseName, ts.SchemaName, ts.ObjectName, ts.PartitionNumber,               DEFAULT,            DEFAULT) AS k) AS ObjectPartitionKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ts.DatabaseName, ts.SchemaName, ts.ObjectName, COALESCE(ts.IndexName, ''N.A.''), ts.PartitionNumber, DEFAULT) AS k) AS IndexPartitionKey
					FROM dbo.fhsmTableSize AS ts
					WHERE (ts.Timestamp IN (
						SELECT a.Timestamp
						FROM (
							SELECT
								ts2.Timestamp
								,ROW_NUMBER() OVER(PARTITION BY CAST(ts2.Timestamp AS date) ORDER BY ts2.Timestamp DESC) AS _Rnk_
							FROM dbo.fhsmTableSize AS ts2
						) AS a
						WHERE (a._Rnk_ = 1)
					));
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on fact view @pbiSchema.[Table size]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Table size');
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create fact view @pbiSchema.[VLF size]
		--
		BEGIN
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('VLF size') + ''', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('VLF size') + ' AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('VLF size') + '
					AS
					SELECT
						vs.VLFCount
						,vs.ActiveVLF
						,vs.VLFSizeMB
						,vs.ActiveVLFSizeMB
						,CAST(vs.Timestamp AS date) AS Date
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(vs.DatabaseName, '''', '''', '''', '''', DEFAULT) AS k) AS DatabaseFileKey
					FROM dbo.fhsmVLFSize AS vs
					WHERE (vs.Timestamp IN (
						SELECT a.Timestamp
						FROM (
							SELECT
								vs2.Timestamp
								,ROW_NUMBER() OVER(PARTITION BY CAST(vs2.Timestamp AS date) ORDER BY vs2.Timestamp DESC) AS _Rnk_
							FROM dbo.fhsmVLFSize AS vs2
						) AS a
						WHERE (a._Rnk_ = 1)
					));
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on fact view @pbiSchema.[VLF size]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('VLF size');
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;
	END;

	--
	-- Create stored procedures
	--
	BEGIN
		--
		-- Create stored procedure dbo.fhsmSPAllocationUnits
		--
		BEGIN
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''dbo.fhsmSPAllocationUnits'', ''P'') IS NULL
					BEGIN
						EXEC(''CREATE PROC dbo.fhsmSPAllocationUnits AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER PROC dbo.fhsmSPAllocationUnits (
						@name nvarchar(128),
						@parameter nvarchar(max)
					)
					AS
					BEGIN
						SET NOCOUNT ON;

						DECLARE @database nvarchar(128);
						DECLARE @databases nvarchar(max);
						DECLARE @errorMsg nvarchar(max);
						DECLARE @message nvarchar(max);
						DECLARE @now datetime;
						DECLARE @nowUTC datetime;
						DECLARE @parameterTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
						DECLARE @replicaId uniqueidentifier;
						DECLARE @stmt nvarchar(max);
						DECLARE @thisTask nvarchar(128);
						DECLARE @version nvarchar(128);

						SET @thisTask = OBJECT_NAME(@@PROCID);
						SET @version = ''' + @version + ''';

						--
						-- Parse the parameter for the command
						--
						BEGIN
							INSERT INTO @parameterTable([Key], Value)
							SELECT
								(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 1)) AS [Key]
								,(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 2)) AS Value
							FROM dbo.fhsmFNSplitString(@parameter, '';'') AS p;

							SET @databases = (SELECT pt.Value FROM @parameterTable AS pt WHERE (pt.[Key] = ''@Databases''));

							--
							-- Trim @databases if Ola Hallengren style has been chosen
							--
							BEGIN
								SET @databases = LTRIM(RTRIM(@databases));
								WHILE (LEFT(@databases, 1) = '''''''') AND (LEFT(@databases, 1) = '''''''')
								BEGIN
									SET @databases = SUBSTRING(@databases, 2, LEN(@databases) - 2);
								END;
							END;
						END;

						--
						-- Get the list of databases to process
						--
						BEGIN
							SELECT d.DatabaseName, d.[Order]
							INTO #dbList
							FROM dbo.fhsmFNParseDatabasesStr(@databases) AS d;
						END;

						--
						-- Collect data
						--
						BEGIN
							SELECT
								@now = SYSDATETIME()
								,@nowUTC = SYSUTCDATETIME();

							DECLARE dCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
							SELECT dl.DatabaseName, ' + CASE WHEN (@productVersion1 <= 10) THEN 'NULL' ELSE 'd.replica_id' END + ' AS replica_id
							FROM #dbList AS dl
							INNER JOIN sys.databases AS d ON (d.name COLLATE DATABASE_DEFAULT = dl.DatabaseName)
							ORDER BY dl.[Order];

							OPEN dCur;

							WHILE (1 = 1)
							BEGIN
								FETCH NEXT FROM dCur
								INTO @database, @replicaId;

								IF (@@FETCH_STATUS <> 0)
								BEGIN
									BREAK;
								END;

								--
								-- If is a member of a replica, we will only execute when running on the primary
								--
								IF (@replicaId IS NULL)
				';
				IF (@productVersion1 >= 11)
				BEGIN
					-- SQL Versions SQL2012 or higher
					SET @stmt += '
									OR (
										(
											SELECT
											CASE
												WHEN (dhags.primary_replica = ar.replica_server_name) THEN 1
												ELSE 0
											END AS IsPrimaryServer
											FROM master.sys.availability_groups AS ag
											INNER JOIN master.sys.availability_replicas AS ar ON ag.group_id = ar.group_id
											INNER JOIN master.sys.dm_hadr_availability_group_states AS dhags ON ag.group_id = dhags.group_id
											WHERE (ar.replica_server_name = @@SERVERNAME) AND (ar.replica_id = @replicaId)
										) = 1
									)
					';
				END;
				SET @stmt += '
								BEGIN
									SET @stmt = ''
										USE '' + QUOTENAME(@database) + '';

										SELECT
											DB_NAME()								AS DatabaseName
											,COALESCE(fg.name, ''''N.A.'''')		AS FilegroupName
											,sch.name								AS SchemaName
											,o.name									AS ObjectName
											,i.name									AS IndexName
											,p.partition_number						AS PartitionNumber
											,au.type								AS AllocationUnitType
											,SUM(au.total_pages)					AS TotalPages
											,SUM(au.used_pages)						AS UsedPages
											,SUM(au.data_pages)						AS DataPages
											,@nowUTC, @now
										FROM sys.database_files AS df
										INNER JOIN sys.filegroups AS fg ON (fg.data_space_id = df.data_space_id)
										INNER JOIN sys.allocation_units AS au ON (au.data_space_id = fg.data_space_id)
										INNER JOIN sys.partitions AS p ON (p.hobt_id = au.container_id)
										INNER JOIN sys.indexes AS i ON (i.object_id = p.object_id) AND (i.index_id = p.index_id)
										INNER JOIN sys.objects AS o ON (o.object_id = i.object_id)
										INNER JOIN sys.schemas AS sch ON (sch.schema_id = o.schema_id)
										WHERE (1 = 1)
											AND (o.type <> ''''V'''')
										GROUP BY
											fg.name
											,sch.name
											,o.name
											,i.name
											,p.partition_number
											,au.type;
									'';
									BEGIN TRY
										INSERT INTO dbo.fhsmAllocationUnits(
											DatabaseName, FilegroupName, SchemaName, ObjectName, IndexName, PartitionNumber, AllocationUnitType
											,TotalPages, UsedPages, DataPages, TimestampUTC, Timestamp
										)
										EXEC sp_executesql
											@stmt
											,N''@now datetime, @nowUTC datetime''
											,@now = @now, @nowUTC = @nowUTC;
									END TRY
									BEGIN CATCH
										SET @errorMsg = ERROR_MESSAGE();

										SET @message = ''Database '''''' + @database + '''''' failed due to - '' + @errorMsg;
										EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Warning'', @message = @message;
									END CATCH;
								END
								ELSE BEGIN
									SET @message = ''Database '''''' + @database + '''''' is member of a replica but this server is not the primary node'';
									EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
								END;
							END;

							CLOSE dCur;
							DEALLOCATE dCur;
						END;

						RETURN 0;
					END;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPAllocationUnits
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPAllocationUnits';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create stored procedure dbo.fhsmSPDatabaseSize
		--
		BEGIN
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''dbo.fhsmSPDatabaseSize'', ''P'') IS NULL
					BEGIN
						EXEC(''CREATE PROC dbo.fhsmSPDatabaseSize AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER PROC dbo.fhsmSPDatabaseSize (
						@name nvarchar(128),
						@parameter nvarchar(max)
					)
					AS
					BEGIN
						SET NOCOUNT ON;

						DECLARE @database nvarchar(128);
						DECLARE @databases nvarchar(max);
						DECLARE @errorMsg nvarchar(max);
						DECLARE @message nvarchar(max);
						DECLARE @now datetime;
						DECLARE @nowUTC datetime;
						DECLARE @parameterTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
						DECLARE @replicaId uniqueidentifier;
						DECLARE @stmt nvarchar(max);
						DECLARE @thisTask nvarchar(128);
						DECLARE @version nvarchar(128);

						SET @thisTask = OBJECT_NAME(@@PROCID);
						SET @version = ''' + @version + ''';

						--
						-- Get the parameter for the command
						--
						BEGIN
							INSERT INTO @parameterTable([Key], Value)
							SELECT
								(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 1)) AS [Key]
								,(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 2)) AS Value
							FROM dbo.fhsmFNSplitString(@parameter, '';'') AS p;

							SET @databases = (SELECT pt.Value FROM @parameterTable AS pt WHERE (pt.[Key] = ''@Databases''));

							--
							-- Trim @databases if Ola Hallengren style has been chosen
							--
							BEGIN
								SET @databases = LTRIM(RTRIM(@databases));
								WHILE (LEFT(@databases, 1) = '''''''') AND (LEFT(@databases, 1) = '''''''')
								BEGIN
									SET @databases = SUBSTRING(@databases, 2, LEN(@databases) - 2);
								END;
							END;
						END;

						--
						-- Get the list of databases to process
						--
						BEGIN
							SELECT d.DatabaseName, d.[Order]
							INTO #dbList
							FROM dbo.fhsmFNParseDatabasesStr(@databases) AS d;
						END;

						--
						-- Collect data
						--
						BEGIN
							SELECT
								@now = SYSDATETIME()
								,@nowUTC = SYSUTCDATETIME();

							DECLARE dCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
							SELECT dl.DatabaseName, ' + CASE WHEN (@productVersion1 <= 10) THEN 'NULL' ELSE 'd.replica_id' END + ' AS replica_id
							FROM #dbList AS dl
							INNER JOIN sys.databases AS d ON (d.name COLLATE DATABASE_DEFAULT = dl.DatabaseName)
							ORDER BY dl.[Order];

							OPEN dCur;

							WHILE (1 = 1)
							BEGIN
								FETCH NEXT FROM dCur
								INTO @database, @replicaId;

								IF (@@FETCH_STATUS <> 0)
								BEGIN
									BREAK;
								END;

								--
								-- If is a member of a replica, we will only execute when running on the primary
								--
								IF (@replicaId IS NULL)
				';
				IF (@productVersion1 >= 11)
				BEGIN
					-- SQL Versions SQL2012 or higher
					SET @stmt += '
									OR (
										(
											SELECT
											CASE
												WHEN (dhags.primary_replica = ar.replica_server_name) THEN 1
												ELSE 0
											END AS IsPrimaryServer
											FROM master.sys.availability_groups AS ag
											INNER JOIN master.sys.availability_replicas AS ar ON ag.group_id = ar.group_id
											INNER JOIN master.sys.dm_hadr_availability_group_states AS dhags ON ag.group_id = dhags.group_id
											WHERE (ar.replica_server_name = @@SERVERNAME) AND (ar.replica_id = @replicaId)
										) = 1
									)
					';
				END;
				SET @stmt += '
								BEGIN
									SET @stmt = ''
										USE '' + QUOTENAME(@database) + '';

										SELECT
											DB_NAME() AS DatabaseName
											,a.LogicalName
											,a.PhysicalName
											,a.Type
											,a.VolumeMountPoint
											,a.LogicalVolumeName
											,COALESCE(a.FilegroupName, ''''N.A.'''') AS FilegroupName
											,a.FileGroupType
											,a.CurrentSize
											,a.UsedSize
											,@nowUTC, @now
										FROM (
											SELECT
												df.name						AS LogicalName
												,df.physical_name			AS PhysicalName
												,df.type					AS Type
				';
				IF ((@productVersion1 = 10) AND (@productVersion2 = 0))
				BEGIN
					-- SQL Versions SQL2008
					SET @stmt += '
												,CAST(NULL AS nvarchar(512))	AS VolumeMountPoint
												,CAST(NULL AS nvarchar(512))	AS LogicalVolumeName
					';
				END
				ELSE BEGIN
					-- SQL Versions SQL2008R2 or higher
					SET @stmt += '
												,dovs.volume_mount_point	AS VolumeMountPoint
												,dovs.logical_volume_name	AS LogicalVolumeName
					';
				END;
				SET @stmt += '
												,fg.name					AS FilegroupName
												,fg.type					AS FileGroupType
												,CAST((df.size / 128.0) AS int) AS CurrentSize
												,CAST((CAST(FILEPROPERTY(df.name, ''''SpaceUsed'''') AS int) / 128.0) AS int) AS UsedSize
											FROM sys.database_files AS df WITH (NOLOCK)
				';
				IF NOT ((@productVersion1 = 10) AND (@productVersion2 = 0))
				BEGIN
					-- SQL Versions SQL2008R2 or higher
					SET @stmt += '
											CROSS APPLY sys.dm_os_volume_stats(DB_ID(), df.file_id) AS dovs
					';
				END;
				SET @stmt += '
											LEFT OUTER JOIN sys.filegroups AS fg WITH (NOLOCK) ON (fg.data_space_id = df.data_space_id)
										) AS a;
									'';
									BEGIN TRY
										INSERT INTO dbo.fhsmDatabaseSize(DatabaseName, LogicalName, PhysicalName, Type, VolumeMountPoint, LogicalVolumeName, FilegroupName, FileGroupType, CurrentSize, UsedSize, TimestampUTC, Timestamp)
										EXEC sp_executesql
											@stmt
											,N''@now datetime, @nowUTC datetime''
											,@now = @now, @nowUTC = @nowUTC;
									END TRY
									BEGIN CATCH
										SET @errorMsg = ERROR_MESSAGE();

										SET @message = ''Database '''''' + @database + '''''' failed due to - '' + @errorMsg;
										EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Warning'', @message = @message;
									END CATCH;
								END
								ELSE BEGIN
									SET @message = ''Database '''''' + @database + '''''' is member of a replica but this server is not the primary node'';
									EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
								END;
							END;

							CLOSE dCur;
							DEALLOCATE dCur;
						END;

						RETURN 0;
					END;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPDatabaseSize
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPDatabaseSize';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create stored procedure dbo.fhsmSPDiskSize
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPDiskSize'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPDiskSize AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPDiskSize
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @now datetime;
					DECLARE @nowUTC datetime;

					--
					-- Collect data
					--
					BEGIN
						SELECT
							@now = SYSDATETIME()
							,@nowUTC = SYSUTCDATETIME();

						INSERT INTO dbo.fhsmDiskSize(VolumeMountPoint, LogicalVolumeName, FileSystemType, TotalBytes, FreeBytes, TimestampUTC, Timestamp)
						SELECT
							d.volume_mount_point	AS VolumeMountPoint
							,d.logical_volume_name	AS LogicalVolumeName
							,d.file_system_type		AS FileSystemType
							,d.total_bytes			AS TotalBytes
							,d.available_bytes		AS FreeBytes
							,@nowUTC				AS TimestampUTC
							,@now					AS Timestamp
						FROM (
							SELECT
								rankedDovs.volume_mount_point,
								rankedDovs.logical_volume_name,
								rankedDovs.file_system_type,
								rankedDovs.total_bytes,
								rankedDovs.available_bytes
							FROM (
								SELECT
									dovs.volume_mount_point,
									dovs.logical_volume_name,
									dovs.file_system_type,
									dovs.total_bytes,
									dovs.available_bytes,
									ROW_NUMBER() OVER(PARTITION BY dovs.volume_mount_point ORDER BY dovs.available_bytes) AS Rnk
								FROM sys.master_files AS mf
								CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS dovs
							) AS rankedDovs
							WHERE (rankedDovs.Rnk = 1)
						) AS d;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPDiskSize
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPDiskSize';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create stored procedure dbo.fhsmSPPartitionedIndexes
		--
		BEGIN
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''dbo.fhsmSPPartitionedIndexes'', ''P'') IS NULL
					BEGIN
						EXEC(''CREATE PROC dbo.fhsmSPPartitionedIndexes AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER PROC dbo.fhsmSPPartitionedIndexes (
						@name nvarchar(128),
						@parameter nvarchar(max)
					)
					AS
					BEGIN
						SET NOCOUNT ON;

						DECLARE @database nvarchar(128);
						DECLARE @databases nvarchar(max);
						DECLARE @errorMsg nvarchar(max);
						DECLARE @message nvarchar(max);
						DECLARE @now datetime;
						DECLARE @nowUTC datetime;
						DECLARE @parameterTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
						DECLARE @replicaId uniqueidentifier;
						DECLARE @stmt nvarchar(max);
						DECLARE @thisTask nvarchar(128);
						DECLARE @version nvarchar(128);

						SET @thisTask = OBJECT_NAME(@@PROCID);
						SET @version = ''' + @version + ''';

						--
						-- Get the parameter for the command
						--
						BEGIN
							INSERT INTO @parameterTable([Key], Value)
							SELECT
								(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 1)) AS [Key]
								,(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 2)) AS Value
							FROM dbo.fhsmFNSplitString(@parameter, '';'') AS p;

							SET @databases = (SELECT pt.Value FROM @parameterTable AS pt WHERE (pt.[Key] = ''@Databases''));

							--
							-- Trim @databases if Ola Hallengren style has been chosen
							--
							BEGIN
								SET @databases = LTRIM(RTRIM(@databases));
								WHILE (LEFT(@databases, 1) = '''''''') AND (LEFT(@databases, 1) = '''''''')
								BEGIN
									SET @databases = SUBSTRING(@databases, 2, LEN(@databases) - 2);
								END;
							END;
						END;
				';
				SET @stmt += '

						--
						-- Get the list of databases to process
						--
						BEGIN
							SELECT d.DatabaseName, d.[Order]
							INTO #dbList
							FROM dbo.fhsmFNParseDatabasesStr(@databases) AS d;
						END;

						--
						-- Collect data
						--
						BEGIN
							SELECT
								@now = SYSDATETIME()
								,@nowUTC = SYSUTCDATETIME();

							DECLARE dCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
							SELECT dl.DatabaseName, ' + CASE WHEN (@productVersion1 <= 10) THEN 'NULL' ELSE 'd.replica_id' END + ' AS replica_id
							FROM #dbList AS dl
							INNER JOIN sys.databases AS d ON (d.name COLLATE DATABASE_DEFAULT = dl.DatabaseName)
							ORDER BY dl.[Order];

							OPEN dCur;
				';
				SET @stmt += '

							WHILE (1 = 1)
							BEGIN
								FETCH NEXT FROM dCur
								INTO @database, @replicaId;

								IF (@@FETCH_STATUS <> 0)
								BEGIN
									BREAK;
								END;

								--
								-- If is a member of a replica, we will only execute when running on the primary
								--
								IF (@replicaId IS NULL)
				';
				IF (@productVersion1 >= 11)
				BEGIN
					-- SQL Versions SQL2012 or higher
					SET @stmt += '
									OR (
										(
											SELECT
											CASE
												WHEN (dhags.primary_replica = ar.replica_server_name) THEN 1
												ELSE 0
											END AS IsPrimaryServer
											FROM master.sys.availability_groups AS ag
											INNER JOIN master.sys.availability_replicas AS ar ON ag.group_id = ar.group_id
											INNER JOIN master.sys.dm_hadr_availability_group_states AS dhags ON ag.group_id = dhags.group_id
											WHERE (ar.replica_server_name = @@SERVERNAME) AND (ar.replica_id = @replicaId)
										) = 1
									)
					';
				END;
				SET @stmt += '
								BEGIN
									SET @stmt = ''
										USE '' + QUOTENAME(@database) + '';

										SELECT
											DB_NAME() AS DatabaseName
											,sch.name AS SchemaName
											,o.name AS ObjectName
											,i.name AS IndexName
											,i.type_desc AS IndexTypeDesc
											,ps.name AS PartitionSchemeName
											,ds.name AS PartitionFilegroupName
											,pf.name AS PartitionFunctionName
											,pf.boundary_value_on_right AS PartitionFunctionValueOnRight
											,pf.create_date AS PartitionFunctionCreateDate
											,pf.modify_date AS PartitionFunctionModifyDate
											,prv.value AS PartitionBoundaryValue
											,c.name AS PartitionColumn
											,pstats.partition_number AS PartitionNumber
											,p.data_compression_desc AS PartitionCompressionTypeDesc
											,pstats.row_count AS PartitionRowCount
											,@nowUTC, @now
										FROM sys.dm_db_partition_stats AS pstats
										INNER JOIN sys.objects AS o ON (o.object_id = pstats.object_id)
										INNER JOIN sys.schemas AS sch ON (sch.schema_id = o.schema_id)
										INNER JOIN sys.partitions AS p ON (p.partition_id = pstats.partition_id)
										INNER JOIN sys.destination_data_spaces AS dds ON (dds.destination_id = pstats.partition_number)
										INNER JOIN sys.data_spaces AS ds ON (ds.data_space_id = dds.data_space_id)
										INNER JOIN sys.partition_schemes AS ps ON (ps.data_space_id = dds.partition_scheme_id)
										INNER JOIN sys.partition_functions AS pf ON (pf.function_id = ps.function_id)
										INNER JOIN sys.indexes AS i ON (i.object_id = pstats.object_id) AND (i.index_id = pstats.index_id) AND (i.data_space_id = dds.partition_scheme_id)
										INNER JOIN sys.index_columns AS ic ON (ic.index_id = i.index_id) AND (ic.object_id = i.object_id) AND (ic.partition_ordinal > 0)
										INNER JOIN sys.columns AS c ON (c.object_id = ic.object_id) AND (c.column_id = ic.column_id)
										LEFT OUTER JOIN sys.partition_range_values AS prv ON (prv.function_id = pf.function_id) AND (pstats.partition_number = (CASE pf.boundary_value_on_right WHEN 0 THEN prv.boundary_id ELSE (prv.boundary_id + 1) END))
									'';
									BEGIN TRY
										INSERT INTO dbo.fhsmPartitionedIndexes(
											DatabaseName, SchemaName, ObjectName, IndexName, IndexTypeDesc
											,PartitionSchemeName
											,PartitionFilegroupName, PartitionFunctionName, PartitionFunctionValueOnRight, PartitionFunctionCreateDate, PartitionFunctionModifyDate, PartitionBoundaryValue, PartitionColumn
											,PartitionNumber, PartitionCompressionTypeDesc, PartitionRowCount
											,TimestampUTC, Timestamp
										)
										EXEC sp_executesql
											@stmt
											,N''@now datetime, @nowUTC datetime''
											,@now = @now, @nowUTC = @nowUTC;
									END TRY
									BEGIN CATCH
										SET @errorMsg = ERROR_MESSAGE();

										SET @message = ''Database '''''' + @database + '''''' failed due to - '' + @errorMsg;
										EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Warning'', @message = @message;
									END CATCH;
								END
								ELSE BEGIN
									SET @message = ''Database '''''' + @database + '''''' is member of a replica but this server is not the primary node'';
									EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
								END;
							END;

							CLOSE dCur;
							DEALLOCATE dCur;
						END;

						RETURN 0;
					END;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPPartitionedIndexes
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPPartitionedIndexes';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create stored procedure dbo.fhsmSPSpaceUsed
		--
		BEGIN
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''dbo.fhsmSPSpaceUsed'', ''P'') IS NULL
					BEGIN
						EXEC(''CREATE PROC dbo.fhsmSPSpaceUsed AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER PROC dbo.fhsmSPSpaceUsed (
						@database nvarchar(128)
					)
					AS
					BEGIN
						SET NOCOUNT ON;

						DECLARE @isMemoryOptimizedStmt nvarchar(max);
						DECLARE @stmt nvarchar(max);

						--
						-- Test if version_generated_inrow (and thereby all other *version*) exists on dm_db_index_operational_stats
						--
						BEGIN
							IF EXISTS(
								SELECT *
								FROM master.sys.system_columns AS sc
								INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
								WHERE (so.name = ''tables'') AND (sc.name = ''is_memory_optimized'')
							)
							BEGIN
								SET @isMemoryOptimizedStmt = ''
									/*
									** If the table is memory-optimized, return NULL for reserved, data, index_size and unused.
									*/
									IF (SELECT t.is_memory_optimized FROM '' + QUOTENAME(@database) + ''.sys.tables AS t WITH (NOLOCK) WHERE t.object_id = @objectId) = 1
									BEGIN
										INSERT INTO @spaceUsed(DatabaseName, SchemaName, ObjectName, IndexName, PartitionNumber, IsMemoryOptimized, Rows, Reserved, Data, IndexSize, Unused)
										SELECT
											@database AS DatabaseName
											,@schema AS SchemaName
											,@object AS ObjectName
											,i.name AS IndexName 
											,1 AS PartitionNumber
											,1 AS IsMemoryOptimized
											,SUM(p.rows) AS Rows
											,NULL AS Reserved
											,NULL AS Data
											,NULL AS IndexSize
											,NULL AS Unused
										FROM '' + QUOTENAME(@database) + ''.sys.partitions AS p WITH (NOLOCK)
										LEFT OUTER JOIN '' + QUOTENAME(@database) + ''.sys.indexes AS i WITH (NOLOCK) ON (i.object_id = p.object_id) AND (i.index_id = p.index_id)
										WHERE (p.index_id IN (0, 1, 5)) AND (p.object_id = @objectId)
										GROUP BY i.name;
									END
								'';
							END
							ELSE BEGIN
								SET @isMemoryOptimizedStmt = ''
									/*
									** Dummy code as this SQL server version does not support memory optimized tables
									*/
									IF (1 = 0)
									BEGIN
										SET @objectId = @objectId;
									END
								'';
							END;
						END;

						SET @stmt = ''
							DECLARE @object nvarchar(128);
							DECLARE @objectId int;
							DECLARE @pages bigint;
							DECLARE @reservedpages bigint;
							DECLARE @rowCount bigint;
							DECLARE @schema nvarchar(128);
							DECLARE @spaceUsed TABLE(
								DatabaseName nvarchar(128), SchemaName nvarchar(128), ObjectName nvarchar(128), IndexName nvarchar(128), PartitionNumber int
								,IsMemoryOptimized bit, Rows bigint, Reserved int, Data int, IndexSize int, Unused int
							);
							DECLARE @usedpages bigint;

							DECLARE oCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
							SELECT sch.name AS [Schema], o.name AS Object, o.object_id AS ObjectId
							FROM '' + QUOTENAME(@database) + ''.sys.schemas AS sch WITH (NOLOCK)
							INNER JOIN '' + QUOTENAME(@database) + ''.sys.objects AS o WITH (NOLOCK) ON (o.schema_id = sch.schema_id)
							WHERE (o.type = ''''U'''')
							ORDER BY sch.name, o.name;

							OPEN OCur;

							WHILE (1 = 1)
							BEGIN
								FETCH NEXT FROM oCur
								INTO @schema, @object, @objectId;

								IF (@@FETCH_STATUS <> 0)
								BEGIN
									BREAK;
								END;

								'' + @isMemoryOptimizedStmt + ''
								ELSE BEGIN
									INSERT INTO @spaceUsed(DatabaseName, SchemaName, ObjectName, IndexName, PartitionNumber, IsMemoryOptimized, Rows, Reserved, Data, IndexSize, Unused)
									SELECT
										@database AS DatabaseName
										,@schema AS SchemaName
										,@object AS ObjectName
										,a.IndexName
										,a.PartitionNumber
										,0 AS IsMemoryOptimized
										,a.[RowCount] AS Rows
										,((a.ReservedPageCount + a.XMLFullReservedPageCount) * 8) AS Reserved
										,(a.Pages * 8) AS Data
										,((CASE WHEN (a.UsedPageCount + a.XMLFullUsedPageCount) > a.Pages THEN ((a.UsedPageCount + a.XMLFullUsedPageCount) - a.Pages) ELSE 0 END) * 8) AS IndexSize
										,((CASE WHEN (a.ReservedPageCount + a.XMLFullReservedPageCount) > (a.UsedPageCount + a.XMLFullUsedPageCount) THEN ((a.ReservedPageCount + a.XMLFullReservedPageCount) - (a.UsedPageCount + a.XMLFullUsedPageCount)) ELSE 0 END) * 8) AS Unused
									FROM (
										/*
										** Now calculate the summary data.
										*  Note that LOB Data and Row-overflow Data are counted as Data Pages for the base table
										*  For non-clustered indices they are counted towards the index pages
										*/
										SELECT
											ddps.object_id
											,i.name AS IndexName
											,ddps.partition_number AS PartitionNumber
											,ddps.reserved_page_count AS ReservedPageCount
											,ddps.used_page_count AS UsedPageCount
											,CASE
												WHEN (ddps.index_id < 2) THEN (ddps.in_row_data_page_count + ddps.lob_used_page_count + ddps.row_overflow_used_page_count)
												ELSE (ddps.lob_used_page_count + ddps.row_overflow_used_page_count)
											END AS Pages
											,ddps.row_count AS [RowCount]
											,COALESCE(XMLFull.ReservedPageCount, 0) AS XMLFullReservedPageCount
											,COALESCE(XMLFull.UsedPageCount, 0) AS XMLFullUsedPageCount
										FROM '' + QUOTENAME(@database) + ''.sys.dm_db_partition_stats AS ddps WITH (NOLOCK)
										LEFT OUTER JOIN '' + QUOTENAME(@database) + ''.sys.indexes AS i WITH (NOLOCK) ON (i.object_id = ddps.object_id) AND (i.index_id = ddps.index_id)
										OUTER APPLY (
											/*
											** Check if table has XML Indexes or Fulltext Indexes which use internal tables tied to this table
											*/
											SELECT
												p.reserved_page_count AS ReservedPageCount
												,p.used_page_count AS UsedPageCount
											FROM '' + QUOTENAME(@database) + ''.sys.dm_db_partition_stats AS p WITH (NOLOCK)
											INNER JOIN '' + QUOTENAME(@database) + ''.sys.internal_tables AS it WITH (NOLOCK) ON (it.object_id = p.object_id)
											WHERE (it.parent_id = ddps.object_id) AND (p.partition_id = ddps.partition_id) AND (it.internal_type IN (202, 204, 207, 211, 212, 213, 214, 215, 216, 221, 222, 236))
										) AS XMLFull
										WHERE (ddps.object_id = @objectId)
									) AS a;
								END;
							END;

							CLOSE OCur;
							DEALLOCATE OCur;

							SELECT *
							FROM @spaceUsed AS su
							ORDER BY su.DatabaseName, su.SchemaName, su.ObjectName, su.IndexName;
						'';
						EXEC sp_executesql
							@stmt
							,N''@database nvarchar(128)''
							,@database = @database;

						RETURN 0;
					END;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPSpaceUsed
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPSpaceUsed';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create stored procedure dbo.fhsmSPTableSize
		--
		BEGIN
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''dbo.fhsmSPTableSize'', ''P'') IS NULL
					BEGIN
						EXEC(''CREATE PROC dbo.fhsmSPTableSize AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER PROC dbo.fhsmSPTableSize (
						@name nvarchar(128),
						@parameter nvarchar(max)
					)
					AS
					BEGIN
						SET NOCOUNT ON;

						DECLARE @database nvarchar(128);
						DECLARE @databases nvarchar(max);
						DECLARE @errorMsg nvarchar(max);
						DECLARE @message nvarchar(max);
						DECLARE @now datetime;
						DECLARE @nowUTC datetime;
						DECLARE @parameterTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
						DECLARE @replicaId uniqueidentifier;
						DECLARE @spaceUsed TABLE(DatabaseName nvarchar(128), SchemaName nvarchar(128), ObjectName nvarchar(128), IndexName nvarchar(128), PartitionNumber int, IsMemoryOptimized bit, Rows bigint, Reserved int, Data int, IndexSize int, Unused int);
						DECLARE @stmt nvarchar(max);
						DECLARE @thisTask nvarchar(128);
						DECLARE @version nvarchar(128);

						SET @thisTask = OBJECT_NAME(@@PROCID);
						SET @version = ''' + @version + ''';

						--
						-- Get the parameter for the command
						--
						BEGIN
							INSERT INTO @parameterTable([Key], Value)
							SELECT
								(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 1)) AS [Key]
								,(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 2)) AS Value
							FROM dbo.fhsmFNSplitString(@parameter, '';'') AS p;

							SET @databases = (SELECT pt.Value FROM @parameterTable AS pt WHERE (pt.[Key] = ''@Databases''));

							--
							-- Trim @databases if Ola Hallengren style has been chosen
							--
							BEGIN
								SET @databases = LTRIM(RTRIM(@databases));
								WHILE (LEFT(@databases, 1) = '''''''') AND (LEFT(@databases, 1) = '''''''')
								BEGIN
									SET @databases = SUBSTRING(@databases, 2, LEN(@databases) - 2);
								END;
							END;
						END;

						--
						-- Get the list of databases to process
						--
						BEGIN
							SELECT d.DatabaseName, d.[Order]
							INTO #dbList
							FROM dbo.fhsmFNParseDatabasesStr(@databases) AS d;
						END;

						--
						-- Collect data
						--
						BEGIN
							SELECT
								@now = SYSDATETIME()
								,@nowUTC = SYSUTCDATETIME();

							DECLARE dCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
							SELECT dl.DatabaseName, ' + CASE WHEN (@productVersion1 <= 10) THEN 'NULL' ELSE 'd.replica_id' END + ' AS replica_id
							FROM #dbList AS dl
							INNER JOIN sys.databases AS d ON (d.name COLLATE DATABASE_DEFAULT = dl.DatabaseName)
							ORDER BY dl.[Order];

							OPEN dCur;

							WHILE (1 = 1)
							BEGIN
								FETCH NEXT FROM dCur
								INTO @database, @replicaId;

								IF (@@FETCH_STATUS <> 0)
								BEGIN
									BREAK;
								END;

								--
								-- If is a member of a replica, we will only execute when running on the primary
								--
								IF (@replicaId IS NULL)
				';
				IF (@productVersion1 >= 11)
				BEGIN
					-- SQL Versions SQL2012 or higher
					SET @stmt += '
									OR (
										(
											SELECT
											CASE
												WHEN (dhags.primary_replica = ar.replica_server_name) THEN 1
												ELSE 0
											END AS IsPrimaryServer
											FROM master.sys.availability_groups AS ag
											INNER JOIN master.sys.availability_replicas AS ar ON ag.group_id = ar.group_id
											INNER JOIN master.sys.dm_hadr_availability_group_states AS dhags ON ag.group_id = dhags.group_id
											WHERE (ar.replica_server_name = @@SERVERNAME) AND (ar.replica_id = @replicaId)
										) = 1
									)
					';
				END;
				SET @stmt += '
								BEGIN
									DELETE @spaceUsed;

									BEGIN TRY
										SET @stmt = ''EXEC dbo.fhsmSPSpaceUsed @database = @database;'';
										INSERT INTO @spaceUsed
										EXEC sp_executesql
											@stmt
											,N''@database nvarchar(128)''
											,@database = @database;

										INSERT INTO dbo.fhsmTableSize(DatabaseName, SchemaName, ObjectName, IndexName, PartitionNumber, IsMemoryOptimized, Rows, Reserved, Data, IndexSize, Unused, TimestampUTC, Timestamp)
										SELECT su.DatabaseName, su.SchemaName, su.ObjectName, su.IndexName, su.PartitionNumber, su.IsMemoryOptimized, su.Rows, su.Reserved, su.Data, su.IndexSize, su.Unused, @nowUTC, @now
										FROM @spaceUsed AS su;
									END TRY
									BEGIN CATCH
										SET @errorMsg = ERROR_MESSAGE();

										SET @message = ''Database '''''' + @database + '''''' failed due to - '' + @errorMsg;
										EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Warning'', @message = @message;
									END CATCH;
								END
								ELSE BEGIN
									SET @message = ''Database '''''' + @database + '''''' is member of a replica but this server is not the primary node'';
									EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
								END;
							END;

							CLOSE dCur;
							DEALLOCATE dCur;
						END;

						RETURN 0;
					END;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPTableSize
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPTableSize';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create stored procedure dbo.fhsmSPVLFSize
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPVLFSize'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPVLFSize AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPVLFSize
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @now datetime;
					DECLARE @nowUTC datetime;

					--
					-- Collect data
					--
					BEGIN
						SELECT
							@now = SYSDATETIME()
							,@nowUTC = SYSUTCDATETIME();

						--
						-- Get VLF statistics
						--
						IF EXISTS(SELECT * FROM master.sys.system_objects AS so WHERE (so.name = ''dm_db_log_info''))
						BEGIN
							INSERT INTO dbo.fhsmVLFSize(DatabaseName, VLFCount, ActiveVLF, VLFSizeMB, ActiveVLFSizeMB, TimestampUTC, Timestamp)
							SELECT
								d.name AS DatabaseName
								,COUNT(d.database_id) AS VLFCount
								,SUM(CAST(ddli.vlf_active AS int)) AS ActiveVLF
								,SUM(ddli.vlf_size_mb) AS VLFSizeMB
								,SUM(ddli.vlf_active * ddli.vlf_size_mb) AS ActiveVLFSizeMB
								,@nowUTC, @now
							FROM sys.databases AS d
							CROSS APPLY sys.dm_db_log_info(d.database_id) AS ddli
							GROUP BY d.name;
						END;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPVLFSize
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPVLFSize';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create stored procedure dbo.fhsmSPCapacity
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPCapacity'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPCapacity AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '';
			SET @stmt += '
				ALTER PROC dbo.fhsmSPCapacity (
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @message nvarchar(max);
					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameter nvarchar(max);
					DECLARE @processingId int;
					DECLARE @processingTimestamp datetime;
					DECLARE @processingTimestampUTC datetime;
					DECLARE @thisTask nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);
					SET @version = ''' + @version + ''';

					--
					-- Get the parameter for the command
					--
					BEGIN
						SET @parameter = dbo.fhsmFNGetTaskParameter(@thisTask, @name);
					END;

					--
					-- Collect data
					--
					BEGIN
			';
			SET @stmt += '
						--
						-- Calling dbo.fhsmSPAllocationUnits
						--
						BEGIN
							SET @message = ''Before calling dbo.fhsmSPAllocationUnits'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;

							--
							-- Insert Processing record and remember the @id in the variable @processingId
							-- Type: 1: Calling dbo.fhsmSPAllocationUnits
							--
							SET @processingId = NULL;
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = NULL, @type = 1, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							EXEC dbo.fhsmSPAllocationUnits @name = @name, @parameter = @parameter;

							--
							-- Update Processing record from before execution with @version, @processingTimestampUTC and @processingTimestamp
							-- Type: 1: Loading data into dbo.fhsmSPAllocationUnits
							--
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = @version, @type = 1, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							SET @message = ''After calling dbo.fhsmSPAllocationUnits'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
						END;
			';
			SET @stmt += '
						--
						-- Calling dbo.fhsmSPDatabaseSize
						--
						BEGIN
							SET @message = ''Before calling dbo.fhsmSPDatabaseSize'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;

							--
							-- Insert Processing record and remember the @id in the variable @processingId
							-- Type: 2: Calling dbo.fhsmSPDatabaseSize
							--
							SET @processingId = NULL;
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = NULL, @type = 2, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							EXEC dbo.fhsmSPDatabaseSize @name = @name, @parameter = @parameter;

							--
							-- Update Processing record from before execution with @version, @processingTimestampUTC and @processingTimestamp
							-- Type: 2: Loading data into dbo.fhsmSPDatabaseSize
							--
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = @version, @type = 2, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							SET @message = ''After calling dbo.fhsmSPDatabaseSize'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
						END;
			';
		--
		-- SQL Versions SQL2008R2 or higher
		--
		IF NOT ((@productVersion1 = 10) AND (@productVersion2 = 0))
		BEGIN
			SET @stmt += '
						--
						-- Calling dbo.fhsmSPDiskSize
						--
						BEGIN
							SET @message = ''Before calling dbo.fhsmSPDiskSize'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;

							--
							-- Insert Processing record and remember the @id in the variable @processingId
							-- Type: 3: Calling dbo.fhsmSPDiskSize
							--
							SET @processingId = NULL;
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = NULL, @type = 3, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							EXEC dbo.fhsmSPDiskSize;

							--
							-- Update Processing record from before execution with @version, @processingTimestampUTC and @processingTimestamp
							-- Type: 3: Loading data into dbo.fhsmSPDiskSize
							--
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = @version, @type = 3, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							SET @message = ''After calling dbo.fhsmSPDiskSize'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
						END;
			';
		END;
			SET @stmt += '
						--
						-- Calling dbo.fhsmSPPartitionedIndexes
						--
						BEGIN
							SET @message = ''Before calling dbo.fhsmSPPartitionedIndexes'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;

							--
							-- Insert Processing record and remember the @id in the variable @processingId
							-- Type: 4: Calling dbo.fhsmSPPartitionedIndexes
							--
							SET @processingId = NULL;
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = NULL, @type = 4, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							EXEC dbo.fhsmSPPartitionedIndexes @name = @name, @parameter = @parameter;

							--
							-- Update Processing record from before execution with @version, @processingTimestampUTC and @processingTimestamp
							-- Type: 4: Loading data into dbo.fhsmSPPartitionedIndexes
							--
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = @version, @type = 4, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							SET @message = ''After calling dbo.fhsmSPPartitionedIndexes'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
						END;
			';
			SET @stmt += '
						--
						-- Calling dbo.fhsmSPTableSize
						--
						BEGIN
							SET @message = ''Before calling dbo.fhsmSPTableSize'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;

							--
							-- Insert Processing record and remember the @id in the variable @processingId
							-- Type: 5: Calling dbo.fhsmSPTableSize
							--
							SET @processingId = NULL;
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = NULL, @type = 5, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							EXEC dbo.fhsmSPTableSize @name = @name, @parameter = @parameter;

							--
							-- Update Processing record from before execution with @version, @processingTimestampUTC and @processingTimestamp
							-- Type: 5: Loading data into dbo.fhsmSPTableSize
							--
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = @version, @type = 5, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							SET @message = ''After calling dbo.fhsmSPTableSize'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
						END;
			';

		--
		-- SQL Versions SQL2016 SP2 or higher
		--
		IF
			NOT (
				(@productVersion1 < 13)
				OR ((@productVersion1 = 13) AND (@productVersion2 = 0) AND (@productVersion3 < 5026))
			)
		BEGIN
			SET @stmt += '
						--
						-- Calling dbo.fhsmSPVLFSize
						--
						BEGIN
							SET @message = ''Before calling dbo.fhsmSPVLFSize'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;

							--
							-- Insert Processing record and remember the @id in the variable @processingId
							-- Type: 6: Calling dbo.fhsmSPVLFSize
							--
							SET @processingId = NULL;
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = NULL, @type = 6, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							EXEC dbo.fhsmSPVLFSize;

							--
							-- Update Processing record from before execution with @version, @processingTimestampUTC and @processingTimestamp
							-- Type: 6: Loading data into dbo.fhsmSPVLFSize
							--
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = @version, @type = 6, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							SET @message = ''After calling dbo.fhsmSPVLFSize'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
						END;
			';
		END;
			SET @stmt += '
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPCapacity
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPCapacity';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;

		--
		-- Create stored procedure dbo.fhsmSPControlCapacity
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPControlCapacity'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPControlCapacity AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPControlCapacity (
					@Type nvarchar(16)
					,@Command nvarchar(16)
					,@Name nvarchar(128) = NULL
					,@Parameter nvarchar(max) = NULL
					,@Task nvarchar(128) = NULL
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @message nvarchar(max);
					DECLARE @parameterChanges TABLE(
						Action nvarchar(10),
						DeletedTask nvarchar(128),
						DeletedName nvarchar(128),
						DeletedParameter nvarchar(max),
						InsertedTask nvarchar(128),
						InsertedName nvarchar(128),
						InsertedParameter nvarchar(max)
					);
					DECLARE @thisTask nvarchar(128);
					DECLARE @version nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);
					SET @version = ''' + @version + ''';
			';
			SET @stmt += '
					IF (@Type = ''Parameter'')
					BEGIN
						IF (@Command = ''set'')
						BEGIN
							SET @Parameter = NULLIF(@Parameter, '''');

							IF NOT EXISTS (
								SELECT *
								FROM dbo.fhsmSchedules AS s
								WHERE (s.Task = @Task) AND (s.Name = @Name) AND (s.DeploymentStatus <> -1)
							)
							BEGIN
								SET @message = ''Invalid @Task:'''''' + COALESCE(NULLIF(@Task, ''''), ''<NULL>'') + '''''' and @Name:'''''' + COALESCE(NULLIF(@Name, ''''), ''<NULL>'') + '''''''';
								RAISERROR(@message, 0, 1) WITH NOWAIT;
								RETURN -11;
							END;

							--
							-- Register configuration changes
							--
							BEGIN
								WITH
								conf(Task, Name, Parameter) AS(
									SELECT
										@Task AS Task
										,@Name AS Name
										,@Parameter AS Parameter
								)
								MERGE dbo.fhsmSchedules AS tgt
								USING conf AS src ON (src.[Task] = tgt.[Task] COLLATE SQL_Latin1_General_CP1_CI_AS) AND (src.[Name] = tgt.[Name] COLLATE SQL_Latin1_General_CP1_CI_AS)
								-- Not testing for NULL as a NULL parameter is not allowed
								WHEN MATCHED AND (tgt.Parameter <> src.Parameter)
									THEN UPDATE
										SET tgt.Parameter = src.Parameter
								WHEN NOT MATCHED BY TARGET
									THEN INSERT(Task, Name, Parameter)
									VALUES(src.Task, src.Name, src.Parameter)
								OUTPUT
									$action,
									deleted.Task,
									deleted.Name,
									deleted.Parameter,
									inserted.Task,
									inserted.Name,
									inserted.Parameter
								INTO @parameterChanges;

								IF (@@ROWCOUNT <> 0)
								BEGIN
									SET @message = (
										SELECT ''Parameter is '''''' + COALESCE(src.InsertedParameter, ''<NULL>'') + '''''' - changed from '''''' + COALESCE(src.DeletedParameter, ''<NULL>'') + ''''''''
										FROM @parameterChanges AS src
									);
									IF (@message IS NOT NULL)
									BEGIN
										EXEC dbo.fhsmSPLog @name = @Name, @version = @version, @task = @thisTask, @type = ''Info'', @message = @message;
									END;
								END;
							END;
			';
			SET @stmt += '
						END
						ELSE BEGIN
							SET @message = ''Illegal Combination of @Type:'''''' + COALESCE(@Type, ''<NULL>'') + '''''' and @Command:'''''' + COALESCE(@Command, ''<NULL>'') + '''''''';
							RAISERROR(@message, 0, 1) WITH NOWAIT;
							RETURN -19;
						END;
					END
			';
			SET @stmt += '
					ELSE IF (@Type = ''Uninstall'')
					BEGIN
						--
						-- Place holder
						--
						SET @Type = @Type;
					END
			';
			SET @stmt += '
					ELSE BEGIN
						SET @message = ''Illegal @Type:'''''' + COALESCE(@Type, ''<NULL>'') + '''''''';
						RAISERROR(@message, 0, 1) WITH NOWAIT;
						RETURN -999;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPControlCapacity
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPControlCapacity';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;
	END;

	--
	-- Register retention
	--
	BEGIN
		WITH
		retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter)
		AS (
			SELECT
				1								AS Enabled
				,'dbo.fhsmAllocationUnits'		AS TableName
				,1								AS Sequence
				,'TimestampUTC'					AS TimeColumn
				,1								AS IsUtc
				,30								AS Days
				,NULL							AS Filter

			UNION ALL

			SELECT
				1								AS Enabled
				,'dbo.fhsmDatabaseSize'			AS TableName
				,1								AS Sequence
				,'TimestampUTC'					AS TimeColumn
				,1								AS IsUtc
				,180							AS Days
				,NULL							AS Filter

			UNION ALL

			SELECT
				1								AS Enabled
				,'dbo.fhsmDiskSize'				AS TableName
				,1								AS Sequence
				,'TimestampUTC'					AS TimeColumn
				,1								AS IsUtc
				,180							AS Days
				,NULL							AS Filter

			UNION ALL

			SELECT
				1								AS Enabled
				,'dbo.fhsmPartitionedIndexes'	AS TableName
				,1								AS Sequence
				,'TimestampUTC'					AS TimeColumn
				,1								AS IsUtc
				,730							AS Days
				,NULL							AS Filter

			UNION ALL

			SELECT
				1								AS Enabled
				,'dbo.fhsmTableSize'			AS TableName
				,1								AS Sequence
				,'TimestampUTC'					AS TimeColumn
				,1								AS IsUtc
				,60								AS Days
				,NULL							AS Filter

			UNION ALL

			SELECT
				1								AS Enabled
				,'dbo.fhsmVLFSize'				AS TableName
				,1								AS Sequence
				,'TimestampUTC'					AS TimeColumn
				,1								AS IsUtc
				,60								AS Days
				,NULL							AS Filter
		)
		MERGE dbo.fhsmRetentions AS tgt
		USING retention AS src ON (src.TableName = tgt.TableName) AND (src.Sequence = tgt.Sequence)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter)
			VALUES(src.Enabled, src.TableName, src.Sequence, src.TimeColumn, src.IsUtc, src.Days, src.Filter);
	END;

	--
	-- Register schedules
	--
	BEGIN
		WITH
		schedules(Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameter) AS(
			SELECT
				@enableCapacity										AS Enabled
				,0													AS DeploymentStatus
				,'Capacity'											AS Name
				,PARSENAME('dbo.fhsmSPCapacity', 1)					AS Task
				,12 * 60 * 60										AS ExecutionDelaySec
				,CAST('1900-1-1T07:00:00.0000' AS datetime2(0))		AS FromTime
				,CAST('1900-1-1T08:00:00.0000' AS datetime2(0))		AS ToTime
				,1, 1, 1, 1, 1, 1, 1								-- Monday..Sunday
				,'@Databases = ''USER_DATABASES, msdb, tempdb'''	AS Parameter
		)
		MERGE dbo.fhsmSchedules AS tgt
		USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameter)
			VALUES(src.Enabled, src.DeploymentStatus, src.Name, src.Task, src.ExecutionDelaySec, src.FromTime, src.ToTime, src.Monday, src.Tuesday, src.Wednesday, src.Thursday, src.Friday, src.Saturday, src.Sunday, src.Parameter);
	END;

	--
	-- Register dimensions
	--
	BEGIN
		WITH
		dimensions(
			DimensionName, DimensionKey
			,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
			,SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4, SrcColumn5
			,OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4, OutputColumn5
		) AS (
			--
			-- dbo.fhsmAllocationUnits
			--
			SELECT
				'File group' AS DimensionName
				,'FileGroupKey' AS DimensionKey
				,'dbo.fhsmAllocationUnits' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[FilegroupName]', NULL, NULL, NULL
				,'Database', 'File group', NULL, NULL, NULL

			UNION ALL

			SELECT
				'Index' AS DimensionName
				,'IndexKey' AS DimensionKey
				,'dbo.fhsmAllocationUnits' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'COALESCE(src.[IndexName], ''N.A.'')', NULL
				,'Database', 'Schema', 'Object', 'Index', NULL

			--
			-- dbo.fhsmDatabaseSize
			--
			UNION ALL

			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmDatabaseSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Database file' AS DimensionName
				,'DatabaseFileKey' AS DimensionKey
				,'dbo.fhsmDatabaseSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[LogicalName]', 'src.[PhysicalName]', 'CASE src.[Type] WHEN 0 THEN ''Data'' WHEN 1 THEN ''Log'' WHEN 2 THEN ''Filestream'' WHEN 4 THEN ''Fulltext'' ELSE ''Other'' END', 'src.[FilegroupName]'
				,'Database name', 'Logical name', 'Physical name', 'Type', 'File group'

			UNION ALL

			SELECT
				'Disk' AS DimensionName
				,'DiskKey' AS DimensionKey
				,'dbo.fhsmDatabaseSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[VolumeMountPoint]', NULL, NULL, NULL, NULL
				,'Disk', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'File group' AS DimensionName
				,'FileGroupKey' AS DimensionKey
				,'dbo.fhsmDatabaseSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[FilegroupName]', NULL, NULL, NULL
				,'Database', 'File group', NULL, NULL, NULL

			--
			-- dbo.fhsmDiskSize
			--
			UNION ALL

			SELECT
				'Disk' AS DimensionName
				,'DiskKey' AS DimensionKey
				,'dbo.fhsmDiskSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[VolumeMountPoint]', NULL, NULL, NULL, NULL
				,'Disk', NULL, NULL, NULL, NULL

			--
			-- dbo.fhsmPartitionedIndexes
			--
			UNION ALL

			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmPartitionedIndexes' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Schema' AS DimensionName
				,'SchemaKey' AS DimensionKey
				,'dbo.fhsmPartitionedIndexes' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', NULL, NULL, NULL
				,'Database', 'Schema', NULL, NULL, NULL

			UNION ALL

			SELECT
				'Object' AS DimensionName
				,'ObjectKey' AS DimensionKey
				,'dbo.fhsmPartitionedIndexes' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', NULL, NULL
				,'Database', 'Schema', 'Object', NULL, NULL

			UNION ALL

			SELECT
				'Index' AS DimensionName
				,'IndexKey' AS DimensionKey
				,'dbo.fhsmPartitionedIndexes' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'COALESCE(src.[IndexName], ''N.A.'')', NULL
				,'Database', 'Schema', 'Object', 'Index', NULL

			UNION ALL

			SELECT
				'File group' AS DimensionName
				,'FileGroupKey' AS DimensionKey
				,'dbo.fhsmPartitionedIndexes' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[PartitionFilegroupName]', NULL, NULL, NULL
				,'Database', 'File group', NULL, NULL, NULL

			--
			-- dbo.fhsmTableSize
			--
			UNION ALL

			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmTableSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Schema' AS DimensionName
				,'SchemaKey' AS DimensionKey
				,'dbo.fhsmTableSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', NULL, NULL, NULL
				,'Database', 'Schema', NULL, NULL, NULL

			UNION ALL

			SELECT
				'Object' AS DimensionName
				,'ObjectKey' AS DimensionKey
				,'dbo.fhsmTableSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', NULL, NULL
				,'Database', 'Schema', 'Object', NULL, NULL

			UNION ALL

			SELECT
				'Index' AS DimensionName
				,'IndexKey' AS DimensionKey
				,'dbo.fhsmTableSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'COALESCE(src.[IndexName], ''N.A.'')', NULL
				,'Database', 'Schema', 'Object', 'Index', NULL

			UNION ALL

			SELECT
				'Object partition' AS DimensionName
				,'ObjectPartitionKey' AS DimensionKey
				,'dbo.fhsmTableSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'CAST(src.[PartitionNumber] AS nvarchar)', NULL
				,'Database', 'Schema', 'Object', 'Partition', NULL

			UNION ALL

			SELECT
				'Index partition' AS DimensionName
				,'IndexPartitionKey' AS DimensionKey
				,'dbo.fhsmTableSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'COALESCE(src.[IndexName], ''N.A.'')', 'CAST(src.[PartitionNumber] AS nvarchar)'
				,'Database', 'Schema', 'Object', 'Index', 'Partition'

			--
			-- dbo.fhsmVLFSize
			--
			UNION ALL

			SELECT
				'Database file' AS DimensionName
				,'DatabaseFileKey' AS DimensionKey
				,'dbo.fhsmVLFSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', '', '', '', ''
				,'Database name', 'Logical name', 'Physical name', 'Type', 'File group'
		)
		MERGE dbo.fhsmDimensions AS tgt
		USING dimensions AS src ON (src.DimensionName = tgt.DimensionName) AND (src.SrcTable = tgt.SrcTable)
		WHEN MATCHED
			THEN UPDATE SET
				tgt.DimensionKey = src.DimensionKey
				,tgt.SrcTable = src.SrcTable
				,tgt.SrcAlias = src.SrcAlias
				,tgt.SrcWhere = src.SrcWhere
				,tgt.SrcDateColumn = src.SrcDateColumn
				,tgt.SrcColumn1 = src.SrcColumn1
				,tgt.SrcColumn2 = src.SrcColumn2
				,tgt.SrcColumn3 = src.SrcColumn3
				,tgt.SrcColumn4 = src.SrcColumn4
				,tgt.SrcColumn5 = src.SrcColumn5
				,tgt.OutputColumn1 = src.OutputColumn1
				,tgt.OutputColumn2 = src.OutputColumn2
				,tgt.OutputColumn3 = src.OutputColumn3
				,tgt.OutputColumn4 = src.OutputColumn4
				,tgt.OutputColumn5 = src.OutputColumn5
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(
				DimensionName, DimensionKey
				,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
				,SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4, SrcColumn5
				,OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4, OutputColumn5
			)
			VALUES(
				src.DimensionName, src.DimensionKey
				,src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn
				,src.SrcColumn1, src.SrcColumn2, src.SrcColumn3, src.SrcColumn4, src.SrcColumn5
				,src.OutputColumn1, src.OutputColumn2, src.OutputColumn3, src.OutputColumn4, src.OutputColumn5
			);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmAllocationUnits';
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmDatabaseSize';
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmDiskSize';
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmPartitionedIndexes';
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmTableSize';
	END;
END;
