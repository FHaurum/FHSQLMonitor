SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableAgentJobsPerformance bit;

	SET @enableAgentJobsPerformance = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing AgentJobsPerformance', 0, 1) WITH NOWAIT;
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
		SET @version = '2.9';

		SET @productVersion = CAST(SERVERPROPERTY('ProductVersion') AS nvarchar);
		SET @productStartPos = 1;
		SET @productEndPos = CHARINDEX('.', @productVersion, @productStartPos);
		SET @productVersion1 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
		SET @productStartPos = @productEndPos + 1;
		SET @productEndPos = CHARINDEX('.', @productVersion, @productStartPos);
		SET @productVersion2 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
		SET @productStartPos = @productEndPos + 1;
		SET @productEndPos = CHARINDEX('.', @productVersion, @productStartPos);
		SET @productVersion3 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
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
	-- Create tables and indexes
	--
	BEGIN
		--
		-- Create table dbo.fhsmAgentJobsPerformance and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmAgentJobsPerformance', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmAgentJobsPerformance', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmAgentJobsPerformance(
						Id int identity(1,1) NOT NULL
						,Name nvarchar(128) NOT NULL
						,JobStatus int NOT NULL
						,StepsStatus int NOT NULL
						,Date date NOT NULL
						,Hour tinyint NOT NULL
						,Cnt smallint NOT NULL
						,SumDurationSeconds int NOT NULL
						,MinDurationSeconds int NOT NULL
						,MaxDurationSeconds int NOT NULL
						,CONSTRAINT PK_fhsmAgentJobsPerformance PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformance')) AND (i.name = 'NC_fhsmAgentJobsPerformance_Date_Name'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformance_Date_Name] to table dbo.fhsmAgentJobsPerformance', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformance_Date_Name ON dbo.fhsmAgentJobsPerformance(Date, Name)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformance')) AND (i.name = 'NC_fhsmAgentJobsPerformance_Name_Date'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformance_Name_Date] to table dbo.fhsmAgentJobsPerformance', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformance_Name_Date ON dbo.fhsmAgentJobsPerformance(Name, Date)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmAgentJobsPerformance
			--
			BEGIN
				SET @objectName = 'dbo.fhsmAgentJobsPerformance';
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
		-- Create table dbo.fhsmAgentJobsPerformanceDelta and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmAgentJobsPerformanceDelta', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmAgentJobsPerformanceDelta', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmAgentJobsPerformanceDelta(
						Id int identity(1,1) NOT NULL
						,Name nvarchar(128) NOT NULL
						,JobStatus int NOT NULL
						,StepsStatus int NOT NULL
						,StartDateTime datetime NOT NULL
						,DurationSeconds int NOT NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmAgentJobsPerformanceDelta PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceDelta')) AND (i.name = 'NC_fhsmAgentJobsPerformanceDelta_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformanceDelta_TimestampUTC] to table dbo.fhsmAgentJobsPerformanceDelta', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformanceDelta_TimestampUTC ON dbo.fhsmAgentJobsPerformanceDelta(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceDelta')) AND (i.name = 'NC_fhsmAgentJobsPerformanceDelta_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformanceDelta_Timestamp] to table dbo.fhsmAgentJobsPerformanceDelta', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformanceDelta_Timestamp ON dbo.fhsmAgentJobsPerformanceDelta(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceDelta')) AND (i.name = 'NC_fhsmAgentJobsPerformanceDelta_Name_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformanceDelta_Name_TimestampUTC] to table dbo.fhsmAgentJobsPerformanceDelta', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformanceDelta_Name_TimestampUTC ON dbo.fhsmAgentJobsPerformanceDelta(Name, TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmAgentJobsPerformanceDelta
			--
			BEGIN
				SET @objectName = 'dbo.fhsmAgentJobsPerformanceDelta';
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
		-- Create table dbo.fhsmAgentJobsPerformanceDeltaTemp and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmAgentJobsPerformanceDeltaTemp', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmAgentJobsPerformanceDeltaTemp', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmAgentJobsPerformanceDeltaTemp(
						Id int identity(1,1) NOT NULL
						,Name nvarchar(128) NOT NULL
						,JobStatus int NOT NULL
						,StartDateTime datetime NOT NULL
						,DurationSeconds int NOT NULL
						,JobId uniqueidentifier NOT NULL
						,InstanceId int NOT NULL
						,PrevInstanceId int NULL
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceDeltaTemp')) AND (i.name = 'CL_fhsmAgentJobsPerformanceDeltaTemp'))
			BEGIN
				RAISERROR('Adding index [CL_fhsmAgentJobsPerformanceDeltaTemp] to table dbo.fhsmAgentJobsPerformanceDeltaTemp', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE CLUSTERED INDEX CL_fhsmAgentJobsPerformanceDeltaTemp ON dbo.fhsmAgentJobsPerformanceDeltaTemp(JobId)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceDeltaTemp')) AND (i.name = 'NC_fhsmAgentJobsPerformanceDeltaTemp_Id'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformanceDeltaTemp_Id] to table dbo.fhsmAgentJobsPerformanceDeltaTemp', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE UNIQUE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformanceDeltaTemp_Id ON dbo.fhsmAgentJobsPerformanceDeltaTemp(Id)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmAgentJobsPerformanceDeltaTemp
			--
			BEGIN
				SET @objectName = 'dbo.fhsmAgentJobsPerformanceDeltaTemp';
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
		-- Create table dbo.fhsmAgentJobsPerformanceLatest and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmAgentJobsPerformanceLatest', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmAgentJobsPerformanceLatest', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmAgentJobsPerformanceLatest(
						Id bigint identity(1,1) NOT NULL
						,Name nvarchar(128) NOT NULL
						,JobStatus int NOT NULL
						,StepsStatus int NOT NULL
						,StartDateTime datetime NOT NULL
						,DurationSeconds int NOT NULL
						,Aggregated bit NOT NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmAgentJobsPerformanceLatest PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceLatest')) AND (i.name = 'NC_fhsmAgentJobsPerformanceLatest_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformanceLatest_TimestampUTC] to table dbo.fhsmAgentJobsPerformanceLatest', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformanceLatest_TimestampUTC ON dbo.fhsmAgentJobsPerformanceLatest(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceLatest')) AND (i.name = 'NC_fhsmAgentJobsPerformanceLatest_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformanceLatest_Timestamp] to table dbo.fhsmAgentJobsPerformanceLatest', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformanceLatest_Timestamp ON dbo.fhsmAgentJobsPerformanceLatest(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceLatest')) AND (i.name = 'NC_fhsmAgentJobsPerformanceLatest_Name_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformanceLatest_Name_TimestampUTC] to table dbo.fhsmAgentJobsPerformanceLatest', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformanceLatest_Name_TimestampUTC ON dbo.fhsmAgentJobsPerformanceLatest(Name, TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmAgentJobsPerformanceLatest
			--
			BEGIN
				SET @objectName = 'dbo.fhsmAgentJobsPerformanceLatest';
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
		-- Create table dbo.fhsmAgentJobsPerformanceErrorDelta and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmAgentJobsPerformanceErrorDelta', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmAgentJobsPerformanceErrorDelta', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmAgentJobsPerformanceErrorDelta(
						Id int identity(1,1) NOT NULL
						,Name nvarchar(128) NOT NULL
						,StepId int NOT NULL
						,StepName nvarchar(128) NOT NULL
						,RunStatus int NOT NULL
						,StartDateTime datetime NOT NULL
						,DurationSeconds int NOT NULL
						,JobDurationSeconds int NULL
						,MessageId int NULL
						,Severity int NULL
						,Message nvarchar(4000) NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmAgentJobsPerformanceErrorDelta PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceErrorDelta')) AND (i.name = 'NC_fhsmAgentJobsPerformanceErrorDelta_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformanceErrorDelta_TimestampUTC] to table dbo.fhsmAgentJobsPerformanceErrorDelta', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformanceErrorDelta_TimestampUTC ON dbo.fhsmAgentJobsPerformanceErrorDelta(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceErrorDelta')) AND (i.name = 'NC_fhsmAgentJobsPerformanceErrorDelta_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformanceErrorDelta_Timestamp] to table dbo.fhsmAgentJobsPerformanceErrorDelta', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformanceErrorDelta_Timestamp ON dbo.fhsmAgentJobsPerformanceErrorDelta(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceErrorDelta')) AND (i.name = 'NC_fhsmAgentJobsPerformanceErrorDelta_Name_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformanceErrorDelta_Name_TimestampUTC] to table dbo.fhsmAgentJobsPerformanceErrorDelta', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformanceErrorDelta_Name_TimestampUTC ON dbo.fhsmAgentJobsPerformanceErrorDelta(Name, TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmAgentJobsPerformanceErrorDelta
			--
			BEGIN
				SET @objectName = 'dbo.fhsmAgentJobsPerformanceErrorDelta';
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
		-- Create table dbo.fhsmAgentJobsPerformanceLatestError and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmAgentJobsPerformanceLatestError', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmAgentJobsPerformanceLatestError', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmAgentJobsPerformanceLatestError(
						Id int identity(1,1) NOT NULL
						,Name nvarchar(128) NOT NULL
						,StepId int NOT NULL
						,StepName nvarchar(128) NOT NULL
						,RunStatus int NOT NULL
						,StartDateTime datetime NOT NULL
						,DurationSeconds int NOT NULL
						,JobDurationSeconds int NULL
						,MessageId int NULL
						,Severity int NULL
						,Message nvarchar(4000) NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmAgentJobsPerformanceLatestError PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceLatestError')) AND (i.name = 'NC_fhsmAgentJobsPerformanceLatestError_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformanceLatestError_TimestampUTC] to table dbo.fhsmAgentJobsPerformanceLatestError', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformanceLatestError_TimestampUTC ON dbo.fhsmAgentJobsPerformanceLatestError(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceLatestError')) AND (i.name = 'NC_fhsmAgentJobsPerformanceLatestError_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformanceLatestError_Timestamp] to table dbo.fhsmAgentJobsPerformanceLatestError', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformanceLatestError_Timestamp ON dbo.fhsmAgentJobsPerformanceLatestError(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobsPerformanceLatestError')) AND (i.name = 'NC_fhsmAgentJobsPerformanceLatestError_Name_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAgentJobsPerformanceLatestError_Name_TimestampUTC] to table dbo.fhsmAgentJobsPerformanceLatestError', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAgentJobsPerformanceLatestError_Name_TimestampUTC ON dbo.fhsmAgentJobsPerformanceLatestError(Name, TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmAgentJobsPerformanceLatestError
			--
			BEGIN
				SET @objectName = 'dbo.fhsmAgentJobsPerformanceLatestError';
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
		-- Add indexes to msdb.dbo.sysjobhistory if they if they not already exists
		--
		BEGIN
			--
			-- Test if index on msdb.dbo.sysjobhistory with index columns [job_id] and [step_id] exists
			--
			IF NOT EXISTS (
				SELECT *
				FROM msdb.sys.indexes AS i
				WHERE (i.object_id = OBJECT_ID('msdb.dbo.sysjobhistory'))
					AND EXISTS (	-- Test for [job_id] AS index column #1
						SELECT *
						FROM msdb.sys.index_columns AS ic
						INNER JOIN msdb.sys.columns AS c ON (c.object_id = ic.object_id) AND (c.column_id = ic.column_id)
						WHERE (1 = 1)
							AND (ic.object_id = i.object_id)
							AND (ic.index_id = i.index_id)
							AND (ic.index_column_id = 1)
							AND (ic.is_included_column = 0)
							AND (c.name = 'job_id')
					)
					AND EXISTS (	-- Test for [step_id] AS index column #2
						SELECT *
						FROM msdb.sys.index_columns AS ic
						INNER JOIN msdb.sys.columns AS c ON (c.object_id = ic.object_id) AND (c.column_id = ic.column_id)
						WHERE (1 = 1)
							AND (ic.object_id = i.object_id)
							AND (ic.index_id = i.index_id)
							AND (ic.index_column_id = 2)
							AND (ic.is_included_column = 0)
							AND (c.name = 'step_id')
					)
			)
			BEGIN
				RAISERROR('Adding index [NC_sysjobhistory_job_id_step_id] to table msdb.dbo.sysjobhistory', 0, 1) WITH NOWAIT;

				SET @stmt = '
					USE [msdb];
					CREATE NONCLUSTERED INDEX NC_sysjobhistory_job_id_step_id ON dbo.sysjobhistory(job_id, step_id)
					INCLUDE(run_status, run_date, run_time, run_duration)
					' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Test if index on msdb.dbo.sysjobhistory with index columns [job_id], [instance_id] and [run_status] exists
			--
			IF NOT EXISTS (
				SELECT *
				FROM msdb.sys.indexes AS i
				WHERE (i.object_id = OBJECT_ID('msdb.dbo.sysjobhistory'))
					AND EXISTS (	-- Test for [job_id] AS index column #1
						SELECT *
						FROM msdb.sys.index_columns AS ic
						INNER JOIN msdb.sys.columns AS c ON (c.object_id = ic.object_id) AND (c.column_id = ic.column_id)
						WHERE (1 = 1)
							AND (ic.object_id = i.object_id)
							AND (ic.index_id = i.index_id)
							AND (ic.index_column_id = 1)
							AND (ic.is_included_column = 0)
							AND (c.name = 'job_id')
					)
					AND EXISTS (	-- Test for [instance_id] AS index column #2
						SELECT *
						FROM msdb.sys.index_columns AS ic
						INNER JOIN msdb.sys.columns AS c ON (c.object_id = ic.object_id) AND (c.column_id = ic.column_id)
						WHERE (1 = 1)
							AND (ic.object_id = i.object_id)
							AND (ic.index_id = i.index_id)
							AND (ic.index_column_id = 2)
							AND (ic.is_included_column = 0)
							AND (c.name = 'instance_id')
					)
					AND EXISTS (	-- Test for [run_status] AS index column #3
						SELECT *
						FROM msdb.sys.index_columns AS ic
						INNER JOIN msdb.sys.columns AS c ON (c.object_id = ic.object_id) AND (c.column_id = ic.column_id)
						WHERE (1 = 1)
							AND (ic.object_id = i.object_id)
							AND (ic.index_id = i.index_id)
							AND (ic.index_column_id = 3)
							AND (ic.is_included_column = 0)
							AND (c.name = 'run_status')
					)
			)
			BEGIN
				RAISERROR('Adding index [NC_sysjobhistory_job_id_instance_id_run_status] to table msdb.dbo.sysjobhistory', 0, 1) WITH NOWAIT;

				SET @stmt = '
					USE [msdb];
					CREATE NONCLUSTERED INDEX NC_sysjobhistory_job_id_instance_id_run_status ON dbo.sysjobhistory(job_id, instance_id, run_status)
					' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
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
		-- Create fact view @pbiSchema.[Agent jobs performance]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs performance') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs performance') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs performance') + '
				AS
				SELECT
					ajp.Date
					,ajp.Cnt
					,ajp.SumDurationSeconds
					,ajp.MinDurationSeconds
					,ajp.MaxDurationSeconds
					,(ajp.Hour * 60 * 60) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ajp.Name, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS AgentJobKey
					,CAST(
						CASE
							WHEN (ajp.JobStatus = 1) AND (ajp.StepsStatus = 0)	THEN 1	-- Ended with errors
							WHEN (ajp.JobStatus = 1)							THEN 0	-- Succeeded
							WHEN (ajp.JobStatus = 0)							THEN 2	-- Failed
							WHEN (ajp.JobStatus = 2)							THEN 3	-- Retry
							WHEN (ajp.JobStatus = 3)							THEN 4	-- Canceled
							WHEN (ajp.JobStatus = 4)							THEN 5	-- In progress
							WHEN (ajp.JobStatus = -1)							THEN 99	-- Missing data
						END
					AS bigint) AS AgentJobStatsusKey
				FROM dbo.fhsmAgentJobsPerformance AS ajp;
			';
			EXEC(@stmt);
		END;

		--
		-- Create fact view @pbiSchema.[Agent jobs performance errors]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs performance errors') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs performance errors') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs performance errors') + '
				AS
				SELECT
					ajpe.StepId
					,ajpe.StepName
					,ajpe.DurationSeconds
					,ajpe.JobDurationSeconds
					,ajpe.MessageId
					,ajpe.Severity
					,ajpe.Message
					,ajpe.StartDateTime
					,CAST(ajpe.StartDateTime AS date) AS Date
					,(DATEPART(HOUR, ajpe.StartDateTime) * 60 * 60) + (DATEPART(MINUTE, ajpe.StartDateTime) * 60) + (DATEPART(SECOND, ajpe.StartDateTime)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ajpe.Name, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS AgentJobKey
					,CAST(
						CASE
							WHEN (ajpe.RunStatus = 0)	THEN 2	-- Failed
							WHEN (ajpe.RunStatus = 2)	THEN 3	-- Retry
							WHEN (ajpe.RunStatus = 3)	THEN 4	-- Canceled
							WHEN (ajpe.RunStatus = 4)	THEN 5	-- In progress
						END
					AS bigint) AS AgentJobStatsusKey
				FROM dbo.fhsmAgentJobsPerformanceLatestError AS ajpe
			';
			EXEC(@stmt);
		END;

		--
		-- Create fact view @pbiSchema.[Agent job status]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent job status') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent job status') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent job status') + '
				AS
				SELECT
					s.Status
					,s.SortOrder
					,CAST(s.StatusVal AS bigint) AS AgentJobStatsusKey
				FROM (
					VALUES
						( 0, ''Succeeded'',         0),
						( 1, ''Ended with errors'', 1),
						( 2, ''Failed'',            2),
						( 3, ''Retry'',             3),
						( 4, ''Canceled'',          4),
						( 5, ''In progress'',       5),
						(99, ''Missing data'',      6)
				) AS s(StatusVal, Status, SortOrder);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Agent job status]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent job status');
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
	-- Create stored procedures
	--
	BEGIN
		--
		-- Create stored procedure dbo.fhsmSPAgentJobsPerformance
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPAgentJobsPerformance'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPAgentJobsPerformance AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPAgentJobsPerformance (
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @jobName nvarchar(128);
					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameter nvarchar(max);
					DECLARE @parameterStmt nvarchar(max);
					DECLARE @productEndPos int;
					DECLARE @productStartPos int;
					DECLARE @productVersion nvarchar(128);
					DECLARE @productVersion1 int;
					DECLARE @productVersion2 int;
					DECLARE @productVersion3 int;
					DECLARE @startDateTime datetime;
					DECLARE @startDateTimeTxt nvarchar(32);
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);
					DECLARE @whereStmt nvarchar(max);
					DECLARE @whereStmt1 nvarchar(max);
					DECLARE @whereStmt2 nvarchar(max);
					DECLARE @whereStmtError nvarchar(max);
					DECLARE @whereStmtError1 nvarchar(max);
					DECLARE @whereStmtError2 nvarchar(max);

					--
					-- Initialize variables
					--
					BEGIN
						SET @thisTask = OBJECT_NAME(@@PROCID);
						SET @version = ''' + @version + ''';

						SET @productVersion = CAST(SERVERPROPERTY(''ProductVersion'') AS nvarchar);
						SET @productStartPos = 1;
						SET @productEndPos = CHARINDEX(''.'', @productVersion, @productStartPos);
						SET @productVersion1 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
						SET @productStartPos = @productEndPos + 1;
						SET @productEndPos = CHARINDEX(''.'', @productVersion, @productStartPos);
						SET @productVersion2 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
						SET @productStartPos = @productEndPos + 1;
						SET @productEndPos = CHARINDEX(''.'', @productVersion, @productStartPos);
						SET @productVersion3 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
					END;

					--
					-- Get the parameter for the command
					--
					BEGIN
						SET @parameter = dbo.fhsmFNGetTaskParameter(@thisTask, @name);

						SET @parameterStmt = '''';

						IF (@parameter IS NOT NULL)
						BEGIN
							SET @parameterStmt = ''AND '' + @parameter;
						END;
					END;
			';
			SET @stmt += '
					--
					-- Create where condition to load latest and newest per job
					--
					BEGIN
						DECLARE jCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
						SELECT
							jpl.Name AS JobName,
							MAX(jpl.StartDateTime) AS StartDateTime
						FROM dbo.fhsmAgentJobsPerformanceLatest AS jpl
						GROUP BY jpl.Name
						ORDER BY jpl.Name;

						OPEN jCur;

						SET @whereStmt1 = '''';
						SET @whereStmt2 = '''';

						WHILE (1 = 1)
						BEGIN
							FETCH NEXT FROM jCur
							INTO @jobName, @startDateTime;

							IF (@@FETCH_STATUS <> 0)
							BEGIN
								BREAK;
							END;

							SET @startDateTimeTxt = CONVERT(nvarchar, @startDateTime, 126);

							IF (@whereStmt1 <> '''')
							BEGIN
								SET @whereStmt1 += ''OR '';
							END;
							SET @whereStmt1 += ''((sj.name = '''''' + @jobName + '''''') AND (ajt.StartDateTime >= '''''' + @startDateTimeTxt + ''''''))'' + CHAR(13);;

							IF (@whereStmt2 <> '''')
							BEGIN
								SET @whereStmt2 += '', '';
							END;
							SET @whereStmt2 += '''''''' + @jobName + '''''''';
						END;

						CLOSE jCur;
						DEALLOCATE jCur;

						IF (@whereStmt1 = '''')
						BEGIN
							SET @whereStmt = '''';
						END
						ELSE BEGIN
							SET @whereStmt = ''
								AND (
									('' + @whereStmt1 + '')
									OR (sj.name NOT IN ('' + @whereStmt2 + ''))
								);
							'';
						END;
					END;
			';
			SET @stmt += '
					--
					-- Create where condition to load latest and newest errors per job
					--
					BEGIN
						DECLARE jCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
						SELECT
							jple.Name AS JobName,
							MAX(jple.StartDateTime) AS StartDateTime
						FROM dbo.fhsmAgentJobsPerformanceLatestError AS jple
						GROUP BY jple.Name
						ORDER BY jple.Name;

						OPEN jCur;

						SET @whereStmtError1 = '''';
						SET @whereStmtError2 = '''';

						WHILE (1 = 1)
						BEGIN
							FETCH NEXT FROM jCur
							INTO @jobName, @startDateTime;

							IF (@@FETCH_STATUS <> 0)
							BEGIN
								BREAK;
							END;

							SET @startDateTimeTxt = CONVERT(nvarchar, @startDateTime, 126);

							IF (@whereStmtError1 <> '''')
							BEGIN
								SET @whereStmtError1 += ''OR '';
							END;
							SET @whereStmtError1 += ''((sj.name = '''''' + @jobName + '''''') AND (ajt.StartDateTime > '''''' + @startDateTimeTxt + ''''''))'' + CHAR(13);;

							IF (@whereStmtError2 <> '''')
							BEGIN
								SET @whereStmtError2 += '', '';
							END;
							SET @whereStmtError2 += '''''''' + @jobName + '''''''';
						END;

						CLOSE jCur;
						DEALLOCATE jCur;

						IF (@whereStmtError1 = '''')
						BEGIN
							SET @whereStmtError = '''';
						END
						ELSE BEGIN
							SET @whereStmtError = ''
								AND (
									('' + @whereStmtError1 + '')
									OR (sj.name NOT IN ('' + @whereStmtError2 + ''))
								);
							'';
						END;
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

						--
						-- Collect data into temp table
						--
						SET @stmt = ''
							TRUNCATE TABLE dbo.fhsmAgentJobsPerformanceDeltaTemp;
						'';
						IF (@productVersion1 <= 10)
						BEGIN
							-- SQL Versions SQL2008R2 or lower

							SET @stmt += ''
							WITH
							jrn AS (
								SELECT
									sj.name
									,sjh.job_id
									,sjh.instance_id
									,sjh.run_date
									,sjh.run_time
									,sjh.run_duration
									,sjh.run_status
									,ROW_NUMBER() OVER(PARTITION BY sjh.job_id ORDER BY sjh.instance_id) AS JobRunNumber
								FROM msdb.dbo.sysjobs AS sj
								INNER JOIN msdb.dbo.sysjobhistory AS sjh ON (sjh.job_id =  sj.job_id)
								WHERE (1 = 1)
									AND (sjh.step_id = 0)
							)
							'';
						END;
			';
			SET @stmt += '
						SET @stmt += ''
							INSERT INTO dbo.fhsmAgentJobsPerformanceDeltaTemp(Name, JobStatus, StartDateTime, DurationSeconds, JobId, InstanceId, PrevInstanceId)
							SELECT
								sj.name AS Name
								,sj.run_status AS JobStatus
								,ajt.StartDateTime
								,CASE WHEN (ajt.DurationSeconds = 0) THEN 1 ELSE ajt.DurationSeconds END AS DurationSeconds
								,sj.job_id AS JobId
								,sj.instance_id AS InstanceId
								,sj.PrevInstanceId AS PrevInstanceId
							FROM (
						'';
						IF (@productVersion1 <= 10)
						BEGIN
							-- SQL Versions SQL2008R2 or lower

							SET @stmt += ''
								SELECT
									jrn.name
									,jrn.job_id
									,jrn.instance_id
									,jrn.run_date
									,jrn.run_time
									,jrn.run_duration
									,jrn.run_status
									,COALESCE(prevJRN.instance_id, 0) AS PrevInstanceId
								FROM jrn
								LEFT OUTER JOIN jrn AS prevJRN ON
									(prevJRN.job_id = jrn.job_id)
									AND (prevJRN.JobRunNumber = jrn.JobRunNumber - 1)
							'';
						END
						ELSE BEGIN
							-- SQL Versions SQL2012 or higher

							SET @stmt += ''
								SELECT
									jrn.name
									,jrn.job_id
									,jrn.instance_id
									,jrn.run_date
									,jrn.run_time
									,jrn.run_duration
									,jrn.run_status
									,LAG(jrn.instance_id, 1, 0) OVER(PARTITION BY jrn.job_id ORDER BY jrn.JobRunNumber) AS PrevInstanceId
								FROM (
									SELECT
										sj.name
										,sjh.job_id
										,sjh.instance_id
										,sjh.run_date
										,sjh.run_time
										,sjh.run_duration
										,sjh.run_status
										,ROW_NUMBER() OVER(PARTITION BY sjh.job_id ORDER BY sjh.instance_id) AS JobRunNumber
									FROM msdb.dbo.sysjobs AS sj
									INNER JOIN msdb.dbo.sysjobhistory AS sjh ON (sjh.job_id =  sj.job_id)
									WHERE (1 = 1)
										AND (sjh.step_id = 0)
								) AS jrn
							'';
						END;
			';
			SET @stmt += '
						SET @stmt += ''
							) AS sj
							CROSS APPLY dbo.fhsmFNAgentJobTime(sj.run_date, sj.run_time, sj.run_duration) AS ajt
							WHERE (1 = 1)
								'' + @whereStmt + '';
						'';
						EXEC sp_executesql
							@stmt
							,N''@now datetime, @nowUTC datetime''
							,@now = @now
							,@nowUTC = @nowUTC;
			';
			SET @stmt += '
						--
						-- Move temp data into data
						--
						SET @stmt = ''
							TRUNCATE TABLE dbo.fhsmAgentJobsPerformanceDelta;
						'';

						SET @stmt += ''
							INSERT INTO dbo.fhsmAgentJobsPerformanceDelta(Name, JobStatus, StepsStatus, StartDateTime, DurationSeconds, TimestampUTC, Timestamp)
							SELECT
								sj.Name
								,sj.JobStatus
								,COALESCE(jobStepError.MinRunStatus, 1) AS StepsStatus
								,sj.StartDateTime
								,sj.DurationSeconds
								,@nowUTC
								,@now
							FROM dbo.fhsmAgentJobsPerformanceDeltaTemp AS sj
							OUTER APPLY (
								SELECT MIN(sjh.run_status) AS MinRunStatus
								FROM msdb.dbo.sysjobhistory AS sjh
								WHERE
									(sjh.run_status <> 1)
									AND (sjh.job_id = sj.JobId)
									AND (sjh.instance_id <= sj.InstanceId)
									AND (sjh.instance_id > sj.PrevInstanceId)
							) AS jobStepError;
						'';
						EXEC sp_executesql
							@stmt
							,N''@now datetime, @nowUTC datetime''
							,@now = @now
							,@nowUTC = @nowUTC;
			';
			SET @stmt += '
						SET @stmt = ''
							TRUNCATE TABLE dbo.fhsmAgentJobsPerformanceErrorDelta;

							INSERT INTO dbo.fhsmAgentJobsPerformanceErrorDelta(Name, StepId, StepName, RunStatus, StartDateTime, DurationSeconds, JobDurationSeconds, MessageId, Severity, Message, TimestampUTC, Timestamp)
							SELECT
								sj.name AS Name
								,sjh.step_id AS StepId
								,sjh.step_name AS StepName
								,sjh.[run_status] AS RunStatus
								,ajt.StartDateTime
								,ajt.DurationSeconds
								,job.run_duration AS JobDurationSeconds
								,sjh.sql_message_id AS MessageId
								,sjh.sql_severity AS Severity
								,sjh.message AS Message
								,@nowUTC
								,@now
							FROM msdb.dbo.sysjobs AS sj
							INNER JOIN msdb.dbo.sysjobhistory AS sjh ON (sj.job_id = sjh.job_id)
							CROSS APPLY dbo.fhsmFNAgentJobTime(sjh.run_date, sjh.run_time, sjh.run_duration) AS ajt
							CROSS APPLY (
								SELECT TOP 1 job.run_duration
								FROM msdb.dbo.sysjobhistory AS job
								CROSS APPLY dbo.fhsmFNAgentJobTime(job.run_date, job.run_time, job.run_duration) AS ajtParent
								WHERE (job.job_id = sj.job_id) AND (job.step_id = 0) AND (ajtParent.StartDateTime <= ajt.StartDateTime)
								ORDER BY ajtParent.StartDateTime DESC
							) AS job
							WHERE (1 = 1)
								AND (sjh.run_status <> 1)
								AND (sjh.step_id <> 0)
								'' + @parameterStmt + ''
								'' + @whereStmtError + '';
						'';
						EXEC sp_executesql
							@stmt
							,N''@now datetime, @nowUTC datetime''
							,@now = @now
							,@nowUTC = @nowUTC;
					END;
			';
			SET @stmt += '
					--
					-- Check if the newest record (Rnk = 1) in dbo.fhsmAgentJobsPerformanceLatest exists in dbo.fhsmAgentJobsPerformanceDelta
					-- If not we are running to slow, or the SQL Server agent must have its Histiry settings changed
					-- We will only record one per hour bucket
					--
					BEGIN
						INSERT INTO dbo.fhsmAgentJobsPerformanceLatest(Name, JobStatus, StepsStatus, StartDateTime, DurationSeconds, Aggregated, TimestampUTC, Timestamp)
						SELECT a.Name, -1 AS JobStatus, -1 AS StepsStatus, a.StartDateTime, 0 AS DurationSeconds, 0 AS Aggregated, @nowUTC, @now
						FROM (
							SELECT
								jpl.Name,
								jpl.StartDateTime,
								ROW_NUMBER() OVER(PARTITION BY jpl.Name ORDER BY jpl.StartDateTime DESC) AS Rnk
							FROM dbo.fhsmAgentJobsPerformanceLatest AS jpl
						) AS a
						WHERE (a.Rnk = 1)
							AND NOT EXISTS (
								SELECT *
								FROM dbo.fhsmAgentJobsPerformanceDelta AS jpd
								WHERE (jpd.Name = a.Name) AND (jpd.StartDateTime = a.StartDateTime)
							)
							AND NOT EXISTS (
								SELECT *
								FROM dbo.fhsmAgentJobsPerformance AS jp
								WHERE (jp.JobStatus = -1) AND (jp.StepsStatus = -1) AND (jp.Name = a.Name) AND (jp.Date = CAST(a.StartDateTime AS date)) AND (jp.Hour = DATEPART(HOUR, a.StartDateTime))
							);
					END;
			';
			SET @stmt += '
					--
					-- Load newest records in the dbo.fhsmAgentJobsPerformanceLatest table and with Aggregated set to 0
					--
					BEGIN
						INSERT INTO dbo.fhsmAgentJobsPerformanceLatest(Name, JobStatus, StepsStatus, StartDateTime, DurationSeconds, Aggregated, TimestampUTC, Timestamp)
						SELECT Name, JobStatus, StepsStatus, StartDateTime, DurationSeconds, 0 AS Aggregated, TimestampUTC, Timestamp
						FROM dbo.fhsmAgentJobsPerformanceDelta AS jpd
						WHERE NOT EXISTS (
							SELECT *
							FROM dbo.fhsmAgentJobsPerformanceLatest AS jpl
							WHERE (jpl.Name = jpd.Name) AND (jpl.StartDateTime = jpd.StartDateTime)
						);
					END;
			';
			SET @stmt += '
					--
					-- Aggregate data into buckets
					--
					BEGIN
						MERGE dbo.fhsmAgentJobsPerformance AS tgt
						USING (
							SELECT
								jpl.Name,
								jpl.JobStatus,
								jpl.StepsStatus,
								CAST(jpl.StartDateTime AS date) AS Date,
								DATEPART(HOUR, jpl.StartDateTime) AS Hour,
								COUNT(*) AS Cnt,
								SUM(jpl.DurationSeconds) AS SumDurationSeconds,
								MIN(jpl.DurationSeconds) AS MinDurationSeconds,
								MAX(jpl.DurationSeconds) AS MaxDurationSeconds
							FROM dbo.fhsmAgentJobsPerformanceLatest AS jpl
							WHERE (jpl.Aggregated = 0)
							GROUP BY
								jpl.Name,
								jpl.JobStatus,
								jpl.StepsStatus,
								CAST(jpl.StartDateTime AS date),
								DATEPART(HOUR, jpl.StartDateTime)
						) AS src
						ON (src.Name = tgt.Name) AND (src.JobStatus = tgt.JobStatus) AND (src.StepsStatus = tgt.StepsStatus) AND (src.Date = tgt.Date) AND (src.Hour = tgt.Hour)
						WHEN MATCHED
							THEN
							UPDATE
							SET
								tgt.Cnt += src.Cnt,
								tgt.SumDurationSeconds += src.SumDurationSeconds,
								tgt.MinDurationSeconds = CASE WHEN (src.MinDurationSeconds < tgt.MinDurationSeconds) THEN src.MinDurationSeconds ELSE tgt.MinDurationSeconds END,
								tgt.MaxDurationSeconds = CASE WHEN (src.MaxDurationSeconds < tgt.MaxDurationSeconds) THEN src.MaxDurationSeconds ELSE tgt.MaxDurationSeconds END
						WHEN NOT MATCHED
							THEN
							INSERT(Name, JobStatus, StepsStatus, Date, Hour, Cnt, SumDurationSeconds, MinDurationSeconds, MaxDurationSeconds)
							VALUES(src.Name, src.JobStatus, src.StepsStatus, src.Date, src.Hour, src.Cnt, src.SumDurationSeconds, src.MinDurationSeconds, src.MaxDurationSeconds);
					END;
			';
			SET @stmt += '
					--
					-- Mark records as aggregated
					--
					BEGIN
						UPDATE jpl
						SET jpl.Aggregated = 1
						FROM dbo.fhsmAgentJobsPerformanceLatest AS jpl
						WHERE (jpl.Aggregated = 0);
					END;
			';
			SET @stmt += '
					--
					-- Delete older records (Rnk > 1) that are aggregated
					--
					BEGIN
						DELETE a
						FROM (
							SELECT
								ROW_NUMBER() OVER(PARTITION BY jpl.Name ORDER BY jpl.StartDateTime DESC) AS Rnk
							FROM dbo.fhsmAgentJobsPerformanceLatest AS jpl
							WHERE (jpl.Aggregated = 1)
						) AS a
						WHERE (a.Rnk > 1);
					END;
			';
			SET @stmt += '
					--
					-- Load newest error records in the dbo.fhsmAgentJobsPerformanceLatestError
					--
					BEGIN
						INSERT INTO dbo.fhsmAgentJobsPerformanceLatestError(Name, StepId, StepName, RunStatus, StartDateTime, DurationSeconds, JobDurationSeconds, MessageId, Severity, Message, TimestampUTC, Timestamp)
						SELECT Name, StepId, StepName, RunStatus, StartDateTime, DurationSeconds, JobDurationSeconds, MessageId, Severity, Message, TimestampUTC, Timestamp
						FROM dbo.fhsmAgentJobsPerformanceErrorDelta AS jped
						WHERE NOT EXISTS (
							SELECT *
							FROM dbo.fhsmAgentJobsPerformanceLatestError AS jple
							WHERE (jple.Name = jped.Name) AND (jple.StartDateTime = jped.StartDateTime)
						);
					END;
			';
			SET @stmt += '
					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPAgentJobs
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPAgentJobsPerformance';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create stored procedure dbo.fhsmSPControlAgentJobsPerformance
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPControlAgentJobsPerformance'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPControlAgentJobsPerformance AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPControlAgentJobsPerformance (
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
								-- Testing for NULL as a NULL parameter is allowed
								WHEN MATCHED AND ((tgt.Parameter <> src.Parameter) OR ((tgt.Parameter IS NULL) AND (src.Parameter IS NOT NULL)) OR ((tgt.Parameter IS NOT NULL) AND (src.Parameter IS NULL)))
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
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPControlAgentJobsPerformance
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPControlAgentJobsPerformance';
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
	-- Register retention
	--
	BEGIN
		WITH
		retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter) AS(
			SELECT
				1
				,'dbo.fhsmAgentJobsPerformance'
				,1
				,'Date'
				,1
				,365
				,NULL

			UNION ALL

			SELECT
				1
				,'dbo.fhsmAgentJobsPerformanceLatestError'
				,1
				,'TimestampUTC'
				,1
				,365
				,NULL
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
				@enableAgentJobsPerformance						AS Enabled
				,0												AS DeploymentStatus
				,'Agent jobs performance'						AS Name
				,PARSENAME('dbo.fhsmSPAgentJobsPerformance', 1)	AS Task
				,10 * 60										AS ExecutionDelaySec
				,CAST('1900-1-1T00:00:00.0000' AS datetime2(0))	AS FromTime
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))	AS ToTime
				,1, 1, 1, 1, 1, 1, 1							-- Monday..Sunday
				,NULL											AS Parameter
		)
		MERGE dbo.fhsmSchedules AS tgt
		USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
		WHEN MATCHED AND (tgt.Enabled = 0) AND (src.Enabled = 1)
			THEN UPDATE
				SET tgt.Enabled = src.Enabled
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
			SELECT
				'Agent job' AS DimensionName
				,'AgentJobKey' AS DimensionKey
				,'dbo.fhsmAgentJobsPerformance' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Date]' AS SrcDateColumn
				,'src.[Name]', NULL, NULL, NULL, NULL
				,'Job name', NULL, NULL, NULL, NULL
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
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmAgentJobsPerformance';
	END;
END;
