SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableQueryStatistics bit;

	SET @enableQueryStatistics = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing QueryStatistics', 0, 1) WITH NOWAIT;
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
		SET @version = '2.1';

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
		DECLARE @maxStatementLineLength int;

		SET @maxStatementLength = 1024;
		SET @maxStatementLineLength = 140;
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
		-- Create table dbo.fhsmQueryStatement if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmQueryStatement', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmQueryStatement', 0, 1) WITH NOWAIT;

			SET @stmt = '
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
					,CONSTRAINT PK_fhsmQueryStatement PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);

				CREATE NONCLUSTERED INDEX NC_fhsmQueryStatement_TimestampUTC ON dbo.fhsmQueryStatement(TimestampUTC)' + @tableCompressionStmt + ';
				CREATE NONCLUSTERED INDEX NC_fhsmQueryStatement_Timestamp ON dbo.fhsmQueryStatement(Timestamp)' + @tableCompressionStmt + ';
				CREATE NONCLUSTERED INDEX NC_fhsmQueryStatement_ObjectName_CounterName_InstanceName ON dbo.fhsmQueryStatement(DatabaseName, QueryHash)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
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

			SET @stmt = '
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
				);

				CREATE CLUSTERED INDEX CL_fhsmQueryStatistics_TimestampUTC ON dbo.fhsmQueryStatistics(TimestampUTC)' + @tableCompressionStmt + ';
				ALTER TABLE dbo.fhsmQueryStatistics ADD CONSTRAINT NCPK_fhsmQueryStatistics PRIMARY KEY NONCLUSTERED(Id)' + @tableCompressionStmt + ';
				CREATE NONCLUSTERED INDEX NC_fhsmQueryStatistics_Timestamp ON dbo.fhsmQueryStatistics(Timestamp)' + @tableCompressionStmt + ';
				CREATE NONCLUSTERED INDEX NC_fhsmQueryStatistics_DatabaseName_QueryHash ON dbo.fhsmQueryStatistics(DatabaseName, QueryHash)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
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
		-- Create table dbo.fhsmQueryStatisticsReport if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmQueryStatisticsReport', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmQueryStatisticsReport', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmQueryStatisticsReport(
					Id int identity(1,1) NOT NULL
					,ExecutionCount bigint NULL
					,WorkerTimeMS bigint NULL
					,PhysicalReads bigint NULL
					,LogicalWrites bigint NULL
					,LogicalReads bigint NULL
					,ClrTimeMS bigint NULL
					,ElapsedTimeMS bigint NULL
					,Rows bigint NULL
					,Spills bigint NULL
					,TimestampUTC datetime NOT NULL
					,Timestamp datetime NOT NULL
					,DatabaseName nvarchar(128) NULL
					,QueryHash binary(8) NOT NULL
					,Date date NOT NULL
					,TimeKey int NOT NULL
					,DatabaseKey bigint NOT NULL
					,QueryStatisticKey bigint NOT NULL
					,CONSTRAINT NCPK_fhsmQueryStatisticsReport PRIMARY KEY NONCLUSTERED(Id)' + @tableCompressionStmt + '
				);

				CREATE CLUSTERED INDEX CL_fhsmQueryStatisticsReport ON dbo.fhsmQueryStatisticsReport(TimestampUTC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmQueryStatisticsReport
		--
		BEGIN
			SET @objectName = 'dbo.fhsmQueryStatisticsReport';
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

			SET @stmt = '
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
					,_Rnk_ int NOT NULL
				);

				CREATE CLUSTERED INDEX CL_fhsmQueryStatisticsTemp ON dbo.fhsmQueryStatisticsTemp(_Rnk_, QueryHash)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
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

		--
		-- Create table dbo.fhsmQueryStatisticsReportTemp if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmQueryStatisticsReportTemp', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmQueryStatisticsReportTemp', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmQueryStatisticsReportTemp(
					DatabaseName nvarchar(128) NULL,
					QueryHash binary(8) NOT NULL,
					PlanHandle varbinary(64) NOT NULL,
					CreationTime datetime NULL,
					TimestampUTC datetime NOT NULL,
					Timestamp datetime NOT NULL,
					LastSQLServiceRestart datetime NULL,
					ExecutionCount bigint NOT NULL,
					TotalWorkerTimeMS bigint NOT NULL,
					TotalPhysicalReads bigint NOT NULL,
					TotalLogicalWrites bigint NOT NULL,
					TotalLogicalReads bigint NOT NULL,
					TotalClrTimeMS bigint NOT NULL,
					TotalElapsedTimeMS bigint NOT NULL,
					TotalRows bigint NULL,
					TotalSpills bigint NULL
				);

				CREATE CLUSTERED INDEX CL_fhsmQueryStatisticsReportTemp ON dbo.fhsmQueryStatisticsReportTemp(TimestampUTC, DatabaseName, QueryHash, PlanHandle, CreationTime)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmQueryStatisticsReportTemp
		--
		BEGIN
			SET @objectName = 'dbo.fhsmQueryStatisticsReportTemp';
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
					,(dbo.fhsmSplitLines(
						(CASE
							WHEN LEN(qs.Statement) > ' + CAST(@maxStatementLength AS nvarchar) + ' THEN LEFT(qs.Statement, ' + CAST(@maxStatementLength AS nvarchar) + ') + CHAR(10) + ''...Statement truncated''
							ELSE qs.Statement
						END),
						' + CAST(@maxStatementLineLength AS nvarchar) + '
					)) AS Statement
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
					qsr.ExecutionCount
					,qsr.WorkerTimeMS
					,qsr.PhysicalReads
					,qsr.LogicalWrites
					,qsr.LogicalReads
					,qsr.ClrTimeMS
					,qsr.ElapsedTimeMS
					,qsr.Rows
					,qsr.Spills
					,qsr.Date
					,qsr.TimeKey
					,qsr.DatabaseKey
					,qsr.QueryStatisticKey
				FROM dbo.fhsmQueryStatisticsReport AS qsr;
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
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @numberOfRows int;
					DECLARE @numberOfRowsStr nvarchar(128);
					DECLARE @parameters nvarchar(max);
					DECLARE @parametersTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);
					DECLARE @totalRowsStmt nvarchar(max);
					DECLARE @totalSpillsStmt nvarchar(max);

					SET @thisTask = OBJECT_NAME(@@PROCID);
					SET @version = ''' + @version + ''';

					--
					-- Get the parameters for the command
					--
					BEGIN
						SET @parameters = dbo.fhsmFNGetTaskParameter(@thisTask, @name);

						INSERT INTO @parametersTable([Key], Value)
						SELECT
							(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 1)) AS [Key]
							,(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 2)) AS Value
						FROM dbo.fhsmFNSplitString(@parameters, '';'') AS p;

						SET @numberOfRowsStr = (SELECT pt.Value FROM @parametersTable AS pt WHERE (pt.[Key] = ''@NumberOfRows''));
						SET @numberOfRows = dbo.fhsmFNTryParseAsInt(@numberOfRowsStr);
					END;

					--
					-- Collect data
					--
					BEGIN
						SELECT
							@now = SYSDATETIME()
							,@nowUTC = SYSUTCDATETIME();

						--
						-- Test if total_rows exists on dm_exec_query_stats
						--
						BEGIN
							IF EXISTS(
								SELECT *
								FROM master.sys.system_columns AS sc
								INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
								WHERE (so.name = ''dm_exec_query_stats'') AND (sc.name = ''total_rows'')
							)
							BEGIN
								SET @totalRowsStmt = ''deqs.total_rows'';
							END
							ELSE BEGIN
								SET @totalRowsStmt = ''NULL'';
							END;
						END;

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
							DECLARE @curUTC datetime;
							DECLARE @prevUTC datetime;

							--
							-- Collect DMV data
							--
							BEGIN
								TRUNCATE TABLE dbo.fhsmQueryStatisticsTemp;

								INSERT INTO dbo.fhsmQueryStatisticsTemp
								SELECT '' + CASE WHEN @numberOfRows > 0 THEN ''TOP ('' + CAST(@numberOfRows AS nvarchar) + '')'' ELSE '''' END + ''
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
									,'' + @totalRowsStmt + '' AS TotalRows
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
									,ROW_NUMBER() OVER(PARTITION BY dest.dbid, deqs.query_hash ORDER BY deqs.last_execution_time DESC, deqs.creation_time DESC) AS _Rnk_
								FROM sys.dm_exec_query_stats AS deqs WITH (NOLOCK)
								OUTER APPLY sys.dm_exec_sql_text(deqs.sql_handle) AS dest
								'' + CASE WHEN @numberOfRows > 0 THEN ''ORDER BY TotalLogicalReads DESC'' ELSE '''' END + '';
							END;
						'';
						SET @stmt += ''
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
						'';
						SET @stmt += ''
							--
							-- Insert records into fhsmQueryStatisticsReport
							--
							BEGIN
								SET @curUTC = (SELECT TOP (1) qs.TimestampUTC FROM dbo.fhsmQueryStatistics AS qs ORDER BY qs.TimestampUTC DESC);
								SET @prevUTC = (SELECT TOP (1) qs.TimestampUTC FROM dbo.fhsmQueryStatistics AS qs WHERE (qs.TimestampUTC < @curUTC) ORDER BY qs.TimestampUTC DESC);

								--
								-- Delete if already processed
								--
								BEGIN
									DELETE qsr
									FROM dbo.fhsmQueryStatisticsReport AS qsr WHERE (qsr.TimestampUTC = @curUTC);
								END;

								--
								-- Load base data
								--
								BEGIN
									TRUNCATE TABLE dbo.fhsmQueryStatisticsReportTemp;

									WITH
									pairedDates AS (
										SELECT
											@curUTC AS curTimestampUTC
											,@prevUTC AS prevTimestampUTC
									)
									,summarizedQS AS (
										SELECT
											qs.DatabaseName
											,qs.QueryHash
											,qs.PlanHandle
											,qs.CreationTime
											,qs.TimestampUTC
											,qs.Timestamp
											,qs.LastSQLServiceRestart
											,SUM(qs.ExecutionCount) AS ExecutionCount
											,SUM(qs.TotalWorkerTimeMS) AS TotalWorkerTimeMS
											,SUM(qs.TotalPhysicalReads) AS TotalPhysicalReads
											,SUM(qs.TotalLogicalWrites) AS TotalLogicalWrites
											,SUM(qs.TotalLogicalReads) AS TotalLogicalReads
											,SUM(qs.TotalClrTimeMS) AS TotalClrTimeMS
											,SUM(qs.TotalElapsedTimeMS) AS TotalElapsedTimeMS
											,SUM(qs.TotalRows) AS TotalRows
											,SUM(qs.TotalSpills) AS TotalSpills
										FROM dbo.fhsmQueryStatistics AS qs
										WHERE (qs.TimestampUTC IN (@curUTC, @prevUTC))
										GROUP BY
											qs.DatabaseName
											,qs.QueryHash
											,qs.PlanHandle
											,qs.CreationTime
											,qs.TimestampUTC
											,qs.Timestamp
											,qs.LastSQLServiceRestart
									)
									INSERT INTO dbo.fhsmQueryStatisticsReportTemp(
											DatabaseName, QueryHash, PlanHandle, CreationTime, TimestampUTC, Timestamp, LastSQLServiceRestart
											,ExecutionCount, TotalWorkerTimeMS, TotalPhysicalReads, TotalLogicalWrites, TotalLogicalReads, TotalClrTimeMS, TotalElapsedTimeMS, TotalRows, TotalSpills
									)
									SELECT
										qs.DatabaseName, qs.QueryHash, qs.PlanHandle, qs.CreationTime, qs.TimestampUTC, qs.Timestamp, qs.LastSQLServiceRestart
										,qs.ExecutionCount, qs.TotalWorkerTimeMS, qs.TotalPhysicalReads, qs.TotalLogicalWrites, qs.TotalLogicalReads, qs.TotalClrTimeMS, qs.TotalElapsedTimeMS, qs.TotalRows, qs.TotalSpills
									FROM summarizedQS AS qs
								END;

								--
								-- Process delta
								--
								BEGIN
									INSERT INTO dbo.fhsmQueryStatisticsReport(
										ExecutionCount, WorkerTimeMS, PhysicalReads, LogicalWrites, LogicalReads, ClrTimeMS, ElapsedTimeMS, Rows, Spills
										,TimestampUTC, Timestamp, DatabaseName, QueryHash
										,Date, TimeKey, DatabaseKey, QueryStatisticKey
									)
									SELECT
										 SUM(a.ExecutionCount) AS ExecutionCount
										,SUM(a.WorkerTimeMS) AS WorkerTimeMS
										,SUM(a.PhysicalReads) AS PhysicalReads
										,SUM(a.LogicalWrites) AS LogicalWrites
										,SUM(a.LogicalReads) AS LogicalReads
										,SUM(a.ClrTimeMS) AS ClrTimeMS
										,SUM(a.ElapsedTimeMS) AS ElapsedTimeMS
										,SUM(a.Rows) AS Rows
										,SUM(a.Spills) AS Spills
										,a.TimestampUTC
										,a.Timestamp
										,a.DatabaseName
										,a.QueryHash
										,CAST(a.Timestamp AS date) AS Date
										,(DATEPART(HOUR, a.Timestamp) * 60 * 60) + (DATEPART(MINUTE, a.Timestamp) * 60) + (DATEPART(SECOND, a.Timestamp)) AS TimeKey
										,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
										,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.DatabaseName, CONVERT(nvarchar(18), a.QueryHash, 1), DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS QueryStatisticKey
									FROM (
										SELECT
											CASE
												WHEN (DATEDIFF(HOUR, prevQS.TimestampUTC, curQS.TimestampUTC) >= 12) THEN NULL															-- Ignore data if distance between current and previous is more than 12 hours
																																														-- Either it is the first data set for this CreationTime, or the counters had an overflow, or the server har been restarted
												WHEN (prevQS.ExecutionCount IS NULL) OR (prevQS.ExecutionCount > curQS.ExecutionCount) OR (prevQS.LastSQLServiceRestart <> curQS.LastSQLServiceRestart) THEN curQS.ExecutionCount
												ELSE curQS.ExecutionCount - prevQS.ExecutionCount																						-- Difference
											END AS ExecutionCount
											,CASE
												WHEN (DATEDIFF(HOUR, prevQS.TimestampUTC, curQS.TimestampUTC) >= 12) THEN NULL
												WHEN (prevQS.TotalWorkerTimeMS IS NULL) OR (prevQS.TotalWorkerTimeMS > curQS.TotalWorkerTimeMS) OR (prevQS.LastSQLServiceRestart <> curQS.LastSQLServiceRestart) THEN curQS.TotalWorkerTimeMS
												ELSE curQS.TotalWorkerTimeMS - prevQS.TotalWorkerTimeMS
											END AS WorkerTimeMS
											,CASE
												WHEN (DATEDIFF(HOUR, prevQS.TimestampUTC, curQS.TimestampUTC) >= 12) THEN NULL
												WHEN (prevQS.TotalPhysicalReads IS NULL) OR (prevQS.TotalPhysicalReads > curQS.TotalPhysicalReads) OR (prevQS.LastSQLServiceRestart <> curQS.LastSQLServiceRestart) THEN curQS.TotalPhysicalReads
												ELSE curQS.TotalPhysicalReads - prevQS.TotalPhysicalReads
											END AS PhysicalReads
											,CASE
												WHEN (DATEDIFF(HOUR, prevQS.TimestampUTC, curQS.TimestampUTC) >= 12) THEN NULL
												WHEN (prevQS.TotalLogicalWrites IS NULL) OR (prevQS.TotalLogicalWrites > curQS.TotalLogicalWrites) OR (prevQS.LastSQLServiceRestart <> curQS.LastSQLServiceRestart) THEN curQS.TotalLogicalWrites
												ELSE curQS.TotalLogicalWrites - prevQS.TotalLogicalWrites
											END AS LogicalWrites
											,CASE
												WHEN (DATEDIFF(HOUR, prevQS.TimestampUTC, curQS.TimestampUTC) >= 12) THEN NULL
												WHEN (prevQS.TotalLogicalReads IS NULL) OR (prevQS.TotalLogicalReads > curQS.TotalLogicalReads) OR (prevQS.LastSQLServiceRestart <> curQS.LastSQLServiceRestart) THEN curQS.TotalLogicalReads
												ELSE curQS.TotalLogicalReads - prevQS.TotalLogicalReads
											END AS LogicalReads
											,CASE
												WHEN (DATEDIFF(HOUR, prevQS.TimestampUTC, curQS.TimestampUTC) >= 12) THEN NULL
												WHEN (prevQS.TotalClrTimeMS IS NULL) OR (prevQS.TotalClrTimeMS > curQS.TotalClrTimeMS) OR (prevQS.LastSQLServiceRestart <> curQS.LastSQLServiceRestart) THEN curQS.TotalClrTimeMS
												ELSE curQS.TotalClrTimeMS - prevQS.TotalClrTimeMS
											END AS ClrTimeMS
											,CASE
												WHEN (DATEDIFF(HOUR, prevQS.TimestampUTC, curQS.TimestampUTC) >= 12) THEN NULL
												WHEN (prevQS.TotalElapsedTimeMS IS NULL) OR (prevQS.TotalElapsedTimeMS > curQS.TotalElapsedTimeMS) OR (prevQS.LastSQLServiceRestart <> curQS.LastSQLServiceRestart) THEN curQS.TotalElapsedTimeMS
												ELSE curQS.TotalElapsedTimeMS - prevQS.TotalElapsedTimeMS
											END AS ElapsedTimeMS
											,CASE
												WHEN (DATEDIFF(HOUR, prevQS.TimestampUTC, curQS.TimestampUTC) >= 12) THEN NULL
												WHEN (prevQS.TotalRows IS NULL) OR (prevQS.TotalRows > curQS.TotalRows) OR (prevQS.LastSQLServiceRestart <> curQS.LastSQLServiceRestart) THEN curQS.TotalRows
												ELSE curQS.TotalRows - prevQS.TotalRows
											END AS Rows
											,CASE
												WHEN (DATEDIFF(HOUR, prevQS.TimestampUTC, curQS.TimestampUTC) >= 12) THEN NULL
												WHEN (prevQS.TotalSpills IS NULL) OR (prevQS.TotalSpills > curQS.TotalSpills) OR (prevQS.LastSQLServiceRestart <> curQS.LastSQLServiceRestart) THEN curQS.TotalSpills
												ELSE curQS.TotalSpills - prevQS.TotalSpills
											END AS Spills
											,curQS.TimestampUTC
											,curQS.Timestamp
											,curQS.DatabaseName
											,curQS.QueryHash
										FROM dbo.fhsmQueryStatisticsReportTemp AS curQS
										LEFT OUTER JOIN dbo.fhsmQueryStatisticsReportTemp AS prevQS ON (prevQS.TimestampUTC = @prevUTC)
											AND (prevQS.DatabaseName = curQS.DatabaseName)
											AND (prevQS.QueryHash = curQS.QueryHash)
											AND (prevQS.PlanHandle = curQS.PlanHandle)
											AND (prevQS.CreationTime = curQS.CreationTime)
										WHERE (curQS.TimestampUTC = @curUTC)
									) AS a
									WHERE
										(a.ExecutionCount <> 0)
										OR (a.WorkerTimeMS <> 0)
										OR (a.PhysicalReads <> 0)
										OR (a.LogicalWrites <> 0)
										OR (a.LogicalReads <> 0)
										OR (a.ClrTimeMS <> 0)
										OR (a.ElapsedTimeMS <> 0)
										OR (a.Rows <> 0)
										OR (a.Spills <> 0)
									GROUP BY
										a.TimestampUTC
										,a.Timestamp
										,a.DatabaseName
										,a.QueryHash;
								END;
							END;

							--
							-- Delete all records except _Rnk_ = 1 AND QueryHash <> 0x0
							--
							BEGIN
								DELETE t
								FROM dbo.fhsmQueryStatisticsTemp AS t
								WHERE NOT ((t._Rnk_ = 1) AND (t.QueryHash <> 0x0000000000000000));
							END;

							--
							-- Insert records into QueryStatement
							--
							BEGIN
								MERGE dbo.fhsmQueryStatement AS tgt
								USING (
									SELECT
										 t.DatabaseName
										,t.QueryHash
										,t.PlanHandle
										,t.CreationTime
										,t.LastExecutionTime
										,t.Statement
										,deqp.encrypted AS Encrypted
										,deqp.query_plan AS QueryPlan
									FROM dbo.fhsmQueryStatisticsTemp AS t
									CROSS APPLY sys.dm_exec_query_plan(t.PlanHandle) AS deqp
									WHERE (deqp.encrypted = 0)
								) AS src
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
						'';
						SET @stmt += ''
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
		retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter) AS(
			SELECT
				1
				,'dbo.fhsmQueryStatement'
				,1
				,'TimestampUTC'
				,1
				,4
				,NULL

			UNION ALL

			SELECT
				1
				,'dbo.fhsmQueryStatistics'
				,1
				,'TimestampUTC'
				,1
				,30
				,NULL

			UNION ALL

			SELECT
				1
				,'dbo.fhsmQueryStatisticsReport'
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
				@enableQueryStatistics
				,'Query statistics'
				,PARSENAME('dbo.fhsmSPQueryStatistics', 1)
				,15 * 60
				,CAST('1900-1-1T00:00:00.0000' AS datetime2(0))
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))
				,1, 1, 1, 1, 1, 1, 1
				,'@NumberOfRows=1000'
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
