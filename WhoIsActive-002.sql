SET NOCOUNT ON;

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
	DECLARE @productEndPos int;
	DECLARE @productStartPos int;
	DECLARE @productVersion nvarchar(128);
	DECLARE @productVersion1 int;
	DECLARE @productVersion2 int;
	DECLARE @productVersion3 int;
	DECLARE @returnValue int;
	DECLARE @schName nvarchar(128);
	DECLARE @stmt nvarchar(max);
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
		SET @version = '1.4';

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
	-- Create tables
	--
	BEGIN
		--
		-- Create dbo.fhsmWhoIsActive
		--
		IF OBJECT_ID('dbo.fhsmWhoIsActive', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmWhoIsActive', 0, 1) WITH NOWAIT;

			EXEC dbo.sp_WhoIsActive
				@format_output = 0
				,@get_transaction_info = 1
				,@get_outer_command = 1
				,@get_plans = 1
				,@return_schema = 1
				,@schema = @stmt OUTPUT;

			SET @stmt = REPLACE(@stmt, '<table_name>', QUOTENAME(DB_NAME()) + '.dbo.fhsmWhoIsActive');
			EXEC(@stmt);
		END;

		--
		-- Create index on dbo.fhsmWhoIsActive
		--
		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmWhoIsActive')) AND (i.name = 'CL_fhsmWhoIsActive_collection_time'))
		BEGIN
			CREATE CLUSTERED INDEX CL_fhsmWhoIsActive_collection_time ON dbo.fhsmWhoIsActive(collection_time ASC);
		END;

		--
		-- Register extended properties on the table dbo.fhsmWhoIsActive
		--
		BEGIN
			SET @objectName = 'dbo.fhsmWhoIsActive';
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
		-- Create fact view @pbiSchema.[Who is active]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Who is active') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Who is active') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Who is active') + '
				AS
				SELECT
					DATEDIFF(SECOND, a.collection_time, SYSDATETIME()) AS SecondsSinceLastSeen
					,a.collection_time AS CollectionTime
					,a.login_time AS LoginTime
					,DATEDIFF(MILLISECOND, a.start_time, a.collection_time) AS ElapsedTimeMS
					,a.session_id AS SessionId
					,a.sql_text AS SQLText
					,a.sql_command AS SQLCommand
					,a.login_name AS LoginName
					,a.wait_info AS WaitInfo
					,a.tran_log_writes AS TransLogWrite
					,a.CPU - a.FirstCPU AS CPU
					,a.tempdb_allocations - a.FirstTempdbAllocations AS TempdbAllocations
					,a.blocking_session_id AS BlockingSessionId
					,a.reads - a.FirstReads AS Reads
					,a.writes - a.FirstWrites AS Writes
					,a.physical_reads - a.FirstPhysicalReads AS PhysicalReads
					,a.used_memory AS UsedMemory
					,a.status AS Status
					,a.tran_start_time AS TranStartTime
					,a.open_tran_count AS OpenTranCount
					,a.percent_complete AS PercentComplete
					,a.host_name AS HostName
					,a.program_name AS ProgramName
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.database_name, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
				FROM (
					SELECT
						ROW_NUMBER() OVER(PARTITION BY wia.session_id, wia.login_time, wia.start_time ORDER BY wia.collection_time DESC) AS _Rnk_
						,wia.*
						,firstWia.CPU AS FirstCPU
						,firstWia.tempdb_allocations AS FirstTempdbAllocations
						,firstWia.reads AS FirstReads
						,firstWia.writes AS FirstWrites
						,firstWia.physical_reads AS FirstPhysicalReads
					FROM dbo.fhsmWhoIsActive AS wia
					CROSS APPLY (
						SELECT TOP (1)
							fWia.CPU
							,fWia.tempdb_allocations
							,fWia.reads
							,fWia.writes
							,fWia.physical_reads
						FROM dbo.fhsmWhoIsActive AS fWia
						WHERE
							(fWia.session_id = wia.session_id)
							AND (fWia.login_time = wia.login_time)
							AND (fWia.start_time = wia.start_time)
						ORDER BY fWia.collection_time
					) AS firstWia
					WHERE (DATEDIFF(HOUR, wia.collection_time, (SELECT MAX(wia2.collection_time) FROM dbo.fhsmWhoIsActive AS wia2)) < 24)
						AND (wia.sql_text <> ''sp_server_diagnostics'')
						AND (wia.sql_text NOT LIKE ''WAITFOR DELAY %'')
				) AS a
				WHERE (a._Rnk_ = 1);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Who is active]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Who is active');
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
		-- Create stored procedure dbo.fhsmSPWhoIsActive
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPWhoIsActive'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPWhoIsActive AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPWhoIsActive(
					@name nvarchar(128)
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @parameters nvarchar(max);
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);

					SET @parameters = dbo.fhsmFNGetTaskParameter(@thisTask, @name);

					SET @stmt = ''EXEC dbo.sp_WhoIsActive '' + @parameters;
					EXEC(@stmt);

					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPIndexUsage
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPWhoIsActive';
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
				,'dbo.fhsmWhoIsActive'
				,1
				,'collection_time'
				,0
				,7
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
				1
				,'Who is active'
				,PARSENAME('dbo.fhsmSPWhoIsActive', 1)
				,60
				,CAST('1900-1-1T00:00:00.0000' AS datetime2(0))
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))
				,1, 1, 1, 1, 1, 1, 1
				,'@format_output = 0, @get_transaction_info = 1, @get_outer_command = 1, @get_plans = 1, @destination_table = ''' + QUOTENAME(DB_NAME()) + '.dbo.fhsmWhoIsActive'''
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
			,SrcColumn1
			,OutputColumn1
		) AS (
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmWhoIsActive' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[collection_time]' AS SrcDateColumn
				,'src.[database_name]'
				,'Database'
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
				,tgt.OutputColumn1 = src.OutputColumn1
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(
				DimensionName, DimensionKey
				,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
				,SrcColumn1
				,OutputColumn1
			)
			VALUES(
				src.DimensionName, src.DimensionKey
				,src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn
				,src.SrcColumn1
				,src.OutputColumn1
			);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmWhoIsActive';
	END;
END;
