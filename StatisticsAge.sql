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
		SET @version = '1.3';
	END;

	--
	-- Create tables
	--
	BEGIN
		--
		-- Create table dbo.fhsmStatisticsAge if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmStatisticsAge', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmStatisticsAge', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmStatisticsAge(
				Id int identity(1,1) NOT NULL
				,DatabaseName nvarchar(128) NOT NULL
				,SchemaName nvarchar(128) NOT NULL
				,ObjectName nvarchar(128) NOT NULL
				,IndexName nvarchar(128) NOT NULL
				,LastUpdated datetime2 NULL
				,Rows bigint NULL
				,RowsSampled bigint NULL
				,Steps int NULL
				,UnfilteredRows bigint NULL
				,ModificationCounter bigint NULL
				,PersistedSamplePercent float NULL
				,IsHypothetical bit NULL
				,TimestampUTC datetime NOT NULL
				,Timestamp datetime NOT NULL
				,CONSTRAINT PK_fhsmStatisticsAge PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmStatisticsAge_TimestampUTC ON dbo.fhsmStatisticsAge(TimestampUTC);
			CREATE NONCLUSTERED INDEX NC_fhsmStatisticsAge_Timestamp_LastUpdated ON dbo.fhsmStatisticsAge(Timestamp, LastUpdated) INCLUDE(DatabaseName, SchemaName, ObjectName, IndexName);
			CREATE NONCLUSTERED INDEX NC_fhsmStatisticsAge_DatabaseName_SchemaName_ObjectName_IndexName ON dbo.fhsmStatisticsAge(DatabaseName, SchemaName, ObjectName, IndexName);
		END;

		--
		-- Register extended properties on the table dbo.fhsmStatisticsAge
		--
		BEGIN
			SET @objectName = 'dbo.fhsmStatisticsAge';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create table dbo.fhsmStatisticsAgeIncremental if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmStatisticsAgeIncremental', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmStatisticsAgeIncremental', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmStatisticsAgeIncremental(
				Id int identity(1,1) NOT NULL
				,DatabaseName nvarchar(128) NOT NULL
				,SchemaName nvarchar(128) NOT NULL
				,ObjectName nvarchar(128) NOT NULL
				,IndexName nvarchar(128) NOT NULL
				,PartitionNumber int NOT NULL
				,LastUpdated datetime2 NULL
				,Rows bigint NULL
				,RowsSampled bigint NULL
				,Steps int NULL
				,UnfilteredRows bigint NULL
				,ModificationCounter bigint NULL
				,IsHypothetical bit NULL
				,TimestampUTC datetime NOT NULL
				,Timestamp datetime NOT NULL
				,CONSTRAINT PK_fhsmStatisticsAgeIncremental PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmStatisticsAgeIncremental_TimestampUTC ON dbo.fhsmStatisticsAgeIncremental(TimestampUTC);
			CREATE NONCLUSTERED INDEX NC_fhsmStatisticsAgeIncremental_Timestamp_LastUpdated ON dbo.fhsmStatisticsAgeIncremental(Timestamp, LastUpdated) INCLUDE(DatabaseName, SchemaName, ObjectName, IndexName);
			CREATE NONCLUSTERED INDEX NC_fhsmStatisticsAgeIncremental_DatabaseName_SchemaName_ObjectName_IndexName ON dbo.fhsmStatisticsAgeIncremental(DatabaseName, SchemaName, ObjectName, IndexName);
		END;

		--
		-- Register extended properties on the table dbo.fhsmStatisticsAgeIncremental
		--
		BEGIN
			SET @objectName = 'dbo.fhsmStatisticsAgeIncremental';
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
		-- Create fact view @pbiSchema.[Statistics age]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Statistics age') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Statistics age') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Statistics age') + '
				AS
				SELECT
					DATEDIFF(DAY, sa.LastUpdated, SYSDATETIME()) AS Age
					,sa.LastUpdated
					,sa.Rows
					,sa.RowsSampled
					,sa.Steps
					,sa.UnfilteredRows
					,sa.ModificationCounter
					,sa.PersistedSamplePercent
					,sa.IsHypothetical
					,CAST(sa.Timestamp AS date) AS Date
					,(DATEPART(HOUR, sa.Timestamp) * 60 * 60) + (DATEPART(MINUTE, sa.Timestamp) * 60) + (DATEPART(SECOND, sa.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sa.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sa.DatabaseName, sa.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sa.DatabaseName, sa.SchemaName, sa.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sa.DatabaseName, sa.SchemaName, sa.ObjectName, sa.IndexName, DEFAULT, DEFAULT) AS k) AS IndexKey
				FROM dbo.fhsmStatisticsAge AS sa
				WHERE (sa.Timestamp = (SELECT MAX(sa2.Timestamp) FROM dbo.fhsmStatisticsAge AS sa2))
					AND (sa.LastUpdated IS NOT NULL);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Statistics age]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Statistics age');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Statistics age detailed]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Statistics age detailed') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Statistics age detailed') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Statistics age detailed') + '
				AS
				SELECT
					DATEDIFF(DAY, sa.LastUpdated, sa.Timestamp) AS Age
					,sa.LastUpdated
					,sa.Rows
					,sa.RowsSampled
					,sa.Steps
					,sa.UnfilteredRows
					,sa.ModificationCounter
					,sa.PersistedSamplePercent
					,sa.Timestamp
					,CAST(sa.Timestamp AS date) AS Date
					,(DATEPART(HOUR, sa.Timestamp) * 60 * 60) + (DATEPART(MINUTE, sa.Timestamp) * 60) + (DATEPART(SECOND, sa.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sa.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sa.DatabaseName, sa.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sa.DatabaseName, sa.SchemaName, sa.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sa.DatabaseName, sa.SchemaName, sa.ObjectName, sa.IndexName, DEFAULT, DEFAULT) AS k) AS IndexKey
				FROM dbo.fhsmStatisticsAge AS sa
				WHERE (sa.LastUpdated IS NOT NULL);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Statistics age detailed]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Statistics age detailed');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Statistics age incremental]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Statistics age incremental') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Statistics age incremental') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Statistics age incremental') + '
				AS
				SELECT
					DATEDIFF(DAY, sai.LastUpdated, SYSDATETIME()) AS Age
					,sai.LastUpdated
					,sai.Rows
					,sai.RowsSampled
					,sai.Steps
					,sai.UnfilteredRows
					,sai.ModificationCounter
					,sai.IsHypothetical
					,CAST(sai.Timestamp AS date) AS Date
					,(DATEPART(HOUR, sai.Timestamp) * 60 * 60) + (DATEPART(MINUTE, sai.Timestamp) * 60) + (DATEPART(SECOND, sai.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sai.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sai.DatabaseName, sai.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sai.DatabaseName, sai.SchemaName, sai.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sai.DatabaseName, sai.SchemaName, sai.ObjectName, sai.PartitionNumber, DEFAULT, DEFAULT) AS k) AS ObjectPartitionKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sai.DatabaseName, sai.SchemaName, sai.ObjectName, sai.IndexName, DEFAULT, DEFAULT) AS k) AS IndexKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(sai.DatabaseName, sai.SchemaName, sai.ObjectName, sai.IndexName, sai.PartitionNumber, DEFAULT) AS k) AS IndexPartitionKey
				FROM dbo.fhsmStatisticsAgeIncremental AS sai
				WHERE (sai.Timestamp = (SELECT MAX(sa2.Timestamp) FROM dbo.fhsmStatisticsAge AS sa2))
					AND (sai.LastUpdated IS NOT NULL);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Statistics age incremental]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Statistics age incremental');
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
		-- Create stored procedure dbo.fhsmSPStatisticsAge
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPStatisticsAge'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPStatisticsAge AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPStatisticsAge (
					@name nvarchar(128)
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @database nvarchar(128);
					DECLARE @databases nvarchar(max);
					DECLARE @message nvarchar(max);
					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameters nvarchar(max);
					DECLARE @parametersTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
					DECLARE @replicaId uniqueidentifier;
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);

					--
					-- Get the parametrs for the command
					--
					BEGIN
						SET @parameters = dbo.fhsmFNGetTaskParameter(@thisTask, @name);

						INSERT INTO @parametersTable([Key], Value)
						SELECT
							(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 1)) AS [Key]
							,(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 2)) AS Value
						FROM dbo.fhsmFNSplitString(@parameters, '';'') AS p;

						SET @databases = (SELECT pt.Value FROM @parametersTable AS pt WHERE (pt.[Key] = ''@Databases''));

						--
						-- Trim @databases if Ola Hallengren style has been chosen
						--
						BEGIN
							SET @databases = LTRIM(RTRIM(@databases));
							WHILE (LEFT(@databases, 1) = '''''''') AND (LEFT(@databases, 1) = '''''''')
							BEGIN
								SET @databases = SUBSTRING(@databases, 2, LEN(@databases) - 2);
							END;
						END;
					END;

					--
					-- Get the list of databases to process
					--
					BEGIN
						SELECT d.DatabaseName, d.[Order]
						INTO #dbList
						FROM dbo.fhsmFNParseDatabasesStr(@databases) AS d;
					END;

					--
					-- Collect data
					--
					BEGIN
						--
						-- Test if persisted_sample_percent exists on dm_db_stats_properties
						--
						BEGIN
							DECLARE @persistedSamplePercentStmt nvarchar(max);

							IF EXISTS(
								SELECT *
								FROM master.sys.system_columns AS sc
								INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
								WHERE (so.name = ''dm_db_stats_properties'') AND (sc.name = ''persisted_sample_percent'')
							)
							BEGIN
								SET @persistedSamplePercentStmt = ''ddsp.persisted_sample_percent'';
							END
							ELSE BEGIN
								SET @persistedSamplePercentStmt = ''NULL'';
							END;
						END;


						SET @now = SYSDATETIME();
						SET @nowUTC = SYSUTCDATETIME();

						DECLARE dCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
						SELECT dl.DatabaseName, d.replica_id
						FROM #dbList AS dl
						INNER JOIN sys.databases AS d ON (d.name COLLATE DATABASE_DEFAULT = dl.DatabaseName)
						ORDER BY dl.[Order];

						OPEN dCur;

						WHILE (1 = 1)
						BEGIN
							FETCH NEXT FROM dCur
							INTO @database, @replicaId;

							IF (@@FETCH_STATUS <> 0)
							BEGIN
								BREAK;
							END;

							--
							-- If is a member of a replica, we will only execute when running on the primary
							--
							IF (@replicaId IS NULL)
								OR (
									(
										SELECT
										CASE
											WHEN (dhags.primary_replica = ar.replica_server_name) THEN 1
											ELSE 0
										END AS IsPrimaryServer
										FROM master.sys.availability_groups AS ag
										INNER JOIN master.sys.availability_replicas AS ar ON ag.group_id = ar.group_id
										INNER JOIN master.sys.dm_hadr_availability_group_states AS dhags ON ag.group_id = dhags.group_id
										WHERE (ar.replica_server_name = @@SERVERNAME) AND (ar.replica_id = @replicaId)
									) = 1
								)
							BEGIN
								SET @stmt = ''
									USE '' + QUOTENAME(@database) + ''
									INSERT INTO '' + QUOTENAME(DB_NAME()) + ''.dbo.fhsmStatisticsAge(
										DatabaseName, SchemaName, ObjectName, IndexName
										,LastUpdated, Rows, RowsSampled, Steps
										,UnfilteredRows, ModificationCounter, PersistedSamplePercent, IsHypothetical
										,TimestampUTC, Timestamp
									)
									SELECT
										'''''' + @database + '''''' AS DatabaseName
										,sch.name AS SchemaName
										,o.name AS ObjectName
										,i.name AS IndexName
										,ddsp.last_updated AS LastUpdated
										,ddsp.rows AS Rows
										,ddsp.rows_sampled AS RowsSampled
										,ddsp.steps AS Steps
										,ddsp.unfiltered_rows AS UnfilteredRows
										,ddsp.modification_counter AS ModificationCounter
										,'' + @persistedSamplePercentStmt + '' AS PersistedSamplePercent
										,i.is_hypothetical AS IsHypothetical
										,@nowUTC
										,@now
									FROM sys.indexes AS i WITH (NOLOCK)
									INNER JOIN sys.objects AS o WITH (NOLOCK) ON (o.object_id = i.object_id)
									INNER JOIN sys.schemas AS sch WITH (NOLOCK) ON (sch.schema_id = o.schema_id)
									CROSS APPLY sys.dm_db_stats_properties(o.object_id, i.index_id) AS ddsp
									WHERE (o.type IN (''''U'''', ''''V'''')) AND (i.type <> 0);
								'';
								EXEC sp_executesql
									@stmt
									,N''@nowUTC datetime, @now datetime''
									,@nowUTC = @nowUTC, @now = @now;

								IF EXISTS(
									SELECT *
									FROM master.sys.system_objects AS so
									WHERE (so.name = ''dm_db_incremental_stats_properties'')
								)
								BEGIN
									SET @stmt = ''
										USE '' + QUOTENAME(@database) + ''
										INSERT INTO '' + QUOTENAME(DB_NAME()) + ''.dbo.fhsmStatisticsAgeIncremental(
											DatabaseName, SchemaName, ObjectName, IndexName, PartitionNumber
											,LastUpdated, Rows, RowsSampled, Steps
											,UnfilteredRows, ModificationCounter, IsHypothetical
											,TimestampUTC, Timestamp
										)
										SELECT
											'''''' + @database + '''''' AS DatabaseName
											,sch.name AS SchemaName
											,o.name AS ObjectName
											,i.name AS IndexName
											,ddsp.partition_number AS PartitionNumber
											,ddsp.last_updated AS LastUpdated
											,ddsp.rows AS Rows
											,ddsp.rows_sampled AS RowsSampled
											,ddsp.steps AS Steps
											,ddsp.unfiltered_rows AS UnfilteredRows
											,ddsp.modification_counter AS ModificationCounter
											,i.is_hypothetical AS IsHypothetical
											,@nowUTC
											,@now
										FROM sys.indexes AS i WITH (NOLOCK)
										INNER JOIN sys.objects AS o WITH (NOLOCK) ON (o.object_id = i.object_id)
										INNER JOIN sys.schemas AS sch WITH (NOLOCK) ON (sch.schema_id = o.schema_id)
										CROSS APPLY sys.dm_db_incremental_stats_properties(o.object_id, i.index_id) AS ddsp
										WHERE (o.type = ''''U'''') AND (i.type <> 0);
									'';
									EXEC sp_executesql
										@stmt
										,N''@nowUTC datetime, @now datetime''
										,@nowUTC = @nowUTC, @now = @now;
								END;
							END
							ELSE BEGIN
								SET @message = ''Database '''''' + @database + '''''' is member of a replica but this server is not the primary node'';
								EXEC dbo.fhsmSPLog @name = @name, @task = @thisTask, @type = ''Warning'', @message = @message;
							END;
						END;

						CLOSE dCur;
						DEALLOCATE dCur;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPStatisticsAge
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPStatisticsAge';
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
				,'dbo.fhsmStatisticsAge'
				,'TimestampUTC'
				,1
				,30

			UNION ALL

			SELECT
				1
				,'dbo.fhsmStatisticsAgeIncremental'
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
				,'Age of statistics'
				,PARSENAME('dbo.fhsmSPStatisticsAge', 1)
				,12 * 60 * 60
				,TIMEFROMPARTS(6, 0, 0, 0, 0)
				,TIMEFROMPARTS(7, 0, 0, 0, 0)
				,1, 1, 1, 1, 1, 1, 1
				,'@Databases = ''USER_DATABASES, msdb'''
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
			,SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4, SrcColumn5
			,OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4, OutputColumn5
		) AS (
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmStatisticsAge' AS SrcTable
				,'src' AS SrcAlias
				,'WHERE (src.Timestamp = (SELECT MAX(sa.Timestamp) FROM dbo.fhsmStatisticsAge AS sa))' AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Schema' AS DimensionName
				,'SchemaKey' AS DimensionKey
				,'dbo.fhsmStatisticsAge' AS SrcTable
				,'src' AS SrcAlias
				,'WHERE (src.Timestamp = (SELECT MAX(sa.Timestamp) FROM dbo.fhsmStatisticsAge AS sa))' AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', NULL, NULL, NULL
				,'Database', 'Schema', NULL, NULL, NULL

			UNION ALL

			SELECT
				'Object' AS DimensionName
				,'ObjectKey' AS DimensionKey
				,'dbo.fhsmStatisticsAge' AS SrcTable
				,'src' AS SrcAlias
				,'WHERE (src.Timestamp = (SELECT MAX(sa.Timestamp) FROM dbo.fhsmStatisticsAge AS sa))' AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', NULL, NULL
				,'Database', 'Schema', 'Object', NULL, NULL

			UNION ALL

			SELECT
				'Object partition' AS DimensionName
				,'ObjectPartitionKey' AS DimensionKey
				,'dbo.fhsmStatisticsAgeIncremental' AS SrcTable
				,'src' AS SrcAlias
				,'WHERE (src.Timestamp = (SELECT MAX(sa.Timestamp) FROM dbo.fhsmStatisticsAge AS sa))' AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'CAST(src.[PartitionNumber] AS nvarchar)', NULL
				,'Database', 'Schema', 'Object', 'Partition', NULL

			UNION ALL

			SELECT
				'Index' AS DimensionName
				,'IndexKey' AS DimensionKey
				,'dbo.fhsmStatisticsAge' AS SrcTable
				,'src' AS SrcAlias
				,'WHERE (src.Timestamp = (SELECT MAX(sa.Timestamp) FROM dbo.fhsmStatisticsAge AS sa))' AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'src.[IndexName]', NULL
				,'Database', 'Schema', 'Object', 'Index', NULL

			UNION ALL

			SELECT
				'Index partition' AS DimensionName
				,'IndexPartitionKey' AS DimensionKey
				,'dbo.fhsmStatisticsAgeIncremental' AS SrcTable
				,'src' AS SrcAlias
				,'WHERE (src.Timestamp = (SELECT MAX(sa.Timestamp) FROM dbo.fhsmStatisticsAge AS sa))' AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'src.[IndexName]', 'CAST(src.[PartitionNumber] AS nvarchar)'
				,'Database', 'Schema', 'Object', 'Index', 'Partition'
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
				,tgt.SrcColumn5 = src.SrcColumn5
				,tgt.OutputColumn1 = src.OutputColumn1
				,tgt.OutputColumn2 = src.OutputColumn2
				,tgt.OutputColumn3 = src.OutputColumn3
				,tgt.OutputColumn4 = src.OutputColumn4
				,tgt.OutputColumn5 = src.OutputColumn5
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(
				DimensionName, DimensionKey
				,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
				,SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4, SrcColumn5
				,OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4, OutputColumn5
			)
			VALUES(
				src.DimensionName, src.DimensionKey
				,src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn
				,src.SrcColumn1, src.SrcColumn2, src.SrcColumn3, src.SrcColumn4, src.SrcColumn5
				,src.OutputColumn1, src.OutputColumn2, src.OutputColumn3, src.OutputColumn4, src.OutputColumn5
			);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmStatisticsAge';
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmStatisticsAgeIncremental';
	END;
END;
