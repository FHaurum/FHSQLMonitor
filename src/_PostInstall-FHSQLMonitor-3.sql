SET NOCOUNT ON;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Post-installing-3 FHSQLMonitor main', 0, 1) WITH NOWAIT;
END;

--
-- Declare variables
--
BEGIN
	DECLARE @returnValue int;
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
	-- Update parameter for fhsmSPQueryStatistics if it is the default
	--
	BEGIN
		WITH
		schedules(Name, Task, Parameter) AS(
			SELECT
				'Query statistics'							AS Name
				,PARSENAME('dbo.fhsmSPQueryStatistics', 1)	AS Task
				,'@NumberOfRows=1000 ; @Databases = ''USER_DATABASES, msdb'' ; @NumberOfStoredProcedures=25'
		)
		MERGE dbo.fhsmSchedules AS tgt
		USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
		WHEN MATCHED AND (tgt.Parameter = '@NumberOfRows=1000')
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

	--
	-- Delete configuration keys used temporarely during development of 2.13.0
	--
	BEGIN
		DELETE c
		FROM dbo.fhsmConfigurations AS c
		WHERE (c.[Key] IN ('View.BlockedProcess.Rows', 'View.Deadlock.Rows'))
	END;
END;
