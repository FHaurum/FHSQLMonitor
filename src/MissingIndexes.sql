SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableMissingIndexes bit;

	SET @enableMissingIndexes = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing MissingIndexes', 0, 1) WITH NOWAIT;
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
		SET @version = '2.6';

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
	-- Variables used in view to control the statement output
	--
	BEGIN
		DECLARE @maxStatementLength int;

		SET @maxStatementLength = 1024;
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
		-- Create table dbo.fhsmMissingIndexes and indexes if they not already exists
		--
		IF OBJECT_ID('dbo.fhsmMissingIndexes', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmMissingIndexes', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmMissingIndexes(
					Id int identity(1,1) NOT NULL
					,DatabaseName nvarchar(128) NOT NULL
					,SchemaName nvarchar(128) NOT NULL
					,ObjectName nvarchar(128) NOT NULL
					,QueryHash binary(8) NULL
					,EqualityColumns nvarchar(4000) NULL
					,InequalityColumns nvarchar(4000) NULL
					,IncludedColumns nvarchar(4000) NULL
					,UniqueCompiles bigint NULL
					,UserSeeks bigint NOT NULL
					,UserScans bigint NOT NULL
					,LastUserSeek datetime NULL
					,LastUserScan datetime NULL
					,AvgTotalUserCost float NOT NULL
					,AvgUserImpact float NOT NULL
					,SystemSeeks bigint NOT NULL
					,SystemScans bigint NOT NULL
					,LastSystemSeek datetime NULL
					,LastSystemScan datetime NULL
					,AvgTotalSystemCost float NOT NULL
					,AvgSystemImpact float NOT NULL
					,LastSQLServiceRestart datetime NOT NULL
					,TimestampUTC datetime NOT NULL
					,Timestamp datetime NOT NULL
					,CONSTRAINT PK_fhsmMissingIndexes PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);
			';
			EXEC(@stmt);
		END;

		--
		-- Adding column QueryHash to table dbo.fhsmMissingIndexes if it not already exists
		--
		IF NOT EXISTS (SELECT * FROM sys.columns AS c WHERE (c.object_id = OBJECT_ID('dbo.fhsmMissingIndexes')) AND (c.name = 'QueryHash'))
		BEGIN
			RAISERROR('Adding column [QueryHash] to table dbo.fhsmMissingIndexes', 0, 1) WITH NOWAIT;

			SET @stmt = '
				ALTER TABLE dbo.fhsmMissingIndexes
					ADD QueryHash binary(8) NULL;
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmMissingIndexes')) AND (i.name = 'NC_fhsmMissingIndexes_TimestampUTC'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmMissingIndexes_TimestampUTC] to table dbo.fhsmMissingIndexes', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexes_TimestampUTC ON dbo.fhsmMissingIndexes(TimestampUTC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmMissingIndexes')) AND (i.name = 'NC_fhsmMissingIndexes_Timestamp'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmMissingIndexes_Timestamp] to table dbo.fhsmMissingIndexes', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexes_Timestamp ON dbo.fhsmMissingIndexes(Timestamp)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmMissingIndexes')) AND (i.name = 'NC_fhsmMissingIndexes_DatabaseName_SchemaName_ObjectName'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmMissingIndexes_DatabaseName_SchemaName_ObjectName] to table dbo.fhsmMissingIndexes', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexes_DatabaseName_SchemaName_ObjectName ON dbo.fhsmMissingIndexes(DatabaseName, SchemaName, ObjectName)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmMissingIndexes')) AND (i.name = 'NC_fhsmMissingIndexes_DatabaseName_QueryHash'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmMissingIndexes_DatabaseName_QueryHash] to table dbo.fhsmMissingIndexes', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexes_DatabaseName_QueryHash ON dbo.fhsmMissingIndexes(DatabaseName, QueryHash)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmMissingIndexes
		--
		BEGIN
			SET @objectName = 'dbo.fhsmMissingIndexes';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create table dbo.fhsmMissingIndexesTemp and indexes if they not already exists
		--
		IF OBJECT_ID('dbo.fhsmMissingIndexesTemp', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmMissingIndexesTemp', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmMissingIndexesTemp(
					Id int identity(1,1) NOT NULL
					,DatabaseName nvarchar(128) NOT NULL
					,SchemaName nvarchar(128) NOT NULL
					,ObjectName nvarchar(128) NOT NULL
					,QueryHash binary(8) NULL
					,Statement nvarchar(max) NULL
					,EqualityColumns nvarchar(4000) NULL
					,InequalityColumns nvarchar(4000) NULL
					,IncludedColumns nvarchar(4000) NULL
					,UniqueCompiles bigint NULL
					,UserSeeks bigint NOT NULL
					,UserScans bigint NOT NULL
					,LastUserSeek datetime NULL
					,LastUserScan datetime NULL
					,AvgTotalUserCost float NOT NULL
					,AvgUserImpact float NOT NULL
					,SystemSeeks bigint NOT NULL
					,SystemScans bigint NOT NULL
					,LastSystemSeek datetime NULL
					,LastSystemScan datetime NULL
					,AvgTotalSystemCost float NOT NULL
					,AvgSystemImpact float NOT NULL
					,LastSQLServiceRestart datetime NOT NULL
					,TimestampUTC datetime NOT NULL
					,Timestamp datetime NOT NULL
					,CONSTRAINT PK_fhsmMissingIndexesTemp PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmMissingIndexesTemp')) AND (i.name = 'NC_fhsmMissingIndexesTemp_TimestampUTC'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmMissingIndexesTemp_TimestampUTC] to table dbo.fhsmMissingIndexesTemp', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexesTemp_TimestampUTC ON dbo.fhsmMissingIndexesTemp(TimestampUTC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmMissingIndexesTemp')) AND (i.name = 'NC_fhsmMissingIndexesTemp_Timestamp'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmMissingIndexesTemp_Timestamp] to table dbo.fhsmMissingIndexesTemp', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexesTemp_Timestamp ON dbo.fhsmMissingIndexesTemp(Timestamp)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmMissingIndexesTemp')) AND (i.name = 'NC_fhsmMissingIndexesTemp_DatabaseName_SchemaName_ObjectName'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmMissingIndexesTemp_DatabaseName_SchemaName_ObjectName] to table dbo.fhsmMissingIndexesTemp', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexesTemp_DatabaseName_SchemaName_ObjectName ON dbo.fhsmMissingIndexesTemp(DatabaseName, SchemaName, ObjectName)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmMissingIndexesTemp
		--
		BEGIN
			SET @objectName = 'dbo.fhsmMissingIndexesTemp';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create table dbo.fhsmMissingIndexStatement and indexes if they not already exists
		--
		IF OBJECT_ID('dbo.fhsmMissingIndexStatement', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmMissingIndexStatement', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmMissingIndexStatement(
					Id int identity(1,1) NOT NULL
					,DatabaseName nvarchar(128) NOT NULL
					,QueryHash binary(8) NOT NULL
					,Statement nvarchar(max) NOT NULL
					,PrevStatement nvarchar(max) NULL
					,UpdateCount int NOT NULL
					,CONSTRAINT PK_fhsmMissingIndexStatement PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmMissingIndexStatement')) AND (i.name = 'NC_fhsmMissingIndexStatement_DatabaseName_QueryHash'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmMissingIndexStatement_DatabaseName_QueryHash] to table dbo.fhsmMissingIndexStatement', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexStatement_DatabaseName_QueryHash ON dbo.fhsmMissingIndexStatement(DatabaseName, QueryHash)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmMissingIndexStatement
		--
		BEGIN
			SET @objectName = 'dbo.fhsmMissingIndexStatement';
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
	-- Create functions
	--

	--
	-- Create views
	--
	BEGIN
		--
		-- Create fact view @pbiSchema.[Missing indexes]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Missing indexes') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Missing indexes') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Missing indexes') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				WITH missingIndexes AS (
					SELECT
						mi.DatabaseName
						,mi.SchemaName
						,mi.ObjectName
						,mi.QueryHash
						,mi.EqualityColumns
						,mi.InequalityColumns
						,mi.IncludedColumns
						,mi.UniqueCompiles
						,mi.UserSeeks
						,mi.LastUserSeek
						,mi.UserScans
						,mi.LastUserScan
						,mi.AvgTotalUserCost
						,mi.AvgUserImpact
						,mi.SystemSeeks
						,mi.LastSystemSeek
						,mi.SystemScans
						,mi.LastSystemScan
						,mi.AvgTotalSystemCost
						,mi.AvgSystemImpact
						,mi.LastSQLServiceRestart
						,CAST(mi.LastUserSeek AS date) AS LastUserSeekDate
						,mi.Timestamp
						,ROW_NUMBER() OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.QueryHash, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS Idx
					FROM dbo.fhsmMissingIndexes AS mi
					WHERE (
							(mi.DatabaseName <> ''<HeartBeat>'')
							OR (mi.SchemaName <> ''<HeartBeat>'')
							OR (mi.ObjectName <> ''<HeartBeat>'')
					)
				)
				';
			END;
			SET @stmt += '
				SELECT
					b.EqualityColumns
					,b.InequalityColumns
					,b.IncludedColumns
					,b.DeltaUniqueCompiles AS UniqueCompiles
					,b.DeltaUserSeeks AS UserSeeks
					,b.LastUserSeek
					,b.DeltaUserScans AS UserScans
					,b.LastUserScan
					,CASE WHEN (b.DeltaUserSeeks <> 0) OR (b.DeltaUserScans <> 0) THEN b.AvgTotalUserCost ELSE 0 END AS AvgTotalUserCost
					,CASE WHEN (b.DeltaUserSeeks <> 0) OR (b.DeltaUserScans <> 0) THEN b.AvgUserImpact ELSE 0 END AS AvgUserImpact
					,b.DeltaSystemSeeks AS SystemSeeks
					,b.LastSystemSeek
					,b.DeltaSystemScans AS SystemScans
					,b.LastSystemScan
					,CASE WHEN (b.DeltaSystemSeeks <> 0) OR (b.DeltaSystemScans <> 0) THEN b.AvgTotalSystemCost ELSE 0 END AS AvgTotalSystemCost
					,CASE WHEN (b.DeltaSystemSeeks <> 0) OR (b.DeltaSystemScans <> 0) THEN b.AvgSystemImpact ELSE 0 END AS AvgSystemImpact

					,CAST(b.LastUserSeek AS date) AS LastUserSeekDate
					,(DATEPART(HOUR, b.LastUserSeek) * 60 * 60) + (DATEPART(MINUTE, b.LastUserSeek) * 60) + (DATEPART(SECOND, b.LastUserSeek)) AS LastUserSeekTimeKey
					,CAST(b.Timestamp AS date) AS Date
					,(DATEPART(HOUR, b.Timestamp) * 60 * 60) + (DATEPART(MINUTE, b.Timestamp) * 60) + (DATEPART(SECOND, b.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(b.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(b.DatabaseName, b.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(b.DatabaseName, b.SchemaName, b.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
					,(SELECT k.[Key] FROM FHSQLMonitor.dbo.fhsmFNGenerateKey(b.DatabaseName, CONVERT(nvarchar(18), b.QueryHash, 1), DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS MissingIndexStatementKey
				FROM (
			';
			SET @stmt += '
					SELECT
						a.EqualityColumns
						,a.InequalityColumns
						,a.IncludedColumns
						,CASE
							WHEN (a.PreviousUniqueCompiles IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL												-- Ignore 1. data set - Yes we loose one data set but better than having visuals showing very high data
							WHEN (a.PreviousUniqueCompiles > a.UniqueCompiles) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.UniqueCompiles	-- Either has the counters had an overflow or the server har been restarted
							ELSE a.UniqueCompiles - a.PreviousUniqueCompiles																							-- Difference
						END AS DeltaUniqueCompiles
						,CASE
							WHEN (a.PreviousUserSeeks IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousUserSeeks > a.UserSeeks) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.UserSeeks
							ELSE a.UserSeeks - a.PreviousUserSeeks
						END AS DeltaUserSeeks
						,a.LastUserSeek
						,CASE
							WHEN (a.PreviousUserScans IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousUserScans > a.UserScans) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.UserScans
							ELSE a.UserScans - a.PreviousUserScans
						END AS DeltaUserScans
						,a.LastUserScan
						,a.AvgTotalUserCost
						,a.AvgUserImpact
						,CASE
							WHEN (a.PreviousSystemSeeks IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousSystemSeeks > a.SystemSeeks) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.SystemSeeks
							ELSE a.SystemSeeks - a.PreviousSystemSeeks
						END AS DeltaSystemSeeks
						,a.LastSystemSeek
						,CASE
							WHEN (a.PreviousSystemScans IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousSystemScans > a.SystemScans) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.SystemScans
							ELSE a.SystemScans - a.PreviousSystemScans
						END AS DeltaSystemScans
						,a.LastSystemScan
						,a.AvgTotalSystemCost
						,a.AvgSystemImpact

						,a.Timestamp
						,a.DatabaseName
						,a.SchemaName
						,a.ObjectName
						,a.QueryHash
					FROM (
			';
			SET @stmt += '

			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
						SELECT
							mi.EqualityColumns
							,mi.InequalityColumns
							,mi.IncludedColumns
							,mi.UniqueCompiles
							,prevMi.UniqueCompiles AS PreviousUniqueCompiles
							,mi.UserSeeks
							,prevMi.UserSeeks AS PreviousUserSeeks
							,mi.LastUserSeek
							,mi.UserScans
							,prevMi.UserScans AS PreviousUserScans
							,mi.LastUserScan
							,mi.AvgTotalUserCost
							,mi.AvgUserImpact
							,mi.SystemSeeks
							,prevMi.SystemSeeks AS PreviousSystemSeeks
							,mi.LastSystemSeek
							,mi.SystemScans
							,prevMi.SystemScans AS PreviousSystemScans
							,mi.LastSystemScan
							,mi.AvgTotalSystemCost
							,mi.AvgSystemImpact
							,mi.LastSQLServiceRestart
							,prevMi.LastSQLServiceRestart AS PreviousLastSQLServiceRestart

							,mi.Timestamp
							,mi.DatabaseName
							,mi.SchemaName
							,mi.ObjectName
							,mi.QueryHash
						FROM missingIndexes AS mi
						LEFT OUTER JOIN missingIndexes AS prevMi ON
							(prevMi.DatabaseName = mi.DatabaseName)
							AND (prevMi.SchemaName = mi.SchemaName)
							AND (prevMi.ObjectName = mi.ObjectName)
							AND ((prevMi.QueryHash = mi.QueryHash) OR ((prevMi.QueryHash IS NULL) AND (mi.QueryHash IS NULL)))
							AND ((prevMi.EqualityColumns = mi.EqualityColumns) OR ((prevMi.EqualityColumns IS NULL) AND (mi.EqualityColumns IS NULL)))
							AND ((prevMi.InequalityColumns = mi.InequalityColumns) OR ((prevMi.InequalityColumns IS NULL) AND (mi.InequalityColumns IS NULL)))
							AND ((prevMi.IncludedColumns = mi.IncludedColumns) OR ((prevMi.IncludedColumns IS NULL) AND (mi.IncludedColumns IS NULL)))
							AND (prevMi.Idx = mi.Idx - 1)
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
						SELECT
							mi.EqualityColumns
							,mi.InequalityColumns
							,mi.IncludedColumns
							,mi.UniqueCompiles
							,LAG(mi.UniqueCompiles) OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.QueryHash, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS PreviousUniqueCompiles
							,mi.UserSeeks
							,LAG(mi.UserSeeks) OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.QueryHash, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS PreviousUserSeeks
							,mi.LastUserSeek
							,mi.UserScans
							,LAG(mi.UserScans) OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.QueryHash, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS PreviousUserScans
							,mi.LastUserScan
							,mi.AvgTotalUserCost
							,mi.AvgUserImpact
							,mi.SystemSeeks
							,LAG(mi.SystemSeeks) OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.QueryHash, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS PreviousSystemSeeks
							,mi.LastSystemSeek
							,mi.SystemScans
							,LAG(mi.SystemScans) OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.QueryHash, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS PreviousSystemScans
							,mi.LastSystemScan
							,mi.AvgTotalSystemCost
							,mi.AvgSystemImpact
							,mi.LastSQLServiceRestart
							,LAG(mi.LastSQLServiceRestart) OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.QueryHash, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS PreviousLastSQLServiceRestart

							,mi.Timestamp
							,mi.DatabaseName
							,mi.SchemaName
							,mi.ObjectName
							,mi.QueryHash
						FROM dbo.fhsmMissingIndexes AS mi
						WHERE (
								(mi.DatabaseName <> ''<HeartBeat>'')
								OR (mi.SchemaName <> ''<HeartBeat>'')
								OR (mi.ObjectName <> ''<HeartBeat>'')
							)
				';
			END;
			SET @stmt += '
					) AS a
				) AS b
				WHERE
					(b.DeltaUniqueCompiles <> 0)
					OR (b.DeltaUserSeeks <> 0)
					OR (b.DeltaUserScans <> 0)
					OR (b.DeltaSystemSeeks <> 0)
					OR (b.DeltaSystemScans <> 0)
			
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Missing indexes]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Missing indexes');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Missing index statement]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Missing index statement') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Missing index statement') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Missing index statement') + '
				AS
			';
			SET @stmt += '
				SELECT
					CASE
						WHEN LEN(mis.Statement) > ' + CAST(@maxStatementLength AS nvarchar) + ' THEN LEFT(mis.Statement, ' + CAST(@maxStatementLength AS nvarchar) + ') + CHAR(10) + ''...Statement truncated''
						ELSE mis.Statement
					END AS Statement
					,(SELECT k.[Key] FROM FHSQLMonitor.dbo.fhsmFNGenerateKey(mis.DatabaseName, CONVERT(nvarchar(18), mis.QueryHash, 1), DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS MissingIndexStatementKey
				FROM dbo.fhsmMissingIndexStatement AS mis;
				';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Missing index statement]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Missing index statement');
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
		-- Create stored procedure dbo.fhsmSPMissingIndexes
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPMissingIndexes'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPMissingIndexes AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPMissingIndexes (
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameters nvarchar(max);
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);
					SET @version = ''' + @version + ''';

					--
					-- Get the parameters for the command
					--
					BEGIN
						SET @parameters = dbo.fhsmFNGetTaskParameter(@thisTask, @name);
					END;

					--
					-- Collect data
					--
					BEGIN
						SELECT
							@now = SYSDATETIME()
							,@nowUTC = SYSUTCDATETIME();
			';
			IF (@productVersion1 <= 14)
			BEGIN
				-- SQL Versions SQL2017 or lower

				SET @stmt += '
						SET @stmt = ''
							SELECT
								PARSENAME(mid.statement, 3) AS DatabaseName
								,PARSENAME(mid.statement, 2) AS SchemaName
								,PARSENAME(mid.statement, 1) AS ObjectName
								,CAST(NULL AS binary(8)) AS QueryHash
								,CAST(NULL AS nvarchar(max)) AS Statement
								,mid.equality_columns AS EqualityColumns
								,mid.inequality_columns AS InequalityColumns
								,mid.included_columns AS IncludedColumns
								,SUM(migs.unique_compiles) AS UniqueCompiles
								,SUM(migs.user_seeks) AS UserSeeks
								,SUM(migs.user_scans) AS UserScans
								,MAX(migs.last_user_seek) AS LastUserSeek
								,MAX(migs.last_user_scan) AS LastUserScan
								,AVG(migs.avg_total_user_cost) AS AvgTotalUserCost
								,AVG(migs.avg_user_impact) AS AvgUserImpact
								,SUM(migs.system_seeks) AS SystemSeeks
								,SUM(migs.system_scans) AS SystemScans
								,MAX(migs.last_system_seek) AS LastSystemSeek
								,MAX(migs.last_system_scan) AS LastSystemScan
								,AVG(migs.avg_total_system_cost) AS AvgTotalSystemCost
								,AVG(migs.avg_system_impact) AS AvgSystemImpact
								,(SELECT d.create_date FROM sys.databases AS d WITH (NOLOCK) WHERE (d.name = ''''tempdb'''')) AS LastSQLServiceRestart
								,@nowUTC, @now
							FROM sys.dm_db_missing_index_group_stats AS migs WITH (NOLOCK)
							INNER JOIN sys.dm_db_missing_index_groups AS mig WITH (NOLOCK) ON (mig.index_group_handle = migs.group_handle)
							INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK) ON (mid.index_handle = mig.index_handle)
							GROUP BY
								mid.statement
								,mid.equality_columns
								,mid.inequality_columns
								,mid.included_columns
				';
			END
			ELSE BEGIN
				SET @stmt += '
						SET @stmt = ''
							SELECT
								PARSENAME(mid.statement, 3) AS DatabaseName
								,PARSENAME(mid.statement, 2) AS SchemaName
								,PARSENAME(mid.statement, 1) AS ObjectName
								,migsq.query_hash AS QueryHash
								,MAX(SUBSTRING(
									dest.text,
									migsq.last_statement_start_offset / 2 + 1,
									(CASE migsq.last_statement_start_offset
										WHEN -1 THEN DATALENGTH(dest.text)
										ELSE migsq.last_statement_end_offset
									END - migsq.last_statement_start_offset) / 2 + 1
								)) AS Statement
								,mid.equality_columns AS EqualityColumns
								,mid.inequality_columns AS InequalityColumns
								,mid.included_columns AS IncludedColumns
								,NULL AS UniqueCompiles
								,SUM(migsq.user_seeks) AS UserSeeks
								,SUM(migsq.user_scans) AS UserScans
								,MAX(migsq.last_user_seek) AS LastUserSeek
								,MAX(migsq.last_user_scan) AS LastUserScan
								,AVG(migsq.avg_total_user_cost) AS AvgTotalUserCost
								,AVG(migsq.avg_user_impact) AS AvgUserImpact
								,SUM(migsq.system_seeks) AS SystemSeeks
								,SUM(migsq.system_scans) AS SystemScans
								,MAX(migsq.last_system_seek) AS LastSystemSeek
								,MAX(migsq.last_system_scan) AS LastSystemScan
								,AVG(migsq.avg_total_system_cost) AS AvgTotalSystemCost
								,AVG(migsq.avg_system_impact) AS AvgSystemImpact
								,(SELECT d.create_date FROM sys.databases AS d WITH (NOLOCK) WHERE (d.name = ''''tempdb'''')) AS LastSQLServiceRestart
								,@nowUTC, @now
							FROM sys.dm_db_missing_index_group_stats_query AS migsq WITH (NOLOCK)
							INNER JOIN sys.dm_db_missing_index_groups AS mig WITH (NOLOCK) ON (mig.index_group_handle = migsq.group_handle)
							INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK) ON (mid.index_handle = mig.index_handle)
							OUTER APPLY sys.dm_exec_sql_text(migsq.last_sql_handle) AS dest
							GROUP BY
								mid.statement
								,migsq.query_hash
								,mid.equality_columns
								,mid.inequality_columns
								,mid.included_columns
				';
			END

			SET @stmt += '
							UNION ALL

							SELECT
								''''<HeartBeat>'''' AS DatabaseName
								,''''<HeartBeat>'''' AS SchemaName
								,''''<HeartBeat>'''' AS ObjectName
								,NULL AS QueryHash
								,NULL AS Statement
								,NULL AS EqualityColumns
								,NULL AS InequalityColumns
								,NULL AS IncludedColumns
								,NULL AS UniqueCompiles
								,-1 AS UserSeeks
								,-1 AS UserScans
								,NULL AS LastUserSeek
								,NULL AS LastUserScan
								,-1 AS AvgTotalUserCost
								,-1 AS AvgUserImpact
								,-1 AS SystemSeeks
								,-1 AS SystemScans
								,NULL AS LastSystemSeek
								,NULL AS LastSystemScan
								,-1 AS AvgTotalSystemCost
								,-1 AS AvgSystemImpact
								,(SELECT d.create_date FROM sys.databases AS d WITH (NOLOCK) WHERE (d.name = ''''tempdb'''')) AS LastSQLServiceRestart
								,@nowUTC, @now
						'';
				';
				SET @stmt += '
						TRUNCATE TABLE dbo.fhsmMissingIndexesTemp;

						INSERT INTO dbo.fhsmMissingIndexesTemp(
							DatabaseName, SchemaName, ObjectName
							,QueryHash, Statement
							,EqualityColumns, InequalityColumns, IncludedColumns
							,UniqueCompiles
							,UserSeeks, UserScans
							,LastUserSeek, LastUserScan
							,AvgTotalUserCost, AvgUserImpact
							,SystemSeeks, SystemScans
							,LastSystemSeek, LastSystemScan
							,AvgTotalSystemCost, AvgSystemImpact
							,LastSQLServiceRestart
							,TimestampUTC, Timestamp
						)
						EXEC sp_executesql
							@stmt
							,N''@now datetime, @nowUTC datetime''
							,@now = @now, @nowUTC = @nowUTC;
				';
				SET @stmt += '
						INSERT INTO dbo.fhsmMissingIndexes(
							DatabaseName, SchemaName, ObjectName
							,QueryHash
							,EqualityColumns, InequalityColumns, IncludedColumns
							,UniqueCompiles
							,UserSeeks, UserScans
							,LastUserSeek, LastUserScan
							,AvgTotalUserCost, AvgUserImpact
							,SystemSeeks, SystemScans
							,LastSystemSeek, LastSystemScan
							,AvgTotalSystemCost, AvgSystemImpact
							,LastSQLServiceRestart
							,TimestampUTC, Timestamp
						)
						SELECT
							DatabaseName, SchemaName, ObjectName
							,QueryHash
							,EqualityColumns, InequalityColumns, IncludedColumns
							,UniqueCompiles
							,UserSeeks, UserScans
							,LastUserSeek, LastUserScan
							,AvgTotalUserCost, AvgUserImpact
							,SystemSeeks, SystemScans
							,LastSystemSeek, LastSystemScan
							,AvgTotalSystemCost, AvgSystemImpact
							,LastSQLServiceRestart
							,TimestampUTC, Timestamp
						FROM dbo.fhsmMissingIndexesTemp;
				';
				SET @stmt += '
						--
						-- Insert records into fhsmMissingIndexStatement
						--
						BEGIN
							MERGE dbo.fhsmMissingIndexStatement AS tgt
							USING (
								SELECT
									t.DatabaseName
									,t.QueryHash
									,MAX(t.Statement) AS Statement
								FROM dbo.fhsmMissingIndexesTemp AS t
								WHERE (t.QueryHash IS NOT NULL) AND (t.Statement IS NOT NULL)
								GROUP BY
									t.DatabaseName
									,t.QueryHash
							) AS src
							ON (src.DatabaseName = tgt.DatabaseName) AND (src.QueryHash = tgt.QueryHash)
							WHEN MATCHED AND (src.Statement <> tgt.Statement)
								THEN UPDATE SET
									tgt.UpdateCount = tgt.UpdateCount + 1
									,tgt.PrevStatement = tgt.Statement
									,tgt.Statement = src.Statement
							WHEN NOT MATCHED BY TARGET
								THEN INSERT(DatabaseName, QueryHash, Statement, UpdateCount)
								VALUES(src.DatabaseName, src.QueryHash, src.Statement, 0)
							;
						END;
				';
				SET @stmt += '
						--
						-- Delete records from fhsmMissingIndexStatement where no owner in fhsmMissingIndexes exists
						--
						BEGIN
							DELETE miStmt
							FROM dbo.fhsmMissingIndexStatement AS miStmt
							WHERE NOT EXISTS (
								SELECT *
								FROM dbo.fhsmMissingIndexes AS mi
								WHERE (mi.DatabaseName = miStmt.DatabaseName) AND (mi.QueryHash = miStmt.QueryHash)
							);
						END;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPMissingIndexes
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPMissingIndexes';
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
				,'dbo.fhsmMissingIndexes'
				,1
				,'TimestampUTC'
				,1
				,90
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
		schedules(Enabled, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters) AS(
			SELECT
				@enableMissingIndexes
				,'Missing indexes'
				,PARSENAME('dbo.fhsmSPMissingIndexes', 1)
				,1 * 60 * 60
				,CAST('1900-1-1T00:00:00.0000' AS datetime2(0))
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))
				,1, 1, 1, 1, 1, 1, 1
				,NULL
		)
		MERGE dbo.fhsmSchedules AS tgt
		USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(Enabled, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters)
			VALUES(src.Enabled, src.Name, src.Task, src.ExecutionDelaySec, src.FromTime, src.ToTime, src.Monday, src.Tuesday, src.Wednesday, src.Thursday, src.Friday, src.Saturday, src.Sunday, src.Parameters);
	END;

	--
	-- Register dimensions
	--
	BEGIN
		WITH
		dimensions(
			DimensionName, DimensionKey
			,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
			,SrcColumn1, SrcColumn2, SrcColumn3
			,OutputColumn1, OutputColumn2, OutputColumn3
		) AS (
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmMissingIndexes' AS SrcTable
				,'src' AS SrcAlias
				,'WHERE ((src.DatabaseName <> ''<HeartBeat>'') OR (src.SchemaName <> ''<HeartBeat>'') OR (src.ObjectName <> ''<HeartBeat>''))' AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL
				,'Database', NULL, NULL

			UNION ALL

			SELECT
				'Schema' AS DimensionName
				,'SchemaKey' AS DimensionKey
				,'dbo.fhsmMissingIndexes' AS SrcTable
				,'src' AS SrcAlias
				,'WHERE ((src.DatabaseName <> ''<HeartBeat>'') OR (src.SchemaName <> ''<HeartBeat>'') OR (src.ObjectName <> ''<HeartBeat>''))' AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', NULL
				,'Database', 'Schema', NULL

			UNION ALL

			SELECT
				'Object' AS DimensionName
				,'ObjectKey' AS DimensionKey
				,'dbo.fhsmMissingIndexes' AS SrcTable
				,'src' AS SrcAlias
				,'WHERE ((src.DatabaseName <> ''<HeartBeat>'') OR (src.SchemaName <> ''<HeartBeat>'') OR (src.ObjectName <> ''<HeartBeat>''))' AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]'
				,'Database', 'Schema', 'Object'
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
				,tgt.OutputColumn1 = src.OutputColumn1
				,tgt.OutputColumn2 = src.OutputColumn2
				,tgt.OutputColumn3 = src.OutputColumn3
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(
				DimensionName, DimensionKey
				,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
				,SrcColumn1, SrcColumn2, SrcColumn3
				,OutputColumn1, OutputColumn2, OutputColumn3
			)
			VALUES(
				src.DimensionName, src.DimensionKey
				,src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn
				,src.SrcColumn1, src.SrcColumn2, src.SrcColumn3
				,src.OutputColumn1, src.OutputColumn2, src.OutputColumn3
			);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmMissingIndexes';
	END;
END;
