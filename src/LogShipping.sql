SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableLogShipping bit;
	DECLARE @ignoreAutoIndex bit;

	SET @enableLogShipping = 0;
	SET @ignoreAutoIndex = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing LogShipping', 0, 1) WITH NOWAIT;
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
		SET @version = '2.12.0';

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
	-- Create tables
	--
	BEGIN
		--
		-- Create table dbo.fhsmLogShippingMonitorErrorDetail and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmLogShippingMonitorErrorDetail', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmLogShippingMonitorErrorDetail', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmLogShippingMonitorErrorDetail(
						Id int identity(1,1) NOT NULL
						,AgentId uniqueidentifier NOT NULL
						,AgentType tinyint NOT NULL
						,SessionId int NOT NULL
						,DatabaseName nvarchar(128) NULL
						,SequenceNumber int NOT NULL
						,LogTime datetime NOT NULL
						,LogTimeUTC datetime NOT NULL
						,Message nvarchar (4000) NOT NULL
						,Source nvarchar (4000) NOT NULL
						,HelpURL nvarchar (4000) NOT NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmLogShippingMonitorErrorDetail PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingMonitorErrorDetail')) AND (i.name = 'NC_fhsmLogShippingMonitorErrorDetail_LogTimeUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingMonitorErrorDetail_LogTimeUTC] to table dbo.fhsmLogShippingMonitorErrorDetail', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingMonitorErrorDetail_LogTimeUTC ON dbo.fhsmLogShippingMonitorErrorDetail(LogTimeUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingMonitorErrorDetail')) AND (i.name = 'NC_fhsmLogShippingMonitorErrorDetail_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingMonitorErrorDetail_TimestampUTC] to table dbo.fhsmLogShippingMonitorErrorDetail', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingMonitorErrorDetail_TimestampUTC ON dbo.fhsmLogShippingMonitorErrorDetail(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmLogShippingMonitorErrorDetail
			--
			BEGIN
				SET @objectName = 'dbo.fhsmLogShippingMonitorErrorDetail';
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
		-- Create table dbo.fhsmLogShippingMonitorHistoryDetail and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmLogShippingMonitorHistoryDetail', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmLogShippingMonitorHistoryDetail', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmLogShippingMonitorHistoryDetail(
						Id int identity(1,1) NOT NULL
						,AgentId uniqueidentifier NOT NULL
						,AgentType tinyint NOT NULL
						,SessionId int NOT NULL
						,DatabaseName nvarchar(128) NULL
						,SessionStatus tinyint NOT NULL
						,LogTime datetime NOT NULL
						,LogTimeUTC datetime NOT NULL
						,Message nvarchar (4000) NOT NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmLogShippingMonitorHistoryDetail PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingMonitorHistoryDetail')) AND (i.name = 'NC_fhsmLogShippingMonitorHistoryDetail_LogTimeUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingMonitorHistoryDetail_LogTimeUTC] to table dbo.fhsmLogShippingMonitorHistoryDetail', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingMonitorHistoryDetail_LogTimeUTC ON dbo.fhsmLogShippingMonitorHistoryDetail(LogTimeUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingMonitorHistoryDetail')) AND (i.name = 'NC_fhsmLogShippingMonitorHistoryDetail_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingMonitorHistoryDetail_TimestampUTC] to table dbo.fhsmLogShippingMonitorHistoryDetail', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingMonitorHistoryDetail_TimestampUTC ON dbo.fhsmLogShippingMonitorHistoryDetail(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmLogShippingMonitorHistoryDetail
			--
			BEGIN
				SET @objectName = 'dbo.fhsmLogShippingMonitorHistoryDetail';
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
		-- Create table dbo.fhsmLogShippingMonitorPrimary and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmLogShippingMonitorPrimary', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmLogShippingMonitorPrimary', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmLogShippingMonitorPrimary(
						Id int identity(1,1) NOT NULL
						,PrimaryServer nvarchar(128) NOT NULL
						,PrimaryDatabase nvarchar(128) NOT NULL
						,LastBackupDate datetime NULL
						,LastBackupDateUTC datetime NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmLogShippingMonitorPrimary PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF EXISTS (SELECT * FROM sys.columns AS c WHERE (c.object_id = OBJECT_ID('dbo.fhsmLogShippingMonitorPrimary')) AND (c.name = 'LastBackupDate') AND (c.is_nullable = 0))
			BEGIN
				RAISERROR('Changing column [LastBackupDate] on table dbo.fhsmLogShippingMonitorPrimary to be NULL''able', 0, 1) WITH NOWAIT;

				SET @stmt = '
					ALTER TABLE dbo.fhsmLogShippingMonitorPrimary ALTER COLUMN [LastBackupDate] datetime NULL;
				';
				EXEC(@stmt);
			END;

			IF EXISTS (SELECT * FROM sys.columns AS c WHERE (c.object_id = OBJECT_ID('dbo.fhsmLogShippingMonitorPrimary')) AND (c.name = 'LastBackupDateUTC') AND (c.is_nullable = 0))
			BEGIN
				IF EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingMonitorPrimary')) AND (i.name = 'NC_fhsmLogShippingMonitorPrimary_PrimaryServer_PrimaryDatabase_LastBackupDateUTC'))
				BEGIN
					RAISERROR('Dropping index [NC_fhsmLogShippingMonitorPrimary_PrimaryServer_PrimaryDatabase_LastBackupDateUTC] on table dbo.fhsmLogShippingMonitorPrimary before changing column LastBackupDate', 0, 1) WITH NOWAIT;

					SET @stmt = '
						DROP INDEX NC_fhsmLogShippingMonitorPrimary_PrimaryServer_PrimaryDatabase_LastBackupDateUTC ON dbo.fhsmLogShippingMonitorPrimary;
					';
					EXEC(@stmt);
				END;

				RAISERROR('Changing column [LastBackupDateUTC] on table dbo.fhsmLogShippingMonitorPrimary to be NULL''able', 0, 1) WITH NOWAIT;

				SET @stmt = '
					ALTER TABLE dbo.fhsmLogShippingMonitorPrimary ALTER COLUMN [LastBackupDateUTC] datetime NULL;
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingMonitorPrimary')) AND (i.name = 'NC_fhsmLogShippingMonitorPrimary_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingMonitorPrimary_TimestampUTC] to table dbo.fhsmLogShippingMonitorPrimary', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingMonitorPrimary_TimestampUTC ON dbo.fhsmLogShippingMonitorPrimary(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingMonitorPrimary')) AND (i.name = 'NC_fhsmLogShippingMonitorPrimary_PrimaryServer_PrimaryDatabase_LastBackupDateUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingMonitorPrimary_PrimaryServer_PrimaryDatabase_LastBackupDateUTC] to table dbo.fhsmLogShippingMonitorPrimary', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingMonitorPrimary_PrimaryServer_PrimaryDatabase_LastBackupDateUTC ON dbo.fhsmLogShippingMonitorPrimary(PrimaryServer, PrimaryDatabase, LastBackupDateUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmLogShippingMonitorPrimary
			--
			BEGIN
				SET @objectName = 'dbo.fhsmLogShippingMonitorPrimary';
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
		-- Create table dbo.fhsmLogShippingMonitorSecondary and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmLogShippingMonitorSecondary', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmLogShippingMonitorSecondary', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmLogShippingMonitorSecondary(
						Id int identity(1,1) NOT NULL
						,SecondaryServer nvarchar(128) NOT NULL
						,SecondaryDatabase nvarchar(128) NOT NULL
						,LastCopiedDate datetime NULL
						,LastCopiedDateUTC datetime NULL
						,LastRestoredDate datetime NULL
						,LastRestoredDateUTC datetime NULL
						,LastRestoredLatency int NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmLogShippingMonitorSecondary PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingMonitorSecondary')) AND (i.name = 'NC_fhsmLogShippingMonitorSecondary_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingMonitorSecondary_TimestampUTC] to table dbo.fhsmLogShippingMonitorSecondary', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingMonitorSecondary_TimestampUTC ON dbo.fhsmLogShippingMonitorSecondary(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingMonitorSecondary')) AND (i.name = 'NC_fhsmLogShippingMonitorSecondary_SecondaryServer_SecondaryDatabase_LastCopiedDateUTC_LastRestoredDateUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingMonitorSecondary_SecondaryServer_SecondaryDatabase_LastCopiedDateUTC_LastRestoredDateUTC] to table dbo.fhsmLogShippingMonitorSecondary', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingMonitorSecondary_SecondaryServer_SecondaryDatabase_LastCopiedDateUTC_LastRestoredDateUTC ON dbo.fhsmLogShippingMonitorSecondary(SecondaryServer, SecondaryDatabase, LastCopiedDateUTC, LastRestoredDateUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmLogShippingMonitorSecondary
			--
			BEGIN
				SET @objectName = 'dbo.fhsmLogShippingMonitorSecondary';
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
		-- Create table dbo.fhsmLogShippingPrimaryDatabases and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmLogShippingPrimaryDatabases', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmLogShippingPrimaryDatabases', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmLogShippingPrimaryDatabases(
						Id int identity(1,1) NOT NULL
						,PrimaryDatabase nvarchar(128) NOT NULL
						,LastBackupDate datetime NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmLogShippingPrimaryDatabases PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF EXISTS (SELECT * FROM sys.columns AS c WHERE (c.object_id = OBJECT_ID('dbo.fhsmLogShippingPrimaryDatabases')) AND (c.name = 'LastBackupDate') AND (c.is_nullable = 0))
			BEGIN
				IF EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingPrimaryDatabases')) AND (i.name = 'NC_fhsmLogShippingPrimaryDatabases_PrimaryDatabase_LastBackupDate'))
				BEGIN
					RAISERROR('Dropping index [NC_fhsmLogShippingPrimaryDatabases_PrimaryDatabase_LastBackupDate] on table dbo.fhsmLogShippingPrimaryDatabases before changing column LastBackupDate', 0, 1) WITH NOWAIT;

					SET @stmt = '
						DROP INDEX NC_fhsmLogShippingPrimaryDatabases_PrimaryDatabase_LastBackupDate ON dbo.fhsmLogShippingPrimaryDatabases;
					';
					EXEC(@stmt);
				END;

				RAISERROR('Changing column [LastBackupDate] on table dbo.fhsmLogShippingPrimaryDatabases to be NULL''able', 0, 1) WITH NOWAIT;

				SET @stmt = '
					ALTER TABLE dbo.fhsmLogShippingPrimaryDatabases ALTER COLUMN [LastBackupDate] datetime NULL;
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingPrimaryDatabases')) AND (i.name = 'NC_fhsmLogShippingPrimaryDatabases_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingPrimaryDatabases_TimestampUTC] to table dbo.fhsmLogShippingPrimaryDatabases', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingPrimaryDatabases_TimestampUTC ON dbo.fhsmLogShippingPrimaryDatabases(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingPrimaryDatabases')) AND (i.name = 'NC_fhsmLogShippingPrimaryDatabases_PrimaryDatabase_LastBackupDate'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingPrimaryDatabases_PrimaryDatabase_LastBackupDate] to table dbo.fhsmLogShippingPrimaryDatabases', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingPrimaryDatabases_PrimaryDatabase_LastBackupDate ON dbo.fhsmLogShippingPrimaryDatabases(PrimaryDatabase, LastBackupDate)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmLogShippingPrimaryDatabases
			--
			BEGIN
				SET @objectName = 'dbo.fhsmLogShippingPrimaryDatabases';
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
		-- Create table dbo.fhsmLogShippingSecondary and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmLogShippingSecondary', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmLogShippingSecondary', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmLogShippingSecondary(
						Id int identity(1,1) NOT NULL
						,PrimaryServer nvarchar(128) NOT NULL
						,PrimaryDatabase nvarchar(128) NOT NULL
						,LastCopiedDate datetime NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmLogShippingSecondary PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingSecondary')) AND (i.name = 'NC_fhsmLogShippingSecondary_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingSecondary_TimestampUTC] to table dbo.fhsmLogShippingSecondary', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingSecondary_TimestampUTC ON dbo.fhsmLogShippingSecondary(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingSecondary')) AND (i.name = 'NC_fhsmLogShippingSecondary_PrimaryServer_PrimaryDatabase_LastCopiedDate'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingSecondary_PrimaryServer_PrimaryDatabase_LastCopiedDate] to table dbo.fhsmLogShippingSecondary', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingSecondary_PrimaryServer_PrimaryDatabase_LastCopiedDate ON dbo.fhsmLogShippingSecondary(PrimaryServer, PrimaryDatabase, LastCopiedDate)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmLogShippingSecondary
			--
			BEGIN
				SET @objectName = 'dbo.fhsmLogShippingSecondary';
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
		-- Create table dbo.fhsmLogShippingSecondaryDatabases and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmLogShippingSecondaryDatabases', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmLogShippingSecondaryDatabases', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmLogShippingSecondaryDatabases(
						Id int identity(1,1) NOT NULL
						,SecondaryDatabase nvarchar(128) NOT NULL
						,LastRestoredDate datetime NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmLogShippingSecondaryDatabases PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingSecondaryDatabases')) AND (i.name = 'NC_fhsmLogShippingSecondaryDatabases_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingSecondaryDatabases_TimestampUTC] to table dbo.fhsmLogShippingSecondaryDatabases', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingSecondaryDatabases_TimestampUTC ON dbo.fhsmLogShippingSecondaryDatabases(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingSecondaryDatabases')) AND (i.name = 'NC_fhsmLogShippingSecondaryDatabases_SecondaryDatabase_LastRestoredDate'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingSecondaryDatabases_SecondaryDatabase_LastRestoredDate] to table dbo.fhsmLogShippingSecondaryDatabases', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingSecondaryDatabases_SecondaryDatabase_LastRestoredDate ON dbo.fhsmLogShippingSecondaryDatabases(SecondaryDatabase, LastRestoredDate)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmLogShippingSecondaryDatabases
			--
			BEGIN
				SET @objectName = 'dbo.fhsmLogShippingSecondaryDatabases';
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
		-- Create table dbo.fhsmLogShippingState and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmLogShippingState', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmLogShippingState', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmLogShippingState(
						Id int identity(1,1) NOT NULL
						,Query int NOT NULL
						,ServerName nvarchar(128) NOT NULL
						,DatabaseName nvarchar(128) NOT NULL
						,[Key] nvarchar(128) NOT NULL
						,Value nvarchar(max) NOT NULL
						,ValidFrom datetime NOT NULL
						,ValidTo datetime NOT NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmLogShippingState PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingState')) AND (i.name = 'NC_fhsmLogShippingState_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingState_TimestampUTC] to table dbo.fhsmLogShippingState', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingState_TimestampUTC ON dbo.fhsmLogShippingState(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingState')) AND (i.name = 'NC_fhsmLogShippingState_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingState_Timestamp] to table dbo.fhsmLogShippingState', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingState_Timestamp ON dbo.fhsmLogShippingState(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingState')) AND (i.name = 'NC_fhsmLogShippingState_Query_ServerName_DatabaseName_Key_ValidTo'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingState_Query_ServerName_DatabaseName_Key_ValidTo] to table dbo.fhsmLogShippingState', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingState_Query_ServerName_DatabaseName_Key_ValidTo ON dbo.fhsmLogShippingState(Query, ServerName, DatabaseName, [Key], ValidTo) INCLUDE(Value)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmLogShippingState')) AND (i.name = 'NC_fhsmLogShippingState_ValidTo_Query_ServerName_DatabaseName_Key'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmLogShippingState_ValidTo_Query_ServerName_DatabaseName_Key] to table dbo.fhsmLogShippingState', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmLogShippingState_ValidTo_Query_ServerName_DatabaseName_Key ON dbo.fhsmLogShippingState(ValidTo, Query, ServerName, DatabaseName, [Key]) INCLUDE(Value)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmLogShippingState
			--
			BEGIN
				SET @objectName = 'dbo.fhsmLogShippingState';
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
		-- Create fact view @pbiSchema.[Log shipping monitor error details]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor error details') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor error details') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor error details') + '
				AS
				SELECT
					lsmed.AgentType
					,lsmed.SessionId
					,lsmed.DatabaseName
					,lsmed.SequenceNumber
					,lsmed.LogTime
					,lsmed.Message
					,lsmed.Source
					,lsmed.HelpURL
					,CAST(lsmed.LogTime AS date) AS Date
					,(DATEPART(HOUR, lsmed.LogTime) * 60 * 60) + (DATEPART(MINUTE, lsmed.LogTime) * 60) + (DATEPART(SECOND, lsmed.LogTime)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(lsmed.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
				FROM dbo.fhsmLogShippingMonitorErrorDetail AS lsmed;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping monitor error details]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor error details');
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
		-- Create fact view @pbiSchema.[Log shipping monitor history details]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor history details') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor history details') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor history details') + '
				AS
				SELECT
					lsmhd.AgentType
					,lsmhd.SessionId
					,lsmhd.DatabaseName
					,lsmhd.SessionStatus
					,lsmhd.LogTime
					,lsmhd.Message
					,CAST(lsmhd.LogTime AS date) AS Date
					,(DATEPART(HOUR, lsmhd.LogTime) * 60 * 60) + (DATEPART(MINUTE, lsmhd.LogTime) * 60) + (DATEPART(SECOND, lsmhd.LogTime)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(lsmhd.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
				FROM dbo.fhsmLogShippingMonitorHistoryDetail AS lsmhd;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping monitor history details]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor history details');
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
		-- Create fact view @pbiSchema.[Log shipping monitor primaries]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor primaries') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor primaries') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor primaries') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				WITH
				rawData AS (
					SELECT
						lsmp.PrimaryServer
						,lsmp.PrimaryDatabase
						,lsmp.LastBackupDate
						,lsmp.LastBackupDateUTC
						,ROW_NUMBER() OVER(PARTITION BY lsmp.PrimaryServer, lsmp.PrimaryDatabase ORDER BY lsmp.LastBackupDateUTC) AS Idx
					FROM dbo.fhsmLogShippingMonitorPrimary AS lsmp
				)
				';
			END;
			SET @stmt += '
				SELECT
					lsmp.PrimaryServer
					,lsmp.PrimaryDatabase
					,CASE lsmpServer.Cnt
						WHEN 1 THEN lsmp.PrimaryDatabase
						ELSE lsmp.PrimaryDatabase + '' - '' + lsmp.PrimaryServer
					END AS PrimaryDatabaseServer
					,lsmp.LastBackupDate
					,lsmp.LastBackupDateUTC
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
					,DATEDIFF(MINUTE, previousLSMP.LastBackupDateUTC, lsmp.LastBackupDateUTC) AS TimeSincePreviousBackup
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
					,DATEDIFF(MINUTE, LAG(lsmp.LastBackupDateUTC) OVER(PARTITION BY lsmp.PrimaryServer, lsmp.PrimaryDatabase ORDER BY lsmp.LastBackupDateUTC), lsmp.LastBackupDateUTC) AS TimeSincePreviousBackup
				';
			END;
			SET @stmt += '
					,CAST(lsmp.LastBackupDate AS date) AS Date
					,(DATEPART(HOUR, lsmp.LastBackupDate) * 60 * 60) + (DATEPART(MINUTE, lsmp.LastBackupDate) * 60) + (DATEPART(SECOND, lsmp.LastBackupDate)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(lsmp.PrimaryDatabase, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(lsmp.PrimaryServer,   DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS ServerKey
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				FROM rawData AS lsmp
				LEFT OUTER JOIN rawData AS previousLSMP ON (previousLSMP.PrimaryServer = lsmp.PrimaryServer) AND (previousLSMP.PrimaryDatabase = lsmp.PrimaryDatabase) AND (previousLSMP.Idx = lsmp.Idx - 1)
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
				FROM dbo.fhsmLogShippingMonitorPrimary AS lsmp
				';
			END;
			SET @stmt += '
				CROSS APPLY (SELECT COUNT(DISTINCT t.PrimaryServer) AS Cnt FROM dbo.fhsmLogShippingMonitorPrimary AS t) AS lsmpServer;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping monitor primaries]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor primaries');
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
		-- Create fact view @pbiSchema.[Log shipping monitor secondaries]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondaries') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondaries') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondaries') + '
				AS
				SELECT
					lsms.SecondaryServer
					,lsms.SecondaryDatabase
					,CASE lsmsServer.Cnt
						WHEN 1 THEN lsms.SecondaryDatabase
						ELSE lsms.SecondaryDatabase + '' - '' + lsms.SecondaryServer
					END AS SecondaryDatabaseServer
					,lsms.LastCopiedDate
					,lsms.LastCopiedDateUTC
					,lsms.LastRestoredDate
					,lsms.LastRestoredDateUTC
					,lsms.LastRestoredLatency
					,CAST(lsms.LastRestoredDate AS date) AS Date
					,(DATEPART(HOUR, lsms.LastRestoredDate) * 60 * 60) + (DATEPART(MINUTE, lsms.LastRestoredDate) * 60) + (DATEPART(SECOND, lsms.LastRestoredDate)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(lsms.SecondaryDatabase, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(lsms.SecondaryServer,   DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS ServerKey
				FROM dbo.fhsmLogShippingMonitorSecondary AS lsms
				CROSS APPLY (SELECT COUNT(DISTINCT t.SecondaryServer) AS Cnt FROM dbo.fhsmLogShippingMonitorSecondary AS t) AS lsmsServer;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping monitor secondaries]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondaries');
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
		-- Create fact view @pbiSchema.[Log shipping monitor secondary copies]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondary copies') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondary copies') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondary copies') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				WITH
				rawData AS (
					SELECT
						lsms.SecondaryServer
						,lsms.SecondaryDatabase
						,lsms.LastCopiedDate
						,lsms.LastCopiedDateUTC
						,ROW_NUMBER() OVER(PARTITION BY lsms.SecondaryServer, lsms.SecondaryDatabase ORDER BY lsms.LastCopiedDateUTC) AS Idx
					FROM (
						SELECT
							DISTINCT
							lsms.SecondaryServer
							,lsms.SecondaryDatabase
							,lsms.LastCopiedDate
							,lsms.LastCopiedDateUTC
						FROM dbo.fhsmLogShippingMonitorSecondary AS lsms
					) AS lsms
				)
				';
			END;
			SET @stmt += '
				SELECT
					t.SecondaryServer
					,t.SecondaryDatabase
					,t.SecondaryDatabaseServer
					,t.LastCopiedDate
					,t.LastCopiedDateUTC
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
					,DATEDIFF(MINUTE, t.previousLastCopiedDateUTC, t.LastCopiedDateUTC) AS TimeSincePreviousCopy
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
					,DATEDIFF(MINUTE, LAG(t.LastCopiedDateUTC) OVER(PARTITION BY t.SecondaryServer, t.SecondaryDatabase ORDER BY t.LastCopiedDateUTC), t.LastCopiedDateUTC) AS TimeSincePreviousCopy
				';
			END;
			SET @stmt += '
					,CAST(t.LastCopiedDate AS date) AS Date
					,(DATEPART(HOUR, t.LastCopiedDate) * 60 * 60) + (DATEPART(MINUTE, t.LastCopiedDate) * 60) + (DATEPART(SECOND, t.LastCopiedDate)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(t.SecondaryDatabase, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(t.SecondaryServer,   DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS ServerKey
				FROM (
					SELECT
			';
			IF (@productVersion1 > 10)
			BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
						DISTINCT
				';
			END;
			SET @stmt += '
						lsms.SecondaryServer
						,lsms.SecondaryDatabase
						,CASE lsmsServer.Cnt
							WHEN 1 THEN lsms.SecondaryDatabase
							ELSE lsms.SecondaryDatabase + '' - '' + lsms.SecondaryServer
						END AS SecondaryDatabaseServer
						,lsms.LastCopiedDate
						,lsms.LastCopiedDateUTC
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
						,previousLSMS.LastCopiedDateUTC AS previousLastCopiedDateUTC
					FROM rawData AS lsms
					LEFT OUTER JOIN rawData AS previousLSMS ON (previousLSMS.SecondaryServer = lsms.SecondaryServer) AND (previousLSMS.SecondaryDatabase = lsms.SecondaryDatabase) AND (previousLSMS.Idx = lsms.Idx - 1)
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
					FROM dbo.fhsmLogShippingMonitorSecondary AS lsms
				';
			END;
			SET @stmt += '
					CROSS APPLY (SELECT COUNT(DISTINCT t.SecondaryServer) AS Cnt FROM dbo.fhsmLogShippingMonitorSecondary AS t) AS lsmsServer
				) AS t;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping monitor secondary copies]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondary copies');
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
		-- Create fact view @pbiSchema.[Log shipping monitor secondary restores]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondary restores') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondary restores') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondary restores') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				WITH
				rawData AS (
					SELECT
						lsms.SecondaryServer
						,lsms.SecondaryDatabase
						,lsms.LastRestoredDate
						,lsms.LastRestoredDateUTC
						,lsms.LastRestoredLatency
						,ROW_NUMBER() OVER(PARTITION BY lsms.SecondaryServer, lsms.SecondaryDatabase ORDER BY lsms.LastRestoredDateUTC) AS Idx
					FROM (
						SELECT
							DISTINCT
							lsms.SecondaryServer
							,lsms.SecondaryDatabase
							,lsms.LastRestoredDate
							,lsms.LastRestoredDateUTC
							,lsms.LastRestoredLatency
						FROM dbo.fhsmLogShippingMonitorSecondary AS lsms
					) AS lsms
				)
				';
			END;
			SET @stmt += '
				SELECT
					t.SecondaryServer
					,t.SecondaryDatabase
					,t.SecondaryDatabaseServer
					,t.LastRestoredDate
					,t.LastRestoredDateUTC
					,t.LastRestoredLatency
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
					,DATEDIFF(MINUTE, t.previousLastRestoredDateUTC, t.LastRestoredDateUTC) AS TimeSincePreviousRestore
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
					,DATEDIFF(MINUTE, LAG(t.LastRestoredDateUTC) OVER(PARTITION BY t.SecondaryServer, t.SecondaryDatabase ORDER BY t.LastRestoredDateUTC), t.LastRestoredDateUTC) AS TimeSincePreviousRestore
				';
			END;
			SET @stmt += '
					,CAST(t.LastRestoredDate AS date) AS Date
					,(DATEPART(HOUR, t.LastRestoredDate) * 60 * 60) + (DATEPART(MINUTE, t.LastRestoredDate) * 60) + (DATEPART(SECOND, t.LastRestoredDate)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(t.SecondaryDatabase, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(t.SecondaryServer,   DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS ServerKey
				FROM (
					SELECT
			';
			IF (@productVersion1 > 10)
			BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
						DISTINCT
				';
			END;
			SET @stmt += '
						lsms.SecondaryServer
						,lsms.SecondaryDatabase
						,CASE lsmsServer.Cnt
							WHEN 1 THEN lsms.SecondaryDatabase
							ELSE lsms.SecondaryDatabase + '' - '' + lsms.SecondaryServer
						END AS SecondaryDatabaseServer
						,lsms.LastRestoredDate
						,lsms.LastRestoredDateUTC
						,lsms.LastRestoredLatency
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
						,previousLSMS.LastRestoredDateUTC AS previousLastRestoredDateUTC
					FROM rawData AS lsms
					LEFT OUTER JOIN rawData AS previousLSMS ON (previousLSMS.SecondaryServer = lsms.SecondaryServer) AND (previousLSMS.SecondaryDatabase = lsms.SecondaryDatabase) AND (previousLSMS.Idx = lsms.Idx - 1)
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
					FROM dbo.fhsmLogShippingMonitorSecondary AS lsms
				';
			END;
			SET @stmt += '
					CROSS APPLY (SELECT COUNT(DISTINCT t.SecondaryServer) AS Cnt FROM dbo.fhsmLogShippingMonitorSecondary AS t) AS lsmsServer
				) AS t;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping monitor secondary restores]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondary restores');
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
		-- Create fact view @pbiSchema.[Log shipping primary databases]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping primary databases') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping primary databases') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping primary databases') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				WITH
				rawData AS (
					SELECT
						lspd.PrimaryDatabase
						,lspd.LastBackupDate
						,ROW_NUMBER() OVER(PARTITION BY lspd.PrimaryDatabase ORDER BY lspd.LastBackupDate) AS Idx
					FROM dbo.fhsmLogShippingPrimaryDatabases AS lspd
				)
				';
			END;
			SET @stmt += '
				SELECT
					lspd.PrimaryDatabase
					,lspd.LastBackupDate
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
					,DATEDIFF(MINUTE, previousLSPD.LastBackupDate, lspd.LastBackupDate) AS TimeSincePreviousBackup
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
					,DATEDIFF(MINUTE, LAG(lspd.LastBackupDate) OVER(PARTITION BY lspd.PrimaryDatabase ORDER BY lspd.LastBackupDate), lspd.LastBackupDate) AS TimeSincePreviousBackup
				';
			END;
			SET @stmt += '
					,CAST(lspd.LastBackupDate AS date) AS Date
					,(DATEPART(HOUR, lspd.LastBackupDate) * 60 * 60) + (DATEPART(MINUTE, lspd.LastBackupDate) * 60) + (DATEPART(SECOND, lspd.LastBackupDate)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(lspd.PrimaryDatabase, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey

			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				FROM rawData AS lspd
				LEFT OUTER JOIN rawData AS previousLSPD ON (previousLSPD.PrimaryDatabase = lspd.PrimaryDatabase) AND (previousLSPD.Idx = lspd.Idx - 1);
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
				FROM dbo.fhsmLogShippingPrimaryDatabases AS lspd;
				';
			END;
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping primary databases]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping primary databases');
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
		-- Create fact view @pbiSchema.[Log shipping secondaries]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondaries') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondaries') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondaries') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				WITH
				rawData AS (
					SELECT
						lss.PrimaryServer
						,lss.PrimaryDatabase
						,lss.LastCopiedDate
						,ROW_NUMBER() OVER(PARTITION BY lss.PrimaryServer, lss.PrimaryDatabase ORDER BY lss.LastCopiedDate) AS Idx
					FROM dbo.fhsmLogShippingSecondary AS lss
				)
				';
			END;
			SET @stmt += '
				SELECT
					lss.PrimaryServer
					,lss.PrimaryDatabase
					,CASE lssServer.Cnt
						WHEN 1 THEN lss.PrimaryDatabase
						ELSE lss.PrimaryDatabase + '' - '' + lss.PrimaryServer
					END AS PrimaryDatabaseServer
					,lss.LastCopiedDate
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
					,DATEDIFF(MINUTE, previousLSS.LastCopiedDate, lss.LastCopiedDate) AS TimeSincePreviousCopy
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
					,DATEDIFF(MINUTE, LAG(lss.LastCopiedDate) OVER(PARTITION BY lss.PrimaryServer, lss.PrimaryDatabase ORDER BY lss.LastCopiedDate), lss.LastCopiedDate) AS TimeSincePreviousCopy
				';
			END;
			SET @stmt += '
					,CAST(lss.LastCopiedDate AS date) AS Date
					,(DATEPART(HOUR, lss.LastCopiedDate) * 60 * 60) + (DATEPART(MINUTE, lss.LastCopiedDate) * 60) + (DATEPART(SECOND, lss.LastCopiedDate)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(lss.PrimaryDatabase, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(lss.PrimaryServer,   DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS ServerKey
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				FROM rawData AS lss
				LEFT OUTER JOIN rawData AS previousLSS ON (previousLSS.PrimaryServer = lss.PrimaryServer) AND (previousLSS.PrimaryDatabase = lss.PrimaryDatabase) AND (previousLSS.Idx = lss.Idx - 1)
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
				FROM dbo.fhsmLogShippingSecondary AS lss
				';
			END;
			SET @stmt += '
				CROSS APPLY (SELECT COUNT(DISTINCT t.PrimaryServer) AS Cnt FROM dbo.fhsmLogShippingSecondary AS t) AS lssServer;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping secondaries]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondaries');
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
		-- Create fact view @pbiSchema.[Log shipping secondary databases]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondary databases') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondary databases') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondary databases') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				WITH
				rawData AS (
					SELECT
						lssd.SecondaryDatabase
						,lssd.LastRestoredDate
						,ROW_NUMBER() OVER(PARTITION BY lssd.SecondaryDatabase ORDER BY lssd.LastRestoredDate) AS Idx
					FROM dbo.fhsmLogShippingSecondaryDatabases AS lssd
				)
				';
			END;
			SET @stmt += '
				SELECT
					lssd.SecondaryDatabase
					,lssd.LastRestoredDate
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
					,DATEDIFF(MINUTE, previousLSSD.LastRestoredDate, lssd.LastRestoredDate) AS TimeSincePreviousRestore
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
					,DATEDIFF(MINUTE, LAG(lssd.LastRestoredDate) OVER(PARTITION BY lssd.SecondaryDatabase ORDER BY lssd.LastRestoredDate), lssd.LastRestoredDate) AS TimeSincePreviousRestore
				';
			END;
			SET @stmt += '
					,CAST(lssd.LastRestoredDate AS date) AS Date
					,(DATEPART(HOUR, lssd.LastRestoredDate) * 60 * 60) + (DATEPART(MINUTE, lssd.LastRestoredDate) * 60) + (DATEPART(SECOND, lssd.LastRestoredDate)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(lssd.SecondaryDatabase, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				FROM rawData AS lssd
				LEFT OUTER JOIN rawData AS previousLSSD ON (previousLSSD.SecondaryDatabase = lssd.SecondaryDatabase) AND (previousLSSD.Idx = lssd.Idx - 1);
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
				FROM dbo.fhsmLogShippingSecondaryDatabases AS lssd;
				';
			END;
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping secondary databases]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondary databases');
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
		-- Log shipping monitor primary database state - Query 11
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor primary database state') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor primary database state') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor primary database state') + '
				AS
					SELECT
						pvt.ServerName                             AS PrimaryServer
						,pvt.DatabaseName                          AS PrimaryDatabase
						,CAST(pvt.backup_threshold AS int)         AS BackupThreshold
						,CAST(pvt.threshold_alert AS int)          AS ThresholdAlert
						,CAST(pvt.history_retention_period AS int) AS HistoryRetentionPeriod
						,(SELECT MIN(t.Timestamp) FROM dbo.fhsmLogShippingState AS t WHERE (t.ServerName = pvt.ServerName) AND (t.DatabaseName = pvt.DatabaseName) AND (t.Query = 11) AND (t.ValidTo = ''9999-12-31T23:59:59'')) AS MinTimestamp
						,(SELECT MAX(t.Timestamp) FROM dbo.fhsmLogShippingState AS t WHERE (t.ServerName = pvt.ServerName) AND (t.DatabaseName = pvt.DatabaseName) AND (t.Query = 11) AND (t.ValidTo = ''9999-12-31T23:59:59'')) AS MaxTimestamp
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.ServerName,   DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS ServerKey
					FROM (
						SELECT lsState.ServerName, lsState.DatabaseName, lsState.[Key], lsState.Value AS _Value_
						FROM dbo.fhsmLogShippingState AS lsState
						WHERE (lsState.Query = 11) AND (lsState.ValidTo = ''9999-12-31T23:59:59'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([backup_threshold], [threshold_alert], [history_retention_period])
					) AS pvt;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping monitor primary database state]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor primary database state');
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
		-- Log shipping monitor secondary database state - Query 12
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondary database state') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondary database state') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondary database state') + '
				AS
					SELECT
						pvt.ServerName                            AS SecondaryServer
						,pvt.DatabaseName                         AS SecondaryDatabase
						,pvt.primary_server                       AS PrimaryServer
						,pvt.primary_database                     AS PrimaryDatabase
						,CAST(pvt.restore_threshold AS int)       AS RestoreThreshold
						,CAST(pvt.threshold_alert AS int)         AS ThresholdAlert
						,CAST(pvt.threshold_alert_enabled AS bit) AS ThresholdAlertEnabled
						,CASE CAST(pvt.threshold_alert_enabled AS bit)
							WHEN 0 THEN ''No''
							WHEN 1 THEN ''Yes''
							ELSE ''N.A.''
						END AS ThresholdAlertEnabledTxt
						,CAST(pvt.history_retention_period AS int) AS HistoryRetentionPeriod
						,(SELECT MIN(t.Timestamp) FROM dbo.fhsmLogShippingState AS t WHERE (t.ServerName = pvt.ServerName) AND (t.DatabaseName = pvt.DatabaseName) AND (t.Query = 12) AND (t.ValidTo = ''9999-12-31T23:59:59'')) AS MinTimestamp
						,(SELECT MAX(t.Timestamp) FROM dbo.fhsmLogShippingState AS t WHERE (t.ServerName = pvt.ServerName) AND (t.DatabaseName = pvt.DatabaseName) AND (t.Query = 12) AND (t.ValidTo = ''9999-12-31T23:59:59'')) AS MaxTimestamp
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.ServerName,   DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS ServerKey
					FROM (
						SELECT lsState.ServerName, lsState.DatabaseName, lsState.[Key], lsState.Value AS _Value_
						FROM dbo.fhsmLogShippingState AS lsState
						WHERE (lsState.Query = 12) AND (lsState.ValidTo = ''9999-12-31T23:59:59'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([primary_server], [primary_database], [restore_threshold], [threshold_alert], [threshold_alert_enabled], [history_retention_period])
					) AS pvt;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping monitor secondary database state]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping monitor secondary database state');
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
		-- Log shipping primary database state - Query 21
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping primary database state') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping primary database state') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping primary database state') + '
				AS
					SELECT
						pvt.DatabaseName                          AS PrimaryDatabase
						,pvt.backup_directory                     AS BackupDirectory
						,pvt.backup_share                         AS BackupShare
						,CAST(pvt.backup_retention_period AS int) AS BackupRetentionPeriod
						,pvt.monitor_server                       AS MonitorServer
						,CAST(pvt.user_specified_monitor AS bit)  AS UserSpecifiedMonitor
						,CASE CAST(pvt.user_specified_monitor AS bit)
							WHEN 0 THEN ''No''
							WHEN 1 THEN ''Yes''
							ELSE ''N.A.''
						END AS UserSpecifiedMonitorTxt
						,CAST(pvt.monitor_server_security_mode AS bit) AS MonitorServerSecurityMode
						,CASE CAST(pvt.monitor_server_security_mode AS bit)
							WHEN 0 THEN ''SQL Server Authentication''
							WHEN 1 THEN ''Windows Authentication''
							ELSE ''N.A.''
						END AS MonitorServerSecurityModeTxt
						,CAST(pvt.backup_compression AS int)           AS BackupCompression
						,CASE CAST(pvt.backup_compression AS int)
							WHEN 0 THEN ''Disabled''
							WHEN 1 THEN ''Enabled''
							WHEN 2 THEN ''Uses the server configuration''
							ELSE ''N.A.''
						END AS BackupCompressionTxt
						,(SELECT MIN(t.Timestamp) FROM dbo.fhsmLogShippingState AS t WHERE (t.DatabaseName = pvt.DatabaseName) AND (t.Query = 21) AND (t.ValidTo = ''9999-12-31T23:59:59'')) AS MinTimestamp
						,(SELECT MAX(t.Timestamp) FROM dbo.fhsmLogShippingState AS t WHERE (t.DatabaseName = pvt.DatabaseName) AND (t.Query = 21) AND (t.ValidTo = ''9999-12-31T23:59:59'')) AS MaxTimestamp
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					FROM (
						SELECT lsState.DatabaseName, lsState.[Key], lsState.Value AS _Value_
						FROM dbo.fhsmLogShippingState AS lsState
						WHERE (lsState.Query = 21) AND (lsState.ValidTo = ''9999-12-31T23:59:59'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([backup_directory], [backup_share], [backup_retention_period], [monitor_server], [user_specified_monitor], [monitor_server_security_mode], [backup_compression])
					) AS pvt;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping primary database state]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping primary database state');
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
		-- Log shipping primary secondary database state - Query 22
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping primary secondary database state') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping primary secondary database state') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping primary secondary database state') + '
				AS
					SELECT
						lsState.ServerName    AS SecondaryServer
						,lsState.DatabaseName AS SecondaryDatabase
						,(SELECT MIN(t.Timestamp) FROM dbo.fhsmLogShippingState AS t WHERE (t.ServerName = lsState.ServerName) AND (t.DatabaseName = lsState.DatabaseName) AND (t.Query = 22) AND (t.ValidTo = ''9999-12-31T23:59:59'')) AS MinTimestamp
						,(SELECT MAX(t.Timestamp) FROM dbo.fhsmLogShippingState AS t WHERE (t.ServerName = lsState.ServerName) AND (t.DatabaseName = lsState.DatabaseName) AND (t.Query = 22) AND (t.ValidTo = ''9999-12-31T23:59:59'')) AS MaxTimestamp
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(lsState.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(lsState.ServerName,   DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS ServerKey
					FROM dbo.fhsmLogShippingState AS lsState
					WHERE (lsState.Query = 22) AND (lsState.ValidTo = ''9999-12-31T23:59:59'');
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping primary secondary database state]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping primary secondary database state');
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
		-- Log shipping secondary database state - Query 31
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondary database state') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondary database state') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondary database state') + '
				AS
					SELECT
						pvt.DatabaseName                AS SecondaryDatabase
						,CAST(pvt.restore_delay AS int) AS RestoreDelay
						,CAST(pvt.restore_all AS bit)   AS RestoreAll
						,CASE CAST(pvt.restore_all AS bit)
							WHEN 0 THEN ''No''
							WHEN 1 THEN ''Yes''
							ELSE ''N.A.''
						END AS RestoreAllTxt
						,CAST(pvt.restore_mode AS bit) AS RestoreMode
						,CASE CAST(pvt.restore_mode AS bit)
							WHEN 0 THEN ''NORECOVERY''
							WHEN 1 THEN ''STANDBY''
							ELSE ''N.A.''
						END AS RestoreModeTxt
						,CAST(pvt.disconnect_users AS bit) AS DisconnectUsers
						,CASE CAST(pvt.disconnect_users AS bit)
							WHEN 0 THEN ''No''
							WHEN 1 THEN ''Yes''
							ELSE ''N.A.''
						END AS DisconnectUsersTxt
						,CAST(pvt.block_size AS int)        AS BlockSize
						,CAST(pvt.buffer_count AS int)      AS BufferCount
						,CAST(pvt.max_transfer_size AS int) AS MaxTransferSize
						,(SELECT MIN(t.Timestamp) FROM dbo.fhsmLogShippingState AS t WHERE (t.DatabaseName = pvt.DatabaseName) AND (t.Query = 31) AND (t.ValidTo = ''9999-12-31T23:59:59'')) AS MinTimestamp
						,(SELECT MAX(t.Timestamp) FROM dbo.fhsmLogShippingState AS t WHERE (t.DatabaseName = pvt.DatabaseName) AND (t.Query = 31) AND (t.ValidTo = ''9999-12-31T23:59:59'')) AS MaxTimestamp
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					FROM (
						SELECT lsState.DatabaseName, lsState.[Key], lsState.Value AS _Value_
						FROM dbo.fhsmLogShippingState AS lsState
						WHERE (lsState.Query = 31) AND (lsState.ValidTo = ''9999-12-31T23:59:59'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([restore_delay], [restore_all], [restore_mode], [disconnect_users], [block_size], [buffer_count], [max_transfer_size])
					) AS pvt;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping secondary database state]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondary database state');
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
		-- Log shipping secondary primary database state - Query 32
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondary primary database state') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondary primary database state') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondary primary database state') + '
				AS
					SELECT
						pvt.ServerName                                 AS PrimaryServer
						,pvt.DatabaseName                              AS PrimaryDatabase
						,pvt.backup_source_directory                   AS BackupSourceDirectory
						,pvt.backup_destination_directory              AS BackupDestinationDirectory
						,CAST(pvt.file_retention_period AS int)        AS FileRetentionPeriod
						,pvt.monitor_server                            AS MonitorServer
						,CAST(pvt.monitor_server_security_mode AS bit) AS MonitorServerSecurityMode
						,CASE CAST(pvt.monitor_server_security_mode AS bit)
							WHEN 0 THEN ''SQL Server Authentication''
							WHEN 1 THEN ''Windows Authentication''
							ELSE ''N.A.''
						END AS MonitorServerSecurityModeTxt
						,CAST(pvt.user_specified_monitor AS bit)  AS UserSpecifiedMonitor
						,CASE CAST(pvt.user_specified_monitor AS bit)
							WHEN 0 THEN ''No''
							WHEN 1 THEN ''Yes''
							ELSE ''N.A.''
						END AS UserSpecifiedMonitorTxt
						,(SELECT MIN(t.Timestamp) FROM dbo.fhsmLogShippingState AS t WHERE (t.ServerName = pvt.ServerName) AND (t.DatabaseName = pvt.DatabaseName) AND (t.Query = 32) AND (t.ValidTo = ''9999-12-31T23:59:59'')) AS MinTimestamp
						,(SELECT MAX(t.Timestamp) FROM dbo.fhsmLogShippingState AS t WHERE (t.ServerName = pvt.ServerName) AND (t.DatabaseName = pvt.DatabaseName) AND (t.Query = 32) AND (t.ValidTo = ''9999-12-31T23:59:59'')) AS MaxTimestamp
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.ServerName,   DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS ServerKey
					FROM (
						SELECT lsState.ServerName, lsState.DatabaseName, lsState.[Key], lsState.Value AS _Value_
						FROM dbo.fhsmLogShippingState AS lsState
						WHERE (lsState.Query = 32) AND (lsState.ValidTo = ''9999-12-31T23:59:59'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([backup_source_directory], [backup_destination_directory], [file_retention_period], [monitor_server], [monitor_server_security_mode], [user_specified_monitor])
					) AS pvt;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping secondary primary database state]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping secondary primary database state');
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
		-- Create fact view @pbiSchema.[Log shipping state history]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping state history') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping state history') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping state history') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				WITH
				rawData AS (
					SELECT
						lsState.Query
						,lsState.ServerName
						,lsState.DatabaseName
						,lsState.[Key]
						,lsState.Value
						,lsState.TimestampUTC
						,lsState.ValidFrom
						,lsState.ValidTo
						,ROW_NUMBER() OVER(PARTITION BY lsState.Query, lsState.ServerName, lsState.DatabaseName, lsState.[Key] ORDER BY lsState.ValidTo DESC) AS Idx
					FROM dbo.fhsmLogShippingState AS lsState
				)
				';
			END;
			SET @stmt += '
				SELECT
					CASE a.Query
						WHEN 11 THEN ''Monitor primary database''
						WHEN 12 THEN ''Monitor secondary database''
						WHEN 21 THEN ''Primary database''
						WHEN 22 THEN ''Primary secondary database''
						WHEN 31 THEN ''Secondary database''
						WHEN 32 THEN ''Secondary primary database''
						ELSE ''??''
					END AS Type
					,a.ServerName
					,a.DatabaseName
					,CASE a.[Key]
						WHEN ''backup_compression'' THEN ''Backup compression''
						WHEN ''backup_destination_directory'' THEN ''Backup destination directory''
						WHEN ''backup_directory'' THEN ''Backup directory''
						WHEN ''backup_retention_period'' THEN ''Backup retention period''
						WHEN ''backup_share'' THEN ''Backup share''
						WHEN ''backup_source_directory'' THEN ''Backup source directory''
						WHEN ''backup_threshold'' THEN ''Backup threshold''
						WHEN ''block_size'' THEN ''Block size''
						WHEN ''buffer_count'' THEN ''Buffer count''
						WHEN ''disconnect_users'' THEN ''Disconnect users''
						WHEN ''file_retention_period'' THEN ''File retention period''
						WHEN ''history_retention_period'' THEN ''History retention period''
						WHEN ''max_transfer_size'' THEN ''Max. transfer size''
						WHEN ''monitor_server'' THEN ''Monitor server''
						WHEN ''monitor_server_security_mode'' THEN ''Monitor server security mode''
						WHEN ''primary_database'' THEN ''Primary database''
						WHEN ''primary_server'' THEN ''Primary server''
						WHEN ''restore_all'' THEN ''Restore all''
						WHEN ''restore_delay'' THEN ''Restore delay''
						WHEN ''restore_mode'' THEN ''Restore mode''
						WHEN ''restore_threshold'' THEN ''Restore threshold''
						WHEN ''threshold_alert'' THEN ''Threshold alert''
						WHEN ''threshold_alert_enabled'' THEN ''Threshold alert enabled''
						WHEN ''user_specified_monitor'' THEN ''User specified monitor''
						ELSE a.[Key]
					END AS [Key]
					,a.ValidFrom
					,NULLIF(a.ValidTo, ''9999-12-31T23:59:59'') AS ValidTo
					,CASE a.[Key]
						WHEN ''backup_compression''
							THEN CASE a.Value
								WHEN 0 THEN ''False''
								WHEN 1 THEN ''True''
								ELSE ''?:'' + a.Value
							END
						WHEN ''disconnect_users''
							THEN CASE a.Value
								WHEN 0 THEN ''False''
								WHEN 1 THEN ''True''
								ELSE ''?:'' + a.Value
							END
						WHEN ''monitor_server_security_mode''
							THEN CASE a.Value
								WHEN 0 THEN ''SQL Server Authentication''
								WHEN 1 THEN ''Windows Authentication''
								ELSE ''?:'' + a.Value
							END
						WHEN ''restore_all''
							THEN CASE a.Value
								WHEN 0 THEN ''False''
								WHEN 1 THEN ''True''
								ELSE ''?:'' + a.Value
							END
						WHEN ''restore_mode''
							THEN CASE a.Value
								WHEN 0 THEN ''NORECOVERY''
								WHEN 1 THEN ''STANDBY''
								ELSE ''?:'' + a.Value
							END
						WHEN ''threshold_alert_enabled''
							THEN CASE a.Value
								WHEN 0 THEN ''False''
								WHEN 1 THEN ''True''
								ELSE ''?:'' + a.Value
							END
						WHEN ''user_specified_monitor''
							THEN CASE a.Value
								WHEN 0 THEN ''False''
								WHEN 1 THEN ''True''
								ELSE ''?:'' + a.Value
							END
						ELSE a.Value
					END AS Value
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.ServerName,   DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS ServerKey
			';
			SET @stmt += '
				FROM (
					SELECT
						lsState.Query, lsState.ServerName, lsState.DatabaseName, lsState.[Key], lsState.Value, lsState.TimestampUTC, lsState.ValidFrom, lsState.ValidTo
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
						,previousLSState.Value AS PreviousValue
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
						,LAG(lsState.Value) OVER(PARTITION BY lsState.Query, lsState.ServerName, lsState.DatabaseName, lsState.[Key] ORDER BY lsState.ValidTo DESC) AS PreviousValue
				';
			END;
			SET @stmt += '
					FROM (
						SELECT DISTINCT lsState.ServerName, lsState.DatabaseName
						FROM dbo.fhsmLogShippingState AS lsState
						WHERE (lsState.ValidTo = ''9999-12-31T23:59:59'')
					) AS toCheck
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
					INNER JOIN rawData AS lsState ON (lsState.ServerName = toCheck.ServerName) AND (lsState.DatabaseName = toCheck.DatabaseName)
					LEFT OUTER JOIN rawData AS previousLSState ON (previousLSState.Query = lsState.Query) AND (previousLSState.ServerName = lsState.ServerName) AND (previousLSState.DatabaseName = lsState.DatabaseName) AND (previousLSState.[Key] = lsState.[Key]) AND (previousLSState.Idx = lsState.Idx - 1)
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
					INNER JOIN dbo.fhsmLogShippingState AS lsState ON (lsState.ServerName = toCheck.ServerName) AND (lsState.DatabaseName = toCheck.DatabaseName)
				';
			END;
			SET @stmt += '
					WHERE
						(lsState.[Key] IN (
							''backup_compression'', ''backup_destination_directory'', ''backup_directory''
							,''backup_retention_period'', ''backup_share'', ''backup_source_directory''
							,''backup_threshold'', ''block_size'', ''buffer_count''
							,''disconnect_users'', ''file_retention_period''
							,''history_retention_period'', ''max_transfer_size''
							,''monitor_server'', ''monitor_server_security_mode''
							,''primary_database'', ''primary_server''
							,''restore_all'', ''restore_delay'', ''restore_mode''
							,''restore_threshold'', ''threshold_alert'', ''threshold_alert_enabled''
							,''user_specified_monitor''
						))
				) AS a
				WHERE ((a.Value <> '''') AND (a.Value <> a.PreviousValue) OR (a.PreviousValue IS NULL));
				';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Log shipping state history]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log shipping state history');
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
		-- Create stored procedure dbo.fhsmSPLogShipping
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPLogShipping'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPLogShipping AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPLogShipping (
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameter nvarchar(max);
					DECLARE @thisTask nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);
					SET @version = ''' + @version + ''';

					--
					-- Get the parameter for the command
					--
					BEGIN
						SET @parameter = dbo.fhsmFNGetTaskParameter(@thisTask, @name);
					END;
			';
			SET @stmt += '
					--
					-- Collect data
					--
					BEGIN
						SELECT
							@now = SYSDATETIME()
							,@nowUTC = SYSUTCDATETIME();
			';
			--
			-- Collect fact data
			--
			SET @stmt += '
						--
						-- Collect fact data
						--
						BEGIN
			';
			SET @stmt += '
							--
							-- Get log_shipping_monitor_error_detail
							--
							BEGIN
								INSERT INTO dbo.fhsmLogShippingMonitorErrorDetail(
									AgentId, AgentType, SessionId
									,DatabaseName, SequenceNumber
									,LogTime, LogTimeUTC
									,Message, Source, HelpURL
									,TimestampUTC, Timestamp
								)
								SELECT
									lsmed.agent_id, lsmed.agent_type, lsmed.session_id
									,lsmed.database_name, lsmed.sequence_number
									,lsmed.log_time, lsmed.log_time_utc
									,lsmed.message, lsmed.source, lsmed.help_url
									,@nowUTC, @now
								FROM msdb.dbo.log_shipping_monitor_error_detail AS lsmed
								WHERE NOT EXISTS(
									SELECT *
									FROM dbo.fhsmLogShippingMonitorErrorDetail AS t
									WHERE
										(t.AgentId = lsmed.agent_id)
										AND (t.AgentType = lsmed.agent_type)
										AND (t.SessionId = lsmed.session_id)
										AND (t.DatabaseName COLLATE DATABASE_DEFAULT = lsmed.database_name)
										AND (t.SequenceNumber = lsmed.sequence_number)
										AND (t.LogTimeUTC = lsmed.log_time_utc)
								);
							END;
			';
			SET @stmt += '
							--
							-- Get log_shipping_monitor_history_detail
							--
							BEGIN
								INSERT INTO dbo.fhsmLogShippingMonitorHistoryDetail(
									AgentId, AgentType, SessionId
									,DatabaseName, SessionStatus
									,LogTime, LogTimeUTC
									,Message
									,TimestampUTC, Timestamp
								)
								SELECT
									lsmhd.agent_id, lsmhd.agent_type, lsmhd.session_id
									,lsmhd.database_name, lsmhd.session_status
									,lsmhd.log_time, lsmhd.log_time_utc
									,lsmhd.message
									,@nowUTC, @now
								FROM msdb.dbo.log_shipping_monitor_history_detail AS lsmhd
								WHERE 
									(lsmhd.session_status NOT IN (0, 1, 2))
									AND NOT EXISTS(
										SELECT *
										FROM dbo.fhsmLogShippingMonitorHistoryDetail AS t
										WHERE
											(t.AgentId = lsmhd.agent_id)
											AND (t.AgentType = lsmhd.agent_type)
											AND (t.SessionId = lsmhd.session_id)
											AND (t.DatabaseName COLLATE DATABASE_DEFAULT = lsmhd.database_name)
											AND (t.SessionStatus = lsmhd.session_status)
											AND (t.LogTimeUTC = lsmhd.log_time_utc)
									);
							END;
			';
			SET @stmt += '
							--
							-- Get log_shipping_monitor_primary
							--
							BEGIN
								INSERT INTO dbo.fhsmLogShippingMonitorPrimary(
									PrimaryServer, PrimaryDatabase
									,LastBackupDate, LastBackupDateUTC
									,TimestampUTC, Timestamp
								)
								SELECT
									lsmp.primary_server, lsmp.primary_database
									,lsmp.last_backup_date, lsmp.last_backup_date_utc
									,@nowUTC, @now
								FROM msdb.dbo.log_shipping_monitor_primary AS lsmp
								WHERE NOT EXISTS(
									SELECT *
									FROM dbo.fhsmLogShippingMonitorPrimary AS t
									WHERE
										(t.PrimaryServer COLLATE DATABASE_DEFAULT = lsmp.primary_server)
										AND (t.PrimaryDatabase COLLATE DATABASE_DEFAULT = lsmp.primary_database)
										AND (t.LastBackupDateUTC = lsmp.last_backup_date_utc)
								);
							END;
			';
			SET @stmt += '
							--
							-- Get log_shipping_monitor_secondary
							--
							BEGIN
								INSERT INTO dbo.fhsmLogShippingMonitorSecondary(
									SecondaryServer, SecondaryDatabase
									,LastCopiedDate, LastCopiedDateUTC
									,LastRestoredDate, LastRestoredDateUTC, LastRestoredLatency
									,TimestampUTC, Timestamp
								)
								SELECT
									lsms.secondary_server, lsms.secondary_database
									,lsms.last_copied_date, lsms.last_copied_date_utc
									,lsms.last_restored_date, lsms.last_restored_date_utc, lsms.last_restored_latency
									,@nowUTC, @now
								FROM msdb.dbo.log_shipping_monitor_secondary AS lsms
								WHERE NOT EXISTS(
									SELECT *
									FROM dbo.fhsmLogShippingMonitorSecondary AS t
									WHERE
										(t.SecondaryServer COLLATE DATABASE_DEFAULT = lsms.secondary_server)
										AND (t.SecondaryDatabase COLLATE DATABASE_DEFAULT = lsms.secondary_database)
										AND ((t.LastCopiedDateUTC = lsms.last_copied_date_utc) OR ((t.LastCopiedDateUTC IS NULL) AND (lsms.last_copied_date_utc IS NULL)))
										AND (t.LastRestoredDateUTC = lsms.last_restored_date_utc)
								);
							END;
			';
			SET @stmt += '
							--
							-- Get log_shipping_primary_databases
							--
							BEGIN
								INSERT INTO dbo.fhsmLogShippingPrimaryDatabases(PrimaryDatabase, LastBackupDate, TimestampUTC, Timestamp)
								SELECT
									lspd.primary_database
									,lspd.last_backup_date
									,@nowUTC
									,@now
								FROM msdb.dbo.log_shipping_primary_databases AS lspd
								WHERE NOT EXISTS(
									SELECT *
									FROM dbo.fhsmLogShippingPrimaryDatabases AS t
									WHERE
										(t.PrimaryDatabase COLLATE DATABASE_DEFAULT = lspd.primary_database)
										AND (t.LastBackupDate = lspd.last_backup_date)
								);
							END;
			';
			SET @stmt += '
							--
							-- Get log_shipping_secondary
							--
							BEGIN
								INSERT INTO dbo.fhsmLogShippingSecondary(
									PrimaryServer, PrimaryDatabase
									,LastCopiedDate
									,TimestampUTC, Timestamp
								)
								SELECT
									lss.primary_server, lss.primary_database
									,lss.last_copied_date
									,@nowUTC, @now
								FROM msdb.dbo.log_shipping_secondary AS lss
								WHERE NOT EXISTS(
									SELECT *
									FROM dbo.fhsmLogShippingSecondary AS t
									WHERE
										(t.PrimaryServer COLLATE DATABASE_DEFAULT = lss.primary_server)
										AND (t.PrimaryDatabase COLLATE DATABASE_DEFAULT = lss.primary_database)
										AND ((t.LastCopiedDate = lss.last_copied_date) OR ((t.LastCopiedDate IS NULL) AND (lss.last_copied_date IS NULL)))
								);
							END;
			';
			SET @stmt += '
							--
							-- Get log_shipping_secondary_databases
							--
							BEGIN
								INSERT INTO dbo.fhsmLogShippingSecondaryDatabases(
									SecondaryDatabase
									,LastRestoredDate
									,TimestampUTC, Timestamp
								)
								SELECT
									lssd.secondary_database
									,lssd.last_restored_date
									,@nowUTC, @now
								FROM msdb.dbo.log_shipping_secondary_databases AS lssd
								WHERE NOT EXISTS(
									SELECT *
									FROM dbo.fhsmLogShippingSecondaryDatabases AS t
									WHERE
										(t.SecondaryDatabase COLLATE DATABASE_DEFAULT = lssd.secondary_database)
										AND (t.LastRestoredDate = lssd.last_restored_date)
								);
							END;
			';
			SET @stmt += '
						END;
			';
			--
			-- Collect state data
			--
			SET @stmt += '
						--
						-- Collect state data
						--
						BEGIN
			';
			SET @stmt += '
							IF (OBJECT_ID(''tempdb..#config'') IS NOT NULL) DROP TABLE #config;

							CREATE TABLE #config(
								Query int NOT NULL
								,ServerName nvarchar(128) NOT NULL
								,DatabaseName nvarchar(128) NOT NULL
								,[Key] nvarchar(128) NOT NULL
								,Value nvarchar(max) NULL
								,PRIMARY KEY(Query, ServerName, DatabaseName, [Key])
							);
			';
			SET @stmt += '
							--
							-- Get log_shipping_monitor_primary configuration values (Query 11)
							--
							BEGIN
								INSERT INTO #config(Query, ServerName, DatabaseName, [Key], Value)
								SELECT 11 AS Query, unpvt.primary_server, unpvt.primary_database, unpvt.K, unpvt.V
								FROM (
									SELECT
										CAST(lsmp.primary_server            AS nvarchar(max)) AS primary_server
										,CAST(lsmp.primary_database         AS nvarchar(max)) AS primary_database
										,CAST(lsmp.backup_threshold         AS nvarchar(max)) AS backup_threshold
										,CAST(lsmp.threshold_alert          AS nvarchar(max)) AS threshold_alert
										,CAST(lsmp.history_retention_period AS nvarchar(max)) AS history_retention_period
									FROM msdb.dbo.log_shipping_monitor_primary AS lsmp WITH (NOLOCK)
								) AS p
								UNPIVOT(
									V FOR K IN (
										p.backup_threshold
										,p.threshold_alert
										,p.history_retention_period
									)
								) AS unpvt OPTION (RECOMPILE);
							END;
			';
			SET @stmt += '
							--
							-- Get log_shipping_monitor_secondary configuration values (Query 12)
							--
							BEGIN
								INSERT INTO #config(Query, ServerName, DatabaseName, [Key], Value)
								SELECT 12 AS Query, unpvt.secondary_server, unpvt.secondary_database, unpvt.K, unpvt.V
								FROM (
									SELECT
										CAST(lsms.secondary_server                           AS nvarchar(max)) AS secondary_server
										,CAST(lsms.secondary_database                        AS nvarchar(max)) AS secondary_database
										,CAST(lsms.primary_server COLLATE DATABASE_DEFAULT   AS nvarchar(max)) AS primary_server
										,CAST(lsms.primary_database COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS primary_database
										,CAST(lsms.restore_threshold                         AS nvarchar(max)) AS restore_threshold
										,CAST(lsms.threshold_alert                           AS nvarchar(max)) AS threshold_alert
										,CAST(lsms.threshold_alert_enabled                   AS nvarchar(max)) AS threshold_alert_enabled
										,CAST(lsms.history_retention_period                  AS nvarchar(max)) AS history_retention_period
									FROM msdb.dbo.log_shipping_monitor_secondary AS lsms WITH (NOLOCK)
								) AS p
								UNPIVOT(
									V FOR K IN (
										p.primary_server
										,p.primary_database
										,p.restore_threshold
										,p.threshold_alert
										,p.threshold_alert_enabled
										,p.history_retention_period
									)
								) AS unpvt OPTION (RECOMPILE);
							END;
			';
			SET @stmt += '
							--
							-- Get log_shipping_primary_databases configuration values (Query 21)
							--
							BEGIN
								INSERT INTO #config(Query, ServerName, DatabaseName, [Key], Value)
								SELECT 21 AS Query, '''', unpvt.primary_database, unpvt.K, unpvt.V
								FROM (
									SELECT
										CAST(lspd.primary_database                           AS nvarchar(max)) AS primary_database
										,CAST(lspd.backup_directory COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS backup_directory
										,CAST(lspd.backup_share COLLATE DATABASE_DEFAULT     AS nvarchar(max)) AS backup_share
										,CAST(lspd.backup_retention_period                   AS nvarchar(max))  AS backup_retention_period
										,CAST(lspd.monitor_server COLLATE DATABASE_DEFAULT   AS nvarchar(max)) AS monitor_server
										,CAST(lspd.user_specified_monitor                    AS nvarchar(max)) AS user_specified_monitor
										,CAST(lspd.monitor_server_security_mode              AS nvarchar(max)) AS monitor_server_security_mode
										,CAST(lspd.backup_compression                        AS nvarchar(max)) AS backup_compression
									FROM msdb.dbo.log_shipping_primary_databases AS lspd WITH (NOLOCK)
								) AS p
								UNPIVOT(
									V FOR K IN (
										p.backup_directory
										,p.backup_share
										,p.backup_retention_period
										,p.monitor_server
										,p.user_specified_monitor
										,p.monitor_server_security_mode
										,p.backup_compression
									)
								) AS unpvt OPTION (RECOMPILE);
							END;
			';
			SET @stmt += '
							--
							-- Get log_shipping_primary_secondaries configuration values (Query 22)
							--
							BEGIN
								INSERT INTO #config(Query, ServerName, DatabaseName, [Key], Value)
								SELECT 22 AS Query, p.secondary_server, p.secondary_database, '''', ''''
								FROM (
									SELECT
										CAST(lsps.secondary_server    AS nvarchar(max)) AS secondary_server
										,CAST(lsps.secondary_database AS nvarchar(max)) AS secondary_database
									FROM msdb.dbo.log_shipping_primary_secondaries AS lsps WITH (NOLOCK)
								) AS p;
							END;
			';
			SET @stmt += '
							--
							-- Get log_shipping_secondary_databases configuration values (Query 31)
							--
							BEGIN
								INSERT INTO #config(Query, ServerName, DatabaseName, [Key], Value)
								SELECT 31 AS Query, '''', unpvt.secondary_database, unpvt.K, unpvt.V
								FROM (
									SELECT
										CAST(lssd.secondary_database  AS nvarchar(max)) AS secondary_database
										,CAST(lssd.restore_delay      AS nvarchar(max)) AS restore_delay
										,CAST(lssd.restore_all        AS nvarchar(max)) AS restore_all
										,CAST(lssd.restore_mode       AS nvarchar(max)) AS restore_mode
										,CAST(lssd.disconnect_users   AS nvarchar(max)) AS disconnect_users
										,CAST(lssd.block_size         AS nvarchar(max)) AS block_size
										,CAST(lssd.buffer_count       AS nvarchar(max)) AS buffer_count
										,CAST(lssd.max_transfer_size  AS nvarchar(max)) AS max_transfer_size
									FROM msdb.dbo.log_shipping_secondary_databases AS lssd WITH (NOLOCK)
								) AS p
								UNPIVOT(
									V FOR K IN (
										p.restore_delay
										,p.restore_all
										,p.restore_mode
										,p.disconnect_users
										,p.block_size
										,p.buffer_count
										,p.max_transfer_size
									)
								) AS unpvt OPTION (RECOMPILE);
							END;
			';
			SET @stmt += '
							--
							-- Get log_shipping_secondary configuration values (Query 32)
							--
							BEGIN
								INSERT INTO #config(Query, ServerName, DatabaseName, [Key], Value)
								SELECT 32 AS Query, unpvt.primary_server, unpvt.primary_database, unpvt.K, unpvt.V
								FROM (
									SELECT
										CAST(lss.primary_server                                         AS nvarchar(max)) AS primary_server
										,CAST(lss.primary_database                                      AS nvarchar(max)) AS primary_database
										,CAST(lss.backup_source_directory COLLATE DATABASE_DEFAULT      AS nvarchar(max)) AS backup_source_directory
										,CAST(lss.backup_destination_directory COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS backup_destination_directory
										,CAST(lss.file_retention_period                                 AS nvarchar(max)) AS file_retention_period
										,CAST(lss.monitor_server COLLATE DATABASE_DEFAULT               AS nvarchar(max)) AS monitor_server
										,CAST(lss.monitor_server_security_mode                          AS nvarchar(max)) AS monitor_server_security_mode
										,CAST(lss.user_specified_monitor                                AS nvarchar(max)) AS user_specified_monitor
									FROM msdb.dbo.log_shipping_secondary AS lss WITH (NOLOCK)
								) AS p
								UNPIVOT(
									V FOR K IN (
										p.backup_source_directory
										,p.backup_destination_directory
										,p.file_retention_period
										,p.monitor_server
										,p.monitor_server_security_mode
										,p.user_specified_monitor
									)
								) AS unpvt OPTION (RECOMPILE);
							END;
			';
			--
			-- Process collected state data
			--
			SET @stmt += '
							--
							-- Remove records where Value is NULL
							--
							BEGIN
								DELETE tgt
								FROM #config AS tgt
								WHERE (tgt.Value IS NULL);
							END;

							--
							-- Update current record ValidTo as it is no longer valid
							--
							BEGIN
								UPDATE tgt
								SET tgt.ValidTo = @nowUTC
								FROM dbo.fhsmLogShippingState AS tgt
								LEFT OUTER JOIN #config AS src
									ON (src.Query = tgt.Query)
									AND (src.ServerName COLLATE DATABASE_DEFAULT = tgt.ServerName)
									AND (src.DatabaseName COLLATE DATABASE_DEFAULT = tgt.DatabaseName)
									AND (src.[Key] COLLATE DATABASE_DEFAULT = tgt.[Key])
								WHERE
									(
										(src.Query IS NULL)
										OR ((src.Value COLLATE DATABASE_DEFAULT <> tgt.Value) OR (src.Value IS NULL AND tgt.Value IS NOT NULL) OR (src.Value IS NOT NULL AND tgt.Value IS NULL))
									) AND (tgt.ValidTo = ''9999-12-31T23:59:59'');
							END;

							--
							-- Insert new records
							--
							BEGIN
								INSERT INTO dbo.fhsmLogShippingState(Query, ServerName, DatabaseName, [Key], Value, ValidFrom, ValidTo, TimestampUTC, Timestamp)
								SELECT src.Query, src.ServerName, src.DatabaseName, src.[Key], src.Value, @nowUTC AS ValidFrom, ''9999-12-31T23:59:59'' AS ValidTo, @nowUTC, @now
								FROM #config AS src
								WHERE NOT EXISTS (
									SELECT *
									FROM dbo.fhsmLogShippingState AS tgt
									WHERE
										(tgt.Query = src.Query)
										AND (tgt.ServerName COLLATE DATABASE_DEFAULT = src.ServerName)
										AND (tgt.DatabaseName COLLATE DATABASE_DEFAULT = src.DatabaseName)
										AND (tgt.[Key] COLLATE DATABASE_DEFAULT = src.[Key])
										AND ((tgt.Value COLLATE DATABASE_DEFAULT = src.Value) OR (tgt.Value IS NULL AND src.Value IS NULL)) AND (tgt.ValidTo = ''9999-12-31T23:59:59'')
								);
							END;
			';
			SET @stmt += '
						END;
			';
			SET @stmt += '
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPLogShipping
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPLogShipping';
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
		retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter) AS(
			SELECT 1, 'dbo.fhsmLogShippingMonitorErrorDetail',   1, 'TimestampUTC', 1, 90, NULL
			UNION ALL
			SELECT 1, 'dbo.fhsmLogShippingMonitorHistoryDetail', 1, 'TimestampUTC', 1, 90, NULL
			UNION ALL
			SELECT 1, 'dbo.fhsmLogShippingMonitorPrimary',       1, 'TimestampUTC', 1, 40, NULL
			UNION ALL
			SELECT 1, 'dbo.fhsmLogShippingMonitorSecondary',     1, 'TimestampUTC', 1, 40, NULL
			UNION ALL
			SELECT 1, 'dbo.fhsmLogShippingPrimaryDatabases',     1, 'TimestampUTC', 1, 40, NULL
			UNION ALL
			SELECT 1, 'dbo.fhsmLogShippingSecondary',            1, 'TimestampUTC', 1, 40, NULL
			UNION ALL
			SELECT 1, 'dbo.fhsmLogShippingSecondaryDatabases',   1, 'TimestampUTC', 1, 40, NULL
			UNION ALL
			SELECT 1, 'dbo.fhsmLogShippingState',                1, 'TimestampUTC', 1, 5 * 365, NULL
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
		schedules(Type, Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameter) AS(
			SELECT
				1												AS type
				,@enableLogShipping								AS Enabled
				,0												AS DeploymentStatus
				,'Log shipping'									AS Name
				,PARSENAME('dbo.fhsmSPLogShipping', 1)			AS Task
				,2 * 60											AS ExecutionDelaySec
				,CAST('1900-1-1T00:00:00.0000' AS datetime2(0))	AS FromTime
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))	AS ToTime
				,1, 1, 1, 1, 1, 1, 1							-- Monday..Sunday
				,NULL											AS Parameter
		)
		MERGE dbo.fhsmSchedules AS tgt
		USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(Type, Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameter)
			VALUES(src.Type, src.Enabled, src.DeploymentStatus, src.Name, src.Task, src.ExecutionDelaySec, src.FromTime, src.ToTime, src.Monday, src.Tuesday, src.Wednesday, src.Thursday, src.Friday, src.Saturday, src.Sunday, src.Parameter);
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
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmLogShippingMonitorErrorDetail' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmLogShippingMonitorHistoryDetail' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmLogShippingMonitorPrimary' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[PrimaryDatabase]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Server' AS DimensionName
				,'ServerKey' AS DimensionKey
				,'dbo.fhsmLogShippingMonitorPrimary' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[PrimaryServer]', NULL, NULL, NULL, NULL
				,'Server', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmLogShippingMonitorSecondary' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[SecondaryDatabase]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Server' AS DimensionName
				,'ServerKey' AS DimensionKey
				,'dbo.fhsmLogShippingMonitorSecondary' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[SecondaryServer]', NULL, NULL, NULL, NULL
				,'Server', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmLogShippingPrimaryDatabases' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[PrimaryDatabase]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmLogShippingSecondary' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[PrimaryDatabase]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Server' AS DimensionName
				,'ServerKey' AS DimensionKey
				,'dbo.fhsmLogShippingSecondary' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[PrimaryServer]', NULL, NULL, NULL, NULL
				,'Server', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmLogShippingSecondaryDatabases' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[SecondaryDatabase]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmLogShippingState' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Server' AS DimensionName
				,'ServerKey' AS DimensionKey
				,'dbo.fhsmLogShippingState' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[ServerName]', NULL, NULL, NULL, NULL
				,'Server', NULL, NULL, NULL, NULL
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
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmLogShippingMonitorErrorDetail', @ignoreAutoIndex = @ignoreAutoIndex;
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmLogShippingMonitorHistoryDetail', @ignoreAutoIndex = @ignoreAutoIndex;
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmLogShippingMonitorPrimary', @ignoreAutoIndex = @ignoreAutoIndex;
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmLogShippingMonitorSecondary', @ignoreAutoIndex = @ignoreAutoIndex;
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmLogShippingPrimaryDatabases', @ignoreAutoIndex = @ignoreAutoIndex;
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmLogShippingSecondary', @ignoreAutoIndex = @ignoreAutoIndex;
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmLogShippingSecondaryDatabases', @ignoreAutoIndex = @ignoreAutoIndex;
	END;
END;
