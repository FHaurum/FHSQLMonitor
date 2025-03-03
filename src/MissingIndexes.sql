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
		SET @version = '2.0';

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
	-- Create tables
	--
	BEGIN
		--
		-- Create table dbo.fhsmMissingIndexes if it not already exists
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

				CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexes_TimestampUTC ON dbo.fhsmMissingIndexes(TimestampUTC)' + @tableCompressionStmt + ';
				CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexes_Timestamp ON dbo.fhsmMissingIndexes(Timestamp)' + @tableCompressionStmt + ';
				CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexes_DatabaseName_SchemaName_ObjectName_IndexName ON dbo.fhsmMissingIndexes(DatabaseName, SchemaName, ObjectName)' + @tableCompressionStmt + ';
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
						,ROW_NUMBER() OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS Idx
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
					,b.LastUserSeekDate
					,b.LastUserSeekTimeKey
					,b.Date
					,b.TimeKey
					,b.DatabaseKey
					,b.SchemaKey
					,b.ObjectKey
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
						,a.LastUserSeekDate
						,a.LastUserSeekTimeKey
						,a.Date
						,a.TimeKey
						,a.DatabaseKey
						,a.SchemaKey
						,a.ObjectKey
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
							,CAST(mi.LastUserSeek AS date) AS LastUserSeekDate
							,(DATEPART(HOUR, mi.LastUserSeek) * 60 * 60) + (DATEPART(MINUTE, mi.LastUserSeek) * 60) + (DATEPART(SECOND, mi.LastUserSeek)) AS LastUserSeekTimeKey
							,CAST(mi.Timestamp AS date) AS Date
							,(DATEPART(HOUR, mi.Timestamp) * 60 * 60) + (DATEPART(MINUTE, mi.Timestamp) * 60) + (DATEPART(SECOND, mi.Timestamp)) AS TimeKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(mi.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(mi.DatabaseName, mi.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(mi.DatabaseName, mi.SchemaName, mi.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
						FROM missingIndexes AS mi
						LEFT OUTER JOIN missingIndexes AS prevMi ON
							(prevMi.DatabaseName = mi.DatabaseName)
							AND (prevMi.SchemaName = mi.SchemaName)
							AND (prevMi.ObjectName = mi.ObjectName)
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
							,LAG(mi.UniqueCompiles) OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS PreviousUniqueCompiles
							,mi.UserSeeks
							,LAG(mi.UserSeeks) OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS PreviousUserSeeks
							,mi.LastUserSeek
							,mi.UserScans
							,LAG(mi.UserScans) OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS PreviousUserScans
							,mi.LastUserScan
							,mi.AvgTotalUserCost
							,mi.AvgUserImpact
							,mi.SystemSeeks
							,LAG(mi.SystemSeeks) OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS PreviousSystemSeeks
							,mi.LastSystemSeek
							,mi.SystemScans
							,LAG(mi.SystemScans) OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS PreviousSystemScans
							,mi.LastSystemScan
							,mi.AvgTotalSystemCost
							,mi.AvgSystemImpact
							,mi.LastSQLServiceRestart
							,LAG(mi.LastSQLServiceRestart) OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS PreviousLastSQLServiceRestart
							,CAST(mi.LastUserSeek AS date) AS LastUserSeekDate
							,(DATEPART(HOUR, mi.LastUserSeek) * 60 * 60) + (DATEPART(MINUTE, mi.LastUserSeek) * 60) + (DATEPART(SECOND, mi.LastUserSeek)) AS LastUserSeekTimeKey
							,CAST(mi.Timestamp AS date) AS Date
							,(DATEPART(HOUR, mi.Timestamp) * 60 * 60) + (DATEPART(MINUTE, mi.Timestamp) * 60) + (DATEPART(SECOND, mi.Timestamp)) AS TimeKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(mi.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(mi.DatabaseName, mi.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(mi.DatabaseName, mi.SchemaName, mi.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
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

						SET @stmt = ''
							SELECT
								PARSENAME(mid.statement, 3) AS DatabaseName
								,PARSENAME(mid.statement, 2) AS SchemaName
								,PARSENAME(mid.statement, 1) AS ObjectName
								,mid.equality_columns AS EqualityColumns
								,mid.inequality_columns AS InequalityColumns
								,mid.included_columns AS IncludedColumns
								,migs.unique_compiles AS UniqueCompiles
								,migs.user_seeks AS UserSeeks
								,migs.user_scans AS UserScans
								,migs.last_user_seek AS LastUserSeek
								,migs.last_user_scan AS LastUserScan
								,migs.avg_total_user_cost AS AvgTotalUserCost
								,migs.avg_user_impact AS AvgUserImpact
								,migs.system_seeks AS SystemSeeks
								,migs.system_scans AS SystemScans
								,migs.last_system_seek AS LastSystemSeek
								,migs.last_system_scan AS LastSystemScan
								,migs.avg_total_system_cost AS AvgTotalSystemCost
								,migs.avg_system_impact AS AvgSystemImpact
								,(SELECT d.create_date FROM sys.databases AS d WITH (NOLOCK) WHERE (d.name = ''''tempdb'''')) AS LastSQLServiceRestart
								,@nowUTC, @now
							FROM sys.dm_db_missing_index_group_stats AS migs WITH (NOLOCK)
							INNER JOIN sys.dm_db_missing_index_groups AS mig WITH (NOLOCK) ON (mig.index_group_handle = migs.group_handle)
							INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK) ON (mid.index_handle = mig.index_handle)

							UNION ALL

							SELECT
								''''<HeartBeat>'''' AS DatabaseName
								,''''<HeartBeat>'''' AS SchemaName
								,''''<HeartBeat>'''' AS ObjectName
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
						INSERT INTO dbo.fhsmMissingIndexes(
							DatabaseName, SchemaName, ObjectName
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
		USING schedules AS src ON (src.Name = tgt.Name)
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
