SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableCPUUtilization bit;

	SET @enableCPUUtilization = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing CPUUtilization', 0, 1) WITH NOWAIT;
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
		-- Create table dbo.fhsmCPUUtilization and indexes if they not already exists
		--
		IF OBJECT_ID('dbo.fhsmCPUUtilization', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmCPUUtilization', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmCPUUtilization(
					Id int identity(1,1) NOT NULL
					,EventTimeUTC datetime NOT NULL
					,EventTime datetime NOT NULL
					,SQLProcessUtilization tinyint NOT NULL
					,SystemIdle tinyint NOT NULL
					,PageFaults int NOT NULL
					,TimestampUTC datetime NOT NULL
					,Timestamp datetime NOT NULL
					,CONSTRAINT PK_CPUUtilization PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmCPUUtilization')) AND (i.name = 'NC_fhsmCPUUtilization_EventTimeUTC'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmCPUUtilization_EventTimeUTC] to table dbo.fhsmCPUUtilization', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmCPUUtilization_EventTimeUTC ON dbo.fhsmCPUUtilization(EventTimeUTC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmCPUUtilization')) AND (i.name = 'NC_fhsmCPUUtilization_EventTime'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmCPUUtilization_EventTime] to table dbo.fhsmCPUUtilization', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmCPUUtilization_EventTime ON dbo.fhsmCPUUtilization(EventTime)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmCPUUtilization
		--
		BEGIN
			SET @objectName = 'dbo.fhsmCPUUtilization';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create table dbo.fhsmCPUPerDatabase and indexes if they not already exists
		-- Create table dbo.fhsmCPUPerDatabase if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmCPUPerDatabase', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmCPUPerDatabase', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmCPUPerDatabase(
					Id int identity(1,1) NOT NULL
					,DatabaseName nvarchar(128) NOT NULL
					,CPUTimeMs bigint NOT NULL
					,CPUPercent decimal(5,2) NOT NULL
					,TimestampUTC datetime NOT NULL
					,Timestamp datetime NOT NULL
					,CONSTRAINT PK_CPUPerDatabase PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmCPUPerDatabase')) AND (i.name = 'NC_fhsmCPUPerDatabase_TimestampUTC'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmCPUPerDatabase_TimestampUTC] to table dbo.fhsmCPUPerDatabase', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmCPUPerDatabase_TimestampUTC ON dbo.fhsmCPUPerDatabase(TimestampUTC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmCPUPerDatabase')) AND (i.name = 'NC_fhsmCPUPerDatabase_Timestamp'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmCPUPerDatabase_Timestamp] to table dbo.fhsmCPUPerDatabase', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmCPUPerDatabase_Timestamp ON dbo.fhsmCPUPerDatabase(Timestamp)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmCPUPerDatabase
		--
		BEGIN
			SET @objectName = 'dbo.fhsmCPUPerDatabase';
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
		-- Create fact view @pbiSchema.[CPU utilization]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('CPU utilization') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('CPU utilization') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('CPU utilization') + '
				AS
				SELECT
					cu.SQLProcessUtilization
					,cu.SystemIdle
					,100 - cu.SystemIdle - cu.SQLProcessUtilization AS OtherProcessUtilization
					,cu.PageFaults
					,cu.EventTime
					,CAST(cu.EventTime AS date) AS Date
					,(DATEPART(HOUR, cu.EventTime) * 60 * 60) + (DATEPART(MINUTE, cu.EventTime) * 60) + (DATEPART(SECOND, cu.EventTime)) AS TimeKey
				FROM dbo.fhsmCPUUtilization AS cu;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[CPU utilization]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('CPU utilization');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[CPU per database]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('CPU per database') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('CPU per database') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('CPU per database') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				WITH cpuPerDatabase AS (
					SELECT
						cpd.DatabaseName
						,cpd.CPUTimeMs
						,cpd.CPUPercent
						,cpd.Timestamp
						,ROW_NUMBER() OVER(PARTITION BY cpd.DatabaseName ORDER BY cpd.TimestampUTC) AS Idx
					FROM dbo.fhsmCPUPerDatabase AS cpd
				)
				';
			END;
			SET @stmt += '
				SELECT
					CASE
						WHEN (a.PreviousCPUTimeMs IS NULL) THEN NULL				-- Ignore 1. data set - Yes we loose one data set but better than having visuals showing very high data
						WHEN (a.PreviousCPUTimeMs > a.CPUTimeMs) THEN a.CPUTimeMs	-- Either has the counters had an overflow or the server har been restarted
						ELSE a.CPUTimeMs - a.PreviousCPUTimeMs						-- Difference
					END AS CPUTimeMs
					,a.CPUPercent
					,a.Timestamp
					,CAST(a.Timestamp AS date) AS Date
					,(DATEPART(HOUR, a.Timestamp) * 60 * 60) + (DATEPART(MINUTE, a.Timestamp) * 60) + (DATEPART(SECOND, a.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
			';
			SET @stmt += '
					FROM (
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
						SELECT
							cpd.DatabaseName
							,cpd.CPUTimeMs
							,prevCpd.CPUTimeMs AS PreviousCPUTimeMs
							,cpd.CPUPercent
							,cpd.Timestamp
						FROM cpuPerDatabase AS cpd
						LEFT OUTER JOIN cpuPerDatabase AS prevCpd ON
							(prevCpd.DatabaseName = cpd.DatabaseName)
							AND (prevCpd.Idx = cpd.Idx - 1)
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
						SELECT
							cpd.DatabaseName
							,cpd.CPUTimeMs
							,LAG(cpd.CPUTimeMs) OVER(PARTITION BY cpd.DatabaseName ORDER BY cpd.TimestampUTC) AS PreviousCPUTimeMs
							,cpd.CPUPercent
							,cpd.Timestamp
						FROM dbo.fhsmCPUPerDatabase AS cpd
				';
			END;
			SET @stmt += '
				) AS a;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[CPU per database]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('CPU per database');
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
		-- Create stored procedure dbo.fhsmSPCPUUtilization
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPCPUUtilization'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPCPUUtilization AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPCPUUtilization (
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @ms_ticks_now bigint;
					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameters nvarchar(max);
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
						SELECT @ms_ticks_now = dosi.ms_ticks FROM sys.dm_os_sys_info AS dosi WITH (NOLOCK);

						SELECT
							@now = SYSDATETIME()
							,@nowUTC = SYSUTCDATETIME();

						INSERT INTO dbo.fhsmCPUUtilization(EventTime, EventTimeUTC, SQLProcessUtilization, SystemIdle, PageFaults, TimestampUTC, Timestamp)
						SELECT c.EventTime, c.EventTimeUTC, c.SQLProcessUtilization, c.SystemIdle, c.PageFaults, @nowUTC, @now
						FROM (
							SELECT
								 dateadd(ms, - 1 * (@ms_ticks_now - b.Timestamp), @now) AS EventTime
								,dateadd(ms, - 1 * (@ms_ticks_now - b.Timestamp), @nowUTC) AS EventTimeUTC
								,b.SQLProcessUtilization
								,b.SystemIdle
								,b.PageFaults
							FROM (
								SELECT
									a.record.value(''(./Record/@id)[1]'', ''int'') AS record_id
									,a.record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]'', ''int'') AS SystemIdle
									,a.record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]'', ''int'') AS SQLProcessUtilization
									,a.record.value(''(./Record/SchedulerMonitorEvent/SystemHealth/PageFaults)[1]'', ''int'') AS PageFaults
									,a.Timestamp
								FROM (
									SELECT
										TIMESTAMP AS Timestamp
										,CAST(dorb.record AS xml) AS record
									FROM sys.dm_os_ring_buffers AS dorb WITH (NOLOCK)
									WHERE (dorb.ring_buffer_type = N''RING_BUFFER_SCHEDULER_MONITOR'') AND (dorb.record LIKE ''%<SystemHealth>%'')
								) AS a
							) AS b
						) AS c
						WHERE NOT EXISTS (
							SELECT *
							FROM dbo.fhsmCPUUtilization AS cu
							WHERE (ABS(DATEDIFF(second, cu.EventTimeUTC, c.EventTimeUTC)) < 10)
						)
						OPTION (RECOMPILE);

						WITH
						dbCPUStats AS (
							SELECT
								pa.DatabaseId
								,DB_NAME(pa.DatabaseId) AS DatabaseName
								,SUM(qs.total_worker_time / 1000) AS CPUTimeMs
							 FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
							 CROSS APPLY (
								SELECT CAST(depa.value AS int) AS DatabaseId
								FROM sys.dm_exec_plan_attributes(qs.plan_handle) AS depa
								WHERE (depa.attribute = N''dbid'')
							) AS pa
							GROUP BY pa.DatabaseId
						)
						INSERT INTO dbo.fhsmCPUPerDatabase(DatabaseName, CPUTimeMs, CPUPercent, TimestampUTC, Timestamp)
						SELECT
							dcs.DatabaseName
							,dcs.CPUTimeMs
							,CAST(dcs.CPUTimeMs * 1.0 / SUM(dcs.CPUTimeMs) OVER() * 100.0 AS decimal(5, 2)) AS CPUPercent
							,@nowUTC, @now
						FROM dbCPUStats AS dcs
						WHERE (dcs.DatabaseId <> 32767) -- ResourceDB
						OPTION (RECOMPILE);
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPCPUUtilization
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPCPUUtilization';
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
				,'dbo.fhsmCPUUtilization'
				,1
				,'EventTimeUTC'
				,1
				,30
				,NULL
		)
		MERGE dbo.fhsmRetentions AS tgt
		USING retention AS src ON (src.TableName = tgt.TableName) AND (src.Sequence = tgt.Sequence)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter)
			VALUES(src.Enabled, src.TableName, src.Sequence, src.TimeColumn, src.IsUtc, src.Days, src.Filter);

		WITH
		retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter) AS(
			SELECT
				1
				,'dbo.fhsmCPUPerDatabase'
				,1
				,'TimestampUTC'
				,1
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
	-- Register schedules
	--
	BEGIN
		WITH
		schedules(Enabled, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters) AS(
			SELECT
				@enableCPUUtilization
				,'CPU utilization'
				,PARSENAME('dbo.fhsmSPCPUUtilization', 1)
				,5 * 60
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
				,'dbo.fhsmCPUPerDatabase' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL
				,'Database', NULL, NULL
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
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmCPUPerDatabase';
	END;
END;
