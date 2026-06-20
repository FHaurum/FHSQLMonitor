SET NOCOUNT ON;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Post-installing-4 FHSQLMonitor main', 0, 1) WITH NOWAIT;
END;

--
-- Declare variables
--
BEGIN
	DECLARE @DEFAULT_SAMPLE_CNT int;
	DECLARE @DEFAULT_THRESHOLD_FACTOR int;
	DECLARE @DEFAULT_THRESHOLD_TIME int;
	DECLARE @parameter nvarchar(max);
	DECLARE @parameterTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
	DECLARE @returnValue int;
	DECLARE @sampleCnt int;
	DECLARE @thresholdFactor int;
	DECLARE @thresholdTime int;
	DECLARE @valueStr nvarchar(128);

	SET @DEFAULT_SAMPLE_CNT = 10;
	SET @DEFAULT_THRESHOLD_FACTOR = 10;
	SET @DEFAULT_THRESHOLD_TIME = 60;
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
	-- Add default parameters for Schedule if they are not there
	--
	BEGIN
		--
		-- Get the parameter for the command
		--
		BEGIN
			SET @parameter = dbo.fhsmFNGetTaskParameter(PARSENAME('dbo.fhsmSPSchedules', 1), 'Schedules');

			INSERT INTO @parameterTable([Key], Value)
			SELECT
				(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, '=') AS s WHERE (s.Part = 1)) AS [Key]
				,(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, '=') AS s WHERE (s.Part = 2)) AS Value
			FROM dbo.fhsmFNSplitString(@parameter, ';') AS p;

			SET @valueStr = (SELECT pt.Value FROM @parameterTable AS pt WHERE (pt.[Key] = '@SampleCnt'));
			SET @sampleCnt = dbo.fhsmFNTryParseAsInt(@valueStr);
			IF (@sampleCnt <= 0) OR (@sampleCnt IS NULL)
			BEGIN
				SET @sampleCnt = @DEFAULT_SAMPLE_CNT;
			END;

			SET @valueStr = (SELECT pt.Value FROM @parameterTable AS pt WHERE (pt.[Key] = '@ThresholdFactor'));
			SET @thresholdFactor = dbo.fhsmFNTryParseAsInt(@valueStr);
			IF (@thresholdFactor <= 0) OR (@thresholdFactor IS NULL)
			BEGIN
				SET @thresholdFactor = @DEFAULT_THRESHOLD_FACTOR;
			END;

			SET @valueStr = (SELECT pt.Value FROM @parameterTable AS pt WHERE (pt.[Key] = '@ThresholdTime'));
			SET @thresholdTime = dbo.fhsmFNTryParseAsInt(@valueStr);
			IF (@thresholdTime <= 0) OR (@thresholdTime IS NULL)
			BEGIN
				SET @thresholdTime = @DEFAULT_THRESHOLD_TIME;
			END;

			SET @parameter = '@SampleCnt = ' + CAST(@sampleCnt AS nvarchar) + '; @ThresholdFactor = ' + CAST(@thresholdFactor AS nvarchar) + '; @ThresholdTime = ' + CAST(@thresholdTime AS nvarchar) + '';
		END;

		--
		-- Register configuration changes
		--
		BEGIN
			WITH
			conf(Task, Name, Parameter) AS(
				SELECT
					PARSENAME('dbo.fhsmSPSchedules', 1)	AS Task
					,'Schedules'						AS Name
					,@parameter							AS Parameter
			)
			MERGE dbo.fhsmSchedules AS tgt
			USING conf AS src ON (src.[Task] = tgt.[Task] COLLATE SQL_Latin1_General_CP1_CI_AS) AND (src.[Name] = tgt.[Name] COLLATE SQL_Latin1_General_CP1_CI_AS)
			-- Not testing for NULL as a NULL parameter is not allowed
			WHEN MATCHED AND (tgt.Parameter <> src.Parameter)
				THEN UPDATE
					SET tgt.Parameter = src.Parameter
			WHEN NOT MATCHED BY TARGET
				THEN INSERT(Task, Name, Parameter)
				VALUES(src.Task, src.Name, src.Parameter);
		END;
	END;
END;
