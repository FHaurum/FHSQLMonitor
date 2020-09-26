SET NOCOUNT ON;

--
-- Test if we are in a database with FHSM registered
--
IF (dbo.fhsmFNIsValidInstallation() = 0)
BEGIN
	RAISERROR('Can not install as it appears the database is not correct installed', 0, 1) WITH NOWAIT;
END
ELSE IF (
	(OBJECT_ID('dbo.CommandLog', 'U') IS NULL)
	OR (OBJECT_ID('dbo.CommandExecute', 'P') IS NULL)
	OR (OBJECT_ID('dbo.IndexOptimize', 'P') IS NULL)
)
BEGIN
	RAISERROR('Can not be installed before Ola Hallengren objects are installed', 0, 1) WITH NOWAIT;
END
ELSE BEGIN
	--
	-- Declare variables
	--
	BEGIN
		DECLARE @myUserName nvarchar(128);
		DECLARE @nowUTC datetime;
		DECLARE @nowUTCStr nvarchar(128);
		DECLARE @objectName nvarchar(128);
		DECLARE @objName nvarchar(128);
		DECLARE @pbiSchema nvarchar(128);
		DECLARE @schName nvarchar(128);
		DECLARE @stmt nvarchar(max);
		DECLARE @version nvarchar(128);

		SET @myUserName = SUSER_NAME();
		SET @nowUTC = SYSUTCDATETIME();
		SET @nowUTCStr = CONVERT(nvarchar(128), @nowUTC, 126);
		SET @pbiSchema = dbo.fhsmFNGetConfiguration('PBISchema');
		SET @version = '1.0';
	END;

	--
	-- Create tables
	--
	BEGIN
		--
		-- Create index on dbo.CommandLog
		--
		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.CommandLog')) AND (i.name = 'NC_CommandLog_StartTime'))
		BEGIN
			CREATE NONCLUSTERED INDEX NC_CommandLog_StartTime ON dbo.CommandLog(StartTime ASC);
		END;

		--
		-- Create index on dbo.CommandLog
		--
		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.CommandLog')) AND (i.name = 'NC_CommandLog_DatabaseName_SchemaName_ObjectName_IndexName'))
		BEGIN
			CREATE NONCLUSTERED INDEX NC_CommandLog_DatabaseName_SchemaName_ObjectName_IndexName ON dbo.CommandLog(DatabaseName, SchemaName, ObjectName, IndexName);
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
					END Type
					,COALESCE(NULLIF(DATEDIFF(SECOND, cl.StartTime, cl.EndTime), 0), 1) AS Duration		-- Duration of 0 sec. will always be 1 sec.
					,CAST(cl.StartTime AS date) AS Date
					,(DATEPART(HOUR, cl.StartTime) * 60 * 60) + (DATEPART(MINUTE, cl.StartTime) * 60) + (DATEPART(SECOND, cl.StartTime)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(cl.DatabaseName, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(cl.DatabaseName, cl.SchemaName, DEFAULT, DEFAULT) AS k) AS SchemaKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(cl.DatabaseName, cl.SchemaName, cl.ObjectName, DEFAULT) AS k) AS ObjectKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(cl.DatabaseName, cl.SchemaName, cl.ObjectName, COALESCE(cl.IndexName, ''N.A.'')) AS k) AS IndexKey
				FROM dbo.CommandLog AS cl;
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
	END;

	--
	-- Create stored procedures
	--
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
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @parameters nvarchar(max);
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);

					--
					-- Get the parametrs for the command
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
	-- Register retention
	--
	BEGIN
		WITH
		retention(Enabled, TableName, TimeColumn, IsUtc, Days) AS(
			SELECT
				1
				,'dbo.CommandLog'
				,'StartTime'
				,0
				,30
		)
		MERGE dbo.fhsmRetentions AS tgt
		USING retention AS src ON (src.TableName = tgt.TableName)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(Enabled, TableName, TimeColumn, IsUtc, Days)
			VALUES(src.Enabled, src.TableName, src.TimeColumn, src.IsUtc, src.Days);
	END;

	--
	-- Register schedules
	--
	BEGIN
		WITH
		schedules(Enabled, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters) AS(
			SELECT
				0
				,'Index rebuild'
				,PARSENAME('dbo.fhsmSPIndexOptimize', 1)
				,12 * 60 * 60
				,TIMEFROMPARTS(2, 0, 0, 0, 0)
				,TIMEFROMPARTS(4, 0, 0, 0, 0)
				,1, 1, 1, 1, 1, 1, 1
				,'@Databases = ''USER_DATABASES'', @TimeLimit = 1800, @FragmentationLow = NULL, @FragmentationMedium = NULL, @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationLevel2 = 30, @LogToTable = ''Y'''

			UNION ALL

			SELECT
				0
				,'Index reorganize'
				,PARSENAME('dbo.fhsmSPIndexOptimize', 1)
				,12 * 60 * 60
				,TIMEFROMPARTS(0, 0, 0, 0, 0)
				,TIMEFROMPARTS(2, 0, 0, 0, 0)
				,1, 1, 1, 1, 1, 1, 1
				,'@Databases = ''USER_DATABASES'', @TimeLimit = 1800, @FragmentationLow = NULL, @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationHigh = NULL, @FragmentationLevel1 = 5, @LogToTable = ''Y'''

			UNION ALL

			SELECT
				0
				,'Update modified statistics'
				,PARSENAME('dbo.fhsmSPIndexOptimize', 1)
				,12 * 60 * 60
				,TIMEFROMPARTS(4, 0, 0, 0, 0)
				,TIMEFROMPARTS(6, 0, 0, 0, 0)
				,1, 1, 1, 1, 1, 1, 0
				,'@Databases = ''USER_DATABASES'', @TimeLimit = 1800, @FragmentationLow = NULL, @FragmentationMedium = NULL, @FragmentationHigh = NULL, @UpdateStatistics = ''ALL'', @OnlyModifiedStatistics = ''Y'', @LogToTable = ''Y'''

			UNION ALL

			SELECT
				0
				,'Update all statistics'
				,PARSENAME('dbo.fhsmSPIndexOptimize', 1)
				,12 * 60 * 60
				,TIMEFROMPARTS(4, 0, 0, 0, 0)
				,TIMEFROMPARTS(6, 0, 0, 0, 0)
				,0, 0, 0, 0, 0, 0, 1
				,'@Databases = ''USER_DATABASES'', @TimeLimit = 1800, @FragmentationLow = NULL, @FragmentationMedium = NULL, @FragmentationHigh = NULL, @UpdateStatistics = ''ALL'', @LogToTable = ''Y'''
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
		dimensions(DimensionName, DimensionKey, SrcTable, SrcAlias, SrcWhere, SrcDateColumn, SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4, OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4) AS(
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.CommandLog' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[StartTime]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL
				,'Database', NULL, NULL, NULL

			UNION ALL

			SELECT
				'Schema' AS DimensionName
				,'SchemaKey' AS DimensionKey
				,'dbo.CommandLog' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[StartTime]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', NULL, NULL
				,'Database', 'Schema', NULL, NULL

			UNION ALL

			SELECT
				'Object' AS DimensionName
				,'ObjectKey' AS DimensionKey
				,'dbo.CommandLog' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[StartTime]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', NULL
				,'Database', 'Schema', 'Object', NULL

			UNION ALL

			SELECT
				'Index' AS DimensionName
				,'IndexKey' AS DimensionKey
				,'dbo.CommandLog' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[StartTime]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'COALESCE(src.[IndexName], ''N.A.'')'
				,'Database', 'Schema', 'Object', 'Index'
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
				,tgt.OutputColumn1 = src.OutputColumn1
				,tgt.OutputColumn2 = src.OutputColumn2
				,tgt.OutputColumn3 = src.OutputColumn3
				,tgt.OutputColumn4 = src.OutputColumn4
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(DimensionName, DimensionKey, SrcTable, SrcAlias, SrcWhere, SrcDateColumn, SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4, OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4)
			VALUES(src.DimensionName, src.DimensionKey, src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn, src.SrcColumn1, src.SrcColumn2, src.SrcColumn3, src.SrcColumn4, src.OutputColumn1, src.OutputColumn2, src.OutputColumn3, src.OutputColumn4);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.CommandLog';
	END;
END;
