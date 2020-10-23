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
		SET @version = '1.1';
	END;

	--
	-- Create tables
	--
	BEGIN
		--
		-- Create table dbo.fhsmQueryStatement if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmQueryStatement', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmQueryStatement', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmQueryStatement(
				Id int identity(1,1) NOT NULL
				,DatabaseName nvarchar(128) NULL
				,QueryHash binary(8) NULL
				--,PlanHandle varbinary(64) NOT NULL
				,CreationTime datetime NOT NULL
				,LastExecutionTime datetime NOT NULL
				,Statement nvarchar(max) NULL
				,Encrypted bit NULL
				,QueryPlan xml NULL
				,TimestampUTC datetime NOT NULL
				,Timestamp datetime NOT NULL
				,CONSTRAINT PK_fhsmQueryStatement PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmQueryStatement_TimestampUTC ON dbo.fhsmQueryStatement(TimestampUTC);
			CREATE NONCLUSTERED INDEX NC_fhsmQueryStatement_Timestamp ON dbo.fhsmQueryStatement(Timestamp);
			CREATE NONCLUSTERED INDEX NC_fhsmQueryStatement_ObjectName_CounterName_InstanceName ON dbo.fhsmQueryStatement(DatabaseName, QueryHash);
		END;

		--
		-- Register extended properties on the table dbo.fhsmQueryStatement
		--
		BEGIN
			SET @objectName = 'dbo.fhsmQueryStatement';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create table dbo.fhsmQueryStatistics if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmQueryStatistics', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmQueryStatistics', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmQueryStatistics(
				Id int identity(1,1) NOT NULL
				,DatabaseName nvarchar(128) NULL
				,QueryHash binary(8) NULL
				,PlanHandle varbinary(64) NOT NULL
				,CreationTime datetime NOT NULL
				,LastExecutionTime datetime NOT NULL
				,ExecutionCount bigint NOT NULL
				,TotalWorkerTimeMS bigint NOT NULL
				,TotalPhysicalReads bigint NOT NULL
				,TotalLogicalWrites bigint NOT NULL
				,TotalLogicalReads bigint NOT NULL
				,TotalClrTimeMS bigint NOT NULL
				,TotalElapsedTimeMS bigint NOT NULL
				,TotalRows bigint NULL
				,TotalSpills bigint NULL
				,LastSQLServiceRestart datetime NOT NULL
				,TimestampUTC datetime NOT NULL
				,Timestamp datetime NOT NULL
				,CONSTRAINT PK_fhsmQueryStatistics PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmQueryStatistics_TimestampUTC ON dbo.fhsmQueryStatistics(TimestampUTC);
			CREATE NONCLUSTERED INDEX NC_fhsmQueryStatistics_Timestamp ON dbo.fhsmQueryStatistics(Timestamp);
			CREATE NONCLUSTERED INDEX NC_fhsmQueryStatistics_DatabaseName_QueryHash ON dbo.fhsmQueryStatistics(DatabaseName, QueryHash);
		END;

		--
		-- Register extended properties on the table dbo.fhsmQueryStatistics
		--
		BEGIN
			SET @objectName = 'dbo.fhsmQueryStatistics';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create table dbo.fhsmQueryStatisticsTemp if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmQueryStatisticsTemp', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmQueryStatisticsTemp', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmQueryStatisticsTemp(
				DatabaseName nvarchar(128) NULL
				,QueryHash binary(8) NOT NULL
				,PlanHandle varbinary(64) NOT NULL
				,CreationTime datetime NULL
				,LastExecutionTime datetime NULL
				,ExecutionCount bigint NOT NULL
				,TotalWorkerTimeMS bigint NOT NULL
				,TotalPhysicalReads bigint NOT NULL
				,TotalLogicalWrites bigint NOT NULL
				,TotalLogicalReads bigint NOT NULL
				,TotalClrTimeMS bigint NOT NULL
				,TotalElapsedTimeMS bigint NOT NULL
				,TotalRows bigint NULL
				,TotalSpills bigint NULL
				,Statement nvarchar(max) NULL
				,Encrypted bit NULL
				,QueryPlan xml NULL
				,_Rnk_ int NOT NULL
			);
		END;

		--
		-- Register extended properties on the table dbo.fhsmQueryStatisticsTemp
		--
		BEGIN
			SET @objectName = 'dbo.fhsmQueryStatisticsTemp';
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
		-- Create fact view @pbiSchema.[Query statements]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Query statements') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Query statements') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Query statements') + '
				AS
				SELECT
					CONVERT(nvarchar(18), qs.QueryHash, 1) AS [Query hash]
					,qs.CreationTime
					,qs.LastExecutionTime
					,qs.Statement
					,qs.Encrypted
					,CAST(qs.Timestamp AS date) AS Date
					,(DATEPART(HOUR, qs.Timestamp) * 60 * 60) + (DATEPART(MINUTE, qs.Timestamp) * 60) + (DATEPART(SECOND, qs.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(qs.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(qs.DatabaseName, CONVERT(nvarchar(18), qs.QueryHash, 1), DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS QueryStatisticKey
				FROM dbo.fhsmQueryStatement AS qs;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Query statements]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Query statements');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Query statistics]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Query statistics') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Query statistics') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Query statistics') + '
				AS
				SELECT
					SUM(b.ExecutionCount) AS ExecutionCount
					,SUM(b.WorkerTimeMS) AS WorkerTimeMS
					,SUM(b.PhysicalReads) AS PhysicalReads
					,SUM(b.LogicalWrites) AS LogicalWrites
					,SUM(b.LogicalReads) AS LogicalReads
					,SUM(b.ClrTimeMS) AS ClrTimeMS
					,SUM(b.ElapsedTimeMS) AS ElapsedTimeMS
					,SUM(b.Rows) AS Rows
					,SUM(b.Spills) AS Spills
					,b.Date
					,b.TimeKey
					,b.DatabaseKey
					,b.QueryStatisticKey
				FROM (
			';
			SET @stmt += '
					SELECT
						CASE
							WHEN (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL																					-- Ignore very first data set - Yes we loose one data set but better than having visuals showing very high data
																																										-- Either it is the first data set for this CreationTime, or the counters had an overflow, or the server har been restarted
							WHEN (a.PreviousExecutionCount IS NULL) OR (a.PreviousExecutionCount > a.ExecutionCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.ExecutionCount
							ELSE a.ExecutionCount - a.PreviousExecutionCount																							-- Difference
						END AS ExecutionCount
						,CASE
							WHEN (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousTotalWorkerTimeMS IS NULL) OR (a.PreviousTotalWorkerTimeMS > a.TotalWorkerTimeMS) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.TotalWorkerTimeMS
							ELSE a.TotalWorkerTimeMS - a.PreviousTotalWorkerTimeMS
						END AS WorkerTimeMS
						,CASE
							WHEN (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousTotalPhysicalReads IS NULL) OR (a.PreviousTotalPhysicalReads > a.TotalPhysicalReads) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.TotalPhysicalReads
							ELSE a.TotalPhysicalReads - a.PreviousTotalPhysicalReads
						END AS PhysicalReads
						,CASE
							WHEN (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousTotalLogicalWrites IS NULL) OR (a.PreviousTotalLogicalWrites > a.TotalLogicalWrites) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.TotalLogicalWrites
							ELSE a.TotalLogicalWrites - a.PreviousTotalLogicalWrites
						END AS LogicalWrites
						,CASE
							WHEN (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousTotalLogicalReads IS NULL) OR (a.PreviousTotalLogicalReads > a.TotalLogicalReads) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.TotalLogicalReads
							ELSE a.TotalLogicalReads - a.PreviousTotalLogicalReads
						END AS LogicalReads
						,CASE
							WHEN (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousTotalClrTimeMS IS NULL) OR (a.PreviousTotalClrTimeMS > a.TotalClrTimeMS) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.TotalClrTimeMS
							ELSE a.TotalClrTimeMS - a.PreviousTotalClrTimeMS
						END AS ClrTimeMS
						,CASE
							WHEN (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousTotalElapsedTimeMS IS NULL) OR (a.PreviousTotalElapsedTimeMS > a.TotalElapsedTimeMS) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.TotalElapsedTimeMS
							ELSE a.TotalElapsedTimeMS - a.PreviousTotalElapsedTimeMS
						END AS ElapsedTimeMS
						,CASE
							WHEN (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousTotalRows IS NULL) OR (a.PreviousTotalRows > a.TotalRows) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.TotalRows
							ELSE a.TotalRows - a.PreviousTotalRows
						END AS Rows
						,CASE
							WHEN (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousTotalSpills IS NULL) OR (a.PreviousTotalSpills > a.TotalSpills) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.TotalSpills
							ELSE a.TotalSpills - a.PreviousTotalSpills
						END AS Spills
						,a.Date
						,a.TimeKey
						,a.DatabaseKey
						,a.QueryStatisticKey
			';
			SET @stmt += '
					FROM (
						SELECT
							qs.ExecutionCount
							,LAG(qs.ExecutionCount) OVER(PARTITION BY qs.DatabaseName, qs.QueryHash, qs.PlanHandle, qs.CreationTime ORDER BY qs.TimestampUTC) AS PreviousExecutionCount
							,qs.TotalWorkerTimeMS
							,LAG(qs.TotalWorkerTimeMS) OVER(PARTITION BY qs.DatabaseName, qs.QueryHash, qs.PlanHandle, qs.CreationTime ORDER BY qs.TimestampUTC) AS PreviousTotalWorkerTimeMS
							,qs.TotalPhysicalReads
							,LAG(qs.TotalPhysicalReads) OVER(PARTITION BY qs.DatabaseName, qs.QueryHash, qs.PlanHandle, qs.CreationTime ORDER BY qs.TimestampUTC) AS PreviousTotalPhysicalReads
							,qs.TotalLogicalWrites
							,LAG(qs.TotalLogicalWrites) OVER(PARTITION BY qs.DatabaseName, qs.QueryHash, qs.PlanHandle, qs.CreationTime ORDER BY qs.TimestampUTC) AS PreviousTotalLogicalWrites
							,qs.TotalLogicalReads
							,LAG(qs.TotalLogicalReads) OVER(PARTITION BY qs.DatabaseName, qs.QueryHash, qs.PlanHandle, qs.CreationTime ORDER BY qs.TimestampUTC) AS PreviousTotalLogicalReads
							,qs.TotalClrTimeMS
							,LAG(qs.TotalClrTimeMS) OVER(PARTITION BY qs.DatabaseName, qs.QueryHash, qs.PlanHandle, qs.CreationTime ORDER BY qs.TimestampUTC) AS PreviousTotalClrTimeMS
							,qs.TotalElapsedTimeMS
							,LAG(qs.TotalElapsedTimeMS) OVER(PARTITION BY qs.DatabaseName, qs.QueryHash, qs.PlanHandle, qs.CreationTime ORDER BY qs.TimestampUTC) AS PreviousTotalElapsedTimeMS
							,qs.TotalRows
							,LAG(qs.TotalRows) OVER(PARTITION BY qs.DatabaseName, qs.QueryHash, qs.PlanHandle, qs.CreationTime ORDER BY qs.TimestampUTC) AS PreviousTotalRows
							,qs.TotalSpills
							,LAG(qs.TotalSpills) OVER(PARTITION BY qs.DatabaseName, qs.QueryHash, qs.PlanHandle, qs.CreationTime ORDER BY qs.TimestampUTC) AS PreviousTotalSpills
							,qs.LastSQLServiceRestart
							,LAG(qs.LastSQLServiceRestart) OVER(PARTITION BY qs.DatabaseName, qs.QueryHash, qs.PlanHandle ORDER BY qs.TimestampUTC) AS PreviousLastSQLServiceRestart	-- qs.CreationTime IS NOT a part of the PARTITION
							,CAST(qs.Timestamp AS date) AS Date
							,(DATEPART(HOUR, qs.Timestamp) * 60 * 60) + (DATEPART(MINUTE, qs.Timestamp) * 60) + (DATEPART(SECOND, qs.Timestamp)) AS TimeKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(qs.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(qs.DatabaseName, CONVERT(nvarchar(18), qs.QueryHash, 1), DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS QueryStatisticKey
						FROM dbo.fhsmQueryStatistics AS qs
					) AS a
				) AS b
				WHERE
					(b.ExecutionCount <> 0)
					OR (b.WorkerTimeMS <> 0)
					OR (b.PhysicalReads <> 0)
					OR (b.LogicalWrites <> 0)
					OR (b.LogicalReads <> 0)
					OR (b.ClrTimeMS <> 0)
					OR (b.ElapsedTimeMS <> 0)
					OR (b.Rows <> 0)
					OR (b.Spills <> 0)
				GROUP BY
					b.Date
					,b.TimeKey
					,b.DatabaseKey
					,b.QueryStatisticKey;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Query statistics]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Query statistics');
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
		-- Create stored procedure dbo.fhsmSPQueryStatistics
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPQueryStatistics'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPQueryStatistics AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPQueryStatistics (
					@name nvarchar(128)
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameters nvarchar(max);
					DECLARE @stmt nvarchar(max);
					DECLARE @totalSpillsStmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);

					--
					-- Get the parametrs for the command
					--
					BEGIN
						SET @parameters = dbo.fhsmFNGetTaskParameter(@thisTask, @name);
					END;

					--
					-- Collect data
					--
					BEGIN
						SET @now = SYSDATETIME();
						SET @nowUTC = SYSUTCDATETIME();

						--
						-- Test if total_spills exists on dm_exec_query_stats
						--
						BEGIN
							IF EXISTS(
								SELECT *
								FROM master.sys.system_columns AS sc
								INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
								WHERE (so.name = ''dm_exec_query_stats'') AND (sc.name = ''total_spills'')
							)
							BEGIN
								SET @totalSpillsStmt = ''deqs.total_spills'';
							END
							ELSE BEGIN
								SET @totalSpillsStmt = ''NULL'';
							END;
						END;

						SET @stmt = ''
							--
							-- Collect DMV data
							--
							BEGIN
								TRUNCATE TABLE dbo.fhsmQueryStatisticsTemp;

								INSERT INTO dbo.fhsmQueryStatisticsTemp
								SELECT
									COALESCE(DB_NAME(dest.dbid), ''''DbId:'''' + CAST(dest.dbid AS nvarchar), ''''Ad hoc / prepared'''') AS DatabaseName
									,deqs.query_hash AS QueryHash
									,deqs.plan_handle AS PlanHandle
									,deqs.creation_time AS CreationTime
									,deqs.last_execution_time AS LastExecutionTime
									,deqs.execution_count AS ExecutionCount
									,(deqs.total_worker_time / 1000.0) AS TotalWorkerTimeMS
									,deqs.total_physical_reads AS TotalPhysicalReads
									,deqs.total_logical_writes AS TotalLogicalWrites
									,deqs.total_logical_reads AS TotalLogicalReads
									,(deqs.total_clr_time / 1000.0) AS TotalClrTimeMS
									,(deqs.total_elapsed_time / 1000.0) AS TotalElapsedTimeMS
									,deqs.total_rows AS TotalRows
									,'' + @totalSpillsStmt + '' AS TotalSpills
									,CASE
										WHEN deqs.statement_start_offset > 0 THEN
											--The start of the active command is not at the beginning of the full command text
											CASE deqs.statement_end_offset
												WHEN -1 THEN
													--The end of the full command is also the end of the active statement
													SUBSTRING(dest.text, (deqs.statement_start_offset / 2) + 1, 2147483647)
												ELSE
													--The end of the active statement is not at the end of the full command
													SUBSTRING(dest.text, (deqs.statement_start_offset / 2) + 1, ((deqs.statement_end_offset - deqs.statement_start_offset) / 2) + 1)
											END
										ELSE
											--1st part of full command is running
											CASE deqs.statement_end_offset
												WHEN -1 THEN
													--The end of the full command is also the end of the active statement
													LTRIM(RTRIM(dest.text))
												ELSE
													--The end of the active statement is not at the end of the full command
													LEFT(dest.text, (deqs.statement_end_offset / 2) + 1)
											END
									END AS Statement
									,deqp.encrypted AS Encrypted
									,deqp.query_plan AS QueryPlan
									,ROW_NUMBER() OVER(PARTITION BY dest.dbid, deqs.query_hash ORDER BY deqs.last_execution_time DESC, deqs.creation_time DESC) AS _Rnk_
								FROM sys.dm_exec_query_stats AS deqs WITH (NOLOCK)
								OUTER APPLY sys.dm_exec_sql_text(deqs.sql_handle) AS dest
								OUTER APPLY sys.dm_exec_query_plan(deqs.plan_handle) AS deqp
							END;

							--
							-- Insert records into QueryStatistics
							--
							BEGIN
								INSERT INTO dbo.fhsmQueryStatistics(
									DatabaseName, QueryHash, PlanHandle, CreationTime, LastExecutionTime
									,ExecutionCount, TotalWorkerTimeMS, TotalPhysicalReads, TotalLogicalWrites, TotalLogicalReads, TotalClrTimeMS, TotalElapsedTimeMS, TotalRows, TotalSpills
									,LastSQLServiceRestart
									,TimestampUTC, Timestamp)
								SELECT
									src.DatabaseName, src.QueryHash, src.PlanHandle, src.CreationTime, src.LastExecutionTime
									,src.ExecutionCount, src.TotalWorkerTimeMS, src.TotalPhysicalReads, src.TotalLogicalWrites, src.TotalLogicalReads, src.TotalClrTimeMS, src.TotalElapsedTimeMS, src.TotalRows, src.TotalSpills
									,(SELECT d.create_date FROM sys.databases AS d WITH (NOLOCK) WHERE (d.name = ''''tempdb'''')) AS LastSQLServiceRestart
									,@nowUTC, @now
								FROM dbo.fhsmQueryStatisticsTemp AS src;
							END;

							--
							-- Insert records into QueryStatement
							--
							BEGIN
								MERGE dbo.fhsmQueryStatement AS tgt
								USING (SELECT * FROM dbo.fhsmQueryStatisticsTemp AS t WHERE (t.QueryHash <> 0x0000000000000000) AND (t.Encrypted = 0) AND (t._Rnk_ = 1)) AS src
								ON (src.DatabaseName = tgt.DatabaseName) AND (src.QueryHash = tgt.QueryHash)
								WHEN MATCHED
									THEN UPDATE SET
										tgt.LastExecutionTime = src.LastExecutionTime
										,tgt.Statement = src.Statement
										,tgt.Encrypted = src.Encrypted
										,tgt.QueryPlan = src.QueryPlan
								WHEN NOT MATCHED BY TARGET
									THEN INSERT(DatabaseName, QueryHash, CreationTime, LastExecutionTime, Statement, Encrypted, QueryPlan, TimestampUTC, Timestamp)
									VALUES(src.DatabaseName, src.QueryHash, src.CreationTime, src.LastExecutionTime, src.Statement, src.Encrypted, src.QueryPlan, @nowUTC, @now)
								;
							END;

							--
							-- Delete records from QueryStatements where no owner in QueryStatistics exists
							--
							BEGIN
								DELETE qStmt
								FROM dbo.fhsmQueryStatement AS qStmt
								WHERE NOT EXISTS (
									SELECT *
									FROM dbo.fhsmQueryStatistics AS qs
									WHERE (qs.DatabaseName = qStmt.DatabaseName) AND (qs.QueryHash = qStmt.QueryHash)
								);
							END;
						'';
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
		-- Register extended properties on the stored procedure dbo.fhsmSPQueryStatistics
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPQueryStatistics';
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
				,'dbo.fhsmQueryStatement'
				,'TimestampUTC'
				,1
				,4

			UNION ALL

			SELECT
				1
				,'dbo.fhsmQueryStatistics'
				,'TimestampUTC'
				,1
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
				1
				,'Query statistics'
				,PARSENAME('dbo.fhsmSPQueryStatistics', 1)
				,15 * 60
				,TIMEFROMPARTS(0, 0, 0, 0, 0)
				,TIMEFROMPARTS(23, 59, 59, 0, 0)
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
			,SrcColumn1, SrcColumn2
			,OutputColumn1, OutputColumn2
		) AS (
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmQueryStatistics' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL
				,'Database', NULL

			UNION ALL

			SELECT
				'Query statistic' AS DimensionName
				,'QueryStatisticKey' AS DimensionKey
				,'dbo.fhsmQueryStatistics' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'CONVERT(nvarchar(18), src.QueryHash, 1)'
				,'Database', 'Query hash'
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
				,tgt.OutputColumn1 = src.OutputColumn1
				,tgt.OutputColumn2 = src.OutputColumn2
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(
				DimensionName, DimensionKey
				,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
				,SrcColumn1, SrcColumn2
				,OutputColumn1, OutputColumn2
			)
			VALUES(
				src.DimensionName, src.DimensionKey
				,src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn
				,src.SrcColumn1, src.SrcColumn2
				,src.OutputColumn1, src.OutputColumn2
			);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmQueryStatistics';
	END;
END;
