SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableIndexRebuild bit;
	DECLARE @enableIndexReorganize bit;
	DECLARE @enableUpdateAllStatistics bit;
	DECLARE @enableUpdateModifiedStatistics bit;

	SET @enableIndexRebuild = 0;
	SET @enableIndexReorganize = 0;
	SET @enableUpdateAllStatistics = 0;
	SET @enableUpdateModifiedStatistics = 0;
END;

--
-- Specify where the Ola Hallengren objects are installed
--
BEGIN
	DECLARE @olaDatabase nvarchar(128);

	SET @olaDatabase = NULL;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing IndexOptimize-004', 0, 1) WITH NOWAIT;
END;

--
-- Do not change anything below here
--

--
-- Declare variables
--
BEGIN
	DECLARE @configuredOlaDatabase nvarchar(128);
	DECLARE @edition nvarchar(128);
	DECLARE @msg nvarchar(max);
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
-- Initialize @returnValue to true value
--
SET @returnValue = 1;

--
-- Test if we are in a database with FHSM registered
--
IF (@returnValue <> 0)
BEGIN
	IF OBJECT_ID('dbo.fhsmFNIsValidInstallation') IS NOT NULL
	BEGIN
		SET @returnValue = dbo.fhsmFNIsValidInstallation();
	END;

	IF (@returnValue = 0)
	BEGIN
		RAISERROR('Can not install as it appears the database is not correct installed', 0, 1) WITH NOWAIT;
	END
END;

--
-- If @olaDatabase is NULL try and lookup a previously configured value
-- If @olaDatabase is the same as the current database, set it to NULL
--
IF (@returnValue <> 0)
BEGIN
	IF (@olaDatabase IS NULL)
	BEGIN
		SET @configuredOlaDatabase = (
			SELECT dsre.referenced_database_name
			FROM sys.dm_sql_referenced_entities('FHSM.Database', 'OBJECT') AS dsre
			WHERE (1 = 1)
				AND (dsre.referenced_minor_id = 0)
				AND (dsre.referenced_schema_name = 'dbo')
				AND (dsre.referenced_entity_name = 'CommandLog')
		);

		IF (@configuredOlaDatabase IS NOT NULL)
		BEGIN
			SET @msg = 'Installing IndexOptimize-004 using the already configured database ' + QUOTENAME(@configuredOlaDatabase) + ' as the Ola Hallengren database';
			RAISERROR(@msg, 0, 1) WITH NOWAIT;

			SET @olaDatabase = @configuredOlaDatabase;
		END;
	END
	ELSE IF (@olaDatabase = DB_NAME())
	BEGIN
		SET @olaDatabase = NULL;
	END;
END;

--
-- Test if the Ola Hallengren table CommandLog exists
--
IF (@returnValue <> 0)
BEGIN
	SET @stmt = '
		USE ' + QUOTENAME(COALESCE(@olaDatabase, DB_NAME())) + '
		SET @returnValue = OBJECT_ID(''dbo.CommandLog'');
		SET @returnValue = COALESCE(@returnValue, 0);
	';
	EXEC sp_executesql
		@stmt
		,N'@returnValue int OUTPUT'
		,@returnValue = @returnValue OUTPUT;

	IF (@returnValue = 0)
	BEGIN
		RAISERROR('Can not install as the Ola Hallengren table dbo.CommandLog does not exist', 0, 1) WITH NOWAIT;
	END;
END;

IF (@returnValue <> 0)
BEGIN
	--
	-- Initialize variables
	--
	BEGIN
		SET @myUserName = SUSER_NAME();
		SET @nowUTC = SYSUTCDATETIME();
		SET @nowUTCStr = CONVERT(nvarchar(128), @nowUTC, 126);
		SET @pbiSchema = dbo.fhsmFNGetConfiguration('PBISchema');
		SET @version = '2.8';

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
	-- Create indexes and register properties, even if using an Ola Hallengren installation in another database
	--
	BEGIN
		--
		-- Create index on dbo.CommandLog
		--
		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.CommandLog')) AND (i.name = 'NC_CommandLog_StartTime'))
		BEGIN
			RAISERROR('Adding index [NC_CommandLog_StartTime] to table dbo.CommandLog', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_CommandLog_StartTime ON dbo.CommandLog(StartTime ASC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Create index on dbo.CommandLog
		--
		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.CommandLog')) AND (i.name = 'NC_CommandLog_DatabaseName_SchemaName_ObjectName_IndexName'))
		BEGIN
			RAISERROR('Adding index [NC_CommandLog_DatabaseName_SchemaName_ObjectName_IndexName] to table dbo.CommandLog', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_CommandLog_DatabaseName_SchemaName_ObjectName_IndexName ON dbo.CommandLog(DatabaseName, SchemaName, ObjectName, IndexName)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.CommandLog (Ola Hallengren)
		--
		BEGIN
			SET @objectName = 'dbo.CommandLog';
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
		-- Create fact view @pbiSchema.[Index optimize]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index optimize') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index optimize') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index optimize') + '
				AS
				SELECT
					CASE
						WHEN (cl.CommandType = ''ALTER_INDEX'') AND (cl.Command LIKE ''% REBUILD %'') THEN 1
						WHEN (cl.CommandType = ''ALTER_INDEX'') AND (cl.Command LIKE ''% REORGANIZE %'') THEN 2
						WHEN (cl.CommandType = ''UPDATE_STATISTICS'') THEN 3
						WHEN (cl.CommandType = ''BACKUP_DATABASE'') THEN 4
						WHEN (cl.CommandType = ''BACKUP_LOG'') THEN 5
						WHEN (cl.CommandType = ''RESTORE_VERIFYONLY'') THEN 6
						WHEN (cl.CommandType = ''DBCC_CHECKDB'') THEN 7
						WHEN (cl.CommandType = ''xp_create_subdir'') THEN 8
						WHEN (cl.CommandType = ''xp_delete_file'') THEN 9
					END Type
					,COALESCE(NULLIF(DATEDIFF(SECOND, cl.StartTime, cl.EndTime), 0), 1) AS Duration		-- Duration of 0 sec. will always be 1 sec.
					,CAST(cl.StartTime AS date) AS Date
					,(DATEPART(HOUR, cl.StartTime) * 60 * 60) + (DATEPART(MINUTE, cl.StartTime) * 60) + (DATEPART(SECOND, cl.StartTime)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(cl.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(cl.DatabaseName, cl.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(cl.DatabaseName, cl.SchemaName, cl.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(cl.DatabaseName, cl.SchemaName, cl.ObjectName, COALESCE(cl.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
				FROM ' + COALESCE(QUOTENAME(@olaDatabase) + '.', '') + 'dbo.CommandLog AS cl;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Index optimize]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index optimize');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[OH errors]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('OH errors') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('OH errors') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('OH errors') + '
				AS
				SELECT
					CASE
						WHEN (cl.CommandType = ''ALTER_INDEX'') AND (cl.Command LIKE ''% REBUILD %'') THEN 1
						WHEN (cl.CommandType = ''ALTER_INDEX'') AND (cl.Command LIKE ''% REORGANIZE %'') THEN 2
						WHEN (cl.CommandType = ''UPDATE_STATISTICS'') THEN 3
						WHEN (cl.CommandType = ''BACKUP_DATABASE'') THEN 4
						WHEN (cl.CommandType = ''BACKUP_LOG'') THEN 5
						WHEN (cl.CommandType = ''RESTORE_VERIFYONLY'') THEN 6
						WHEN (cl.CommandType = ''DBCC_CHECKDB'') THEN 7
						WHEN (cl.CommandType = ''xp_create_subdir'') THEN 8
						WHEN (cl.CommandType = ''xp_delete_file'') THEN 9
					END Type
					,cl.StartTime
					,cl.EndTime
					,COALESCE(NULLIF(DATEDIFF(SECOND, cl.StartTime, cl.EndTime), 0), 1) AS Duration		-- Duration of 0 sec. will always be 1 sec.
					,cl.Command
					,cl.ErrorNumber
					,cl.ErrorMessage
					,CAST(cl.StartTime AS date) AS Date
					,(DATEPART(HOUR, cl.StartTime) * 60 * 60) + (DATEPART(MINUTE, cl.StartTime) * 60) + (DATEPART(SECOND, cl.StartTime)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(cl.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(cl.DatabaseName, cl.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(cl.DatabaseName, cl.SchemaName, cl.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(cl.DatabaseName, cl.SchemaName, cl.ObjectName, COALESCE(cl.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
				FROM ' + COALESCE(QUOTENAME(@olaDatabase) + '.', '') + 'dbo.CommandLog AS cl
				WHERE (cl.ErrorNumber <> 0) OR (cl.ErrorMessage IS NOT NULL);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[OH errors]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('OH errors');
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
	-- Create stored procedures, but only if on FHSQLMonitor database
	--
	IF (DB_NAME() = COALESCE(@olaDatabase, DB_NAME()))
	BEGIN
		--
		-- Create stored procedure dbo.fhsmSPIndexOptimize
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPIndexOptimize'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPIndexOptimize AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPIndexOptimize (
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

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
					-- Call Ola Hallengren
					--
					BEGIN
						SET @stmt = ''EXEC dbo.IndexOptimize '' + @parameters;
						EXEC(@stmt);
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPIndexOptimize
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPIndexOptimize';
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
	-- Register retention, but only if on FHSQLMonitor database
	--
	IF (DB_NAME() = COALESCE(@olaDatabase, DB_NAME()))
	BEGIN
		WITH
		retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter) AS(
			SELECT
				1
				,'dbo.CommandLog'
				,1
				,'StartTime'
				,0
				,30
				,NULL
		)
		MERGE dbo.fhsmRetentions AS tgt
		USING retention AS src ON (src.TableName = tgt.TableName) AND (src.Sequence = tgt.Sequence)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter)
			VALUES(src.Enabled, src.TableName, src.Sequence, src.TimeColumn, src.IsUtc, src.Days, src.Filter);
	END;

	--
	-- Register schedules, but only if on FHSQLMonitor database
	--
	IF (DB_NAME() = COALESCE(@olaDatabase, DB_NAME()))
	BEGIN
		WITH
		schedules(Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters) AS(
			SELECT
				@enableIndexRebuild								AS Enabled
				,0												AS DeploymentStatus
				,'Index rebuild'								AS Name
				,PARSENAME('dbo.fhsmSPIndexOptimize', 1)		AS Task
				,12 * 60 * 60									AS ExecutionDelaySec
				,CAST('1900-1-1T02:00:00.0000' AS datetime2(0))	AS FromTime
				,CAST('1900-1-1T04:00:00.0000' AS datetime2(0))	AS ToTime
				,1, 1, 1, 1, 1, 1, 1							-- Monday..Sunday
				,'@Databases = ''USER_DATABASES, msdb'', @TimeLimit = 1800, @FragmentationLow = NULL, @FragmentationMedium = NULL, @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationLevel2 = 30, @LogToTable = ''Y'''

			UNION ALL

			SELECT
				@enableIndexReorganize							AS Enabled
				,0												AS DeploymentStatus
				,'Index reorganize'								AS Name
				,PARSENAME('dbo.fhsmSPIndexOptimize', 1)		AS Task
				,12 * 60 * 60									AS ExecutionDelaySec
				,CAST('1900-1-1T00:00:00.0000' AS datetime2(0))	AS FromTime
				,CAST('1900-1-1T02:00:00.0000' AS datetime2(0))	AS ToTime
				,1, 1, 1, 1, 1, 1, 1							-- Monday..Sunday
				,'@Databases = ''USER_DATABASES, msdb'', @TimeLimit = 1800, @FragmentationLow = NULL, @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationHigh = NULL, @FragmentationLevel1 = 5, @LogToTable = ''Y'''

			UNION ALL

			SELECT
				@enableUpdateAllStatistics						AS Enabled
				,0												AS DeploymentStatus
				,'Update all statistics'						AS Name
				,PARSENAME('dbo.fhsmSPIndexOptimize', 1)		AS Task
				,12 * 60 * 60									AS ExecutionDelaySec
				,CAST('1900-1-1T04:00:00.0000' AS datetime2(0))	AS FromTime
				,CAST('1900-1-1T06:00:00.0000' AS datetime2(0))	AS ToTime
				,0, 0, 0, 0, 0, 0, 1							-- Monday..Sunday
				,'@Databases = ''USER_DATABASES, msdb'', @TimeLimit = 1800, @FragmentationLow = NULL, @FragmentationMedium = NULL, @FragmentationHigh = NULL, @UpdateStatistics = ''ALL'', @LogToTable = ''Y'''

			UNION ALL

			SELECT
				@enableUpdateModifiedStatistics					AS Enabled
				,0												AS DeploymentStatus
				,'Update modified statistics'					AS Name
				,PARSENAME('dbo.fhsmSPIndexOptimize', 1)		AS Task
				,12 * 60 * 60									AS ExecutionDelaySec
				,CAST('1900-1-1T04:00:00.0000' AS datetime2(0))	AS FromTime
				,CAST('1900-1-1T06:00:00.0000' AS datetime2(0))	AS ToTime
				,1, 1, 1, 1, 1, 1, 0							-- Monday..Sunday
				,'@Databases = ''USER_DATABASES, msdb'', @TimeLimit = 1800, @FragmentationLow = NULL, @FragmentationMedium = NULL, @FragmentationHigh = NULL, @UpdateStatistics = ''ALL'', @OnlyModifiedStatistics = ''Y'', @LogToTable = ''Y'''
		)
		MERGE dbo.fhsmSchedules AS tgt
		USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters)
			VALUES(src.Enabled, src.DeploymentStatus, src.Name, src.Task, src.ExecutionDelaySec, src.FromTime, src.ToTime, src.Monday, src.Tuesday, src.Wednesday, src.Thursday, src.Friday, src.Saturday, src.Sunday, src.Parameters);
	END;

	--
	-- Register dimensions
	--
	BEGIN
		WITH
		dimensions(
			DimensionName, DimensionKey
			,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
			,SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4
			,OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4
		) AS (
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,COALESCE(QUOTENAME(@olaDatabase) + '.', '') + 'dbo.CommandLog' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[StartTime]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL
				,'Database', NULL, NULL, NULL

			UNION ALL

			SELECT
				'Schema' AS DimensionName
				,'SchemaKey' AS DimensionKey
				,COALESCE(QUOTENAME(@olaDatabase) + '.', '') + 'dbo.CommandLog' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[StartTime]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', NULL, NULL
				,'Database', 'Schema', NULL, NULL

			UNION ALL

			SELECT
				'Object' AS DimensionName
				,'ObjectKey' AS DimensionKey
				,COALESCE(QUOTENAME(@olaDatabase) + '.', '') + 'dbo.CommandLog' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[StartTime]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', NULL
				,'Database', 'Schema', 'Object', NULL

			UNION ALL

			SELECT
				'Index' AS DimensionName
				,'IndexKey' AS DimensionKey
				,COALESCE(QUOTENAME(@olaDatabase) + '.', '') + 'dbo.CommandLog' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[StartTime]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'COALESCE(src.[IndexName], ''N.A.'')'
				,'Database', 'Schema', 'Object', 'Index'
		)
		MERGE dbo.fhsmDimensions AS tgt
		USING dimensions AS src ON (src.DimensionName = tgt.DimensionName) AND (PARSENAME(src.SrcTable, 1) = PARSENAME(tgt.SrcTable, 1))
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
				,tgt.OutputColumn1 = src.OutputColumn1
				,tgt.OutputColumn2 = src.OutputColumn2
				,tgt.OutputColumn3 = src.OutputColumn3
				,tgt.OutputColumn4 = src.OutputColumn4
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(
				DimensionName, DimensionKey
				,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
				,SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4
				,OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4
			)
			VALUES(
				src.DimensionName, src.DimensionKey
				,src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn
				,src.SrcColumn1, src.SrcColumn2, src.SrcColumn3, src.SrcColumn4
				,src.OutputColumn1, src.OutputColumn2, src.OutputColumn3, src.OutputColumn4
			);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		SET @stmt = COALESCE(QUOTENAME(@olaDatabase) + '.', '') + 'dbo.CommandLog';
		EXEC dbo.fhsmSPUpdateDimensions @table = @stmt;
	END;
END;
