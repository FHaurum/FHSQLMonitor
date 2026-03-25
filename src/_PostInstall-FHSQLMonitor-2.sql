SET NOCOUNT ON;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Post-installing-2 FHSQLMonitor main', 0, 1) WITH NOWAIT;
END;

--
-- Declare variables
--
BEGIN
	DECLARE @msg nvarchar(max);
	DECLARE @returnValue int;
	DECLARE @stmt nvarchar(max);
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
	-- Register dimensions for dbo.fhsmProcessing
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
				'Task name version' AS DimensionName
				,'TaskNameVersionKey' AS DimensionKey
				,'dbo.fhsmProcessing' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[StartedTimestamp]' AS SrcDateColumn
				,'src.[Task]', 'src.[Name]', 'src.[Version]', NULL
				,'Task', 'Name', 'Version', NULL
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
	-- Update parameter for fhsmSPInstanceState if it is the default
	--
	BEGIN
		WITH
		schedules(Name, Task, Parameter) AS(
			SELECT
				'Instance state'							AS Name
				,PARSENAME('dbo.fhsmSPInstanceState', 1)	AS Task
				,'@SeverityLevel = 17 ; @MessageIds = 833, 3197, 3198'
		)
		MERGE dbo.fhsmSchedules AS tgt
		USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
		WHEN MATCHED AND (tgt.Parameter = '@SeverityLevel = 17')
			THEN UPDATE SET
				tgt.Parameter = src.Parameter;
	END;

	--
	-- Update parameter for fhsmSPWhoIsActive if it is the default
	--
	BEGIN
		WITH
		schedules(Name, Task, Parameter) AS(
			SELECT
				'Who is active'							AS Name
				,PARSENAME('dbo.fhsmSPWhoIsActive', 1)	AS Task
				,'@format_output = 0, @get_transaction_info = 1, @get_outer_command = 1, @get_plans = 1, @destination_table = ''<FHSQLMonitorDatabase>.dbo.fhsmWhoIsActive'''
		)
		MERGE dbo.fhsmSchedules AS tgt
		USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
		WHEN MATCHED AND (tgt.Parameter = '@format_output = 0, @get_transaction_info = 1, @get_outer_command = 1, @get_plans = 1, @destination_table = ''' + QUOTENAME(DB_NAME()) + '.dbo.fhsmWhoIsActive''')
			THEN UPDATE SET
				tgt.Parameter = src.Parameter;
	END;
END;
