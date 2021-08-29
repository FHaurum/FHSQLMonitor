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
		-- Create table dbo.fhsmTableSize if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmTableSize', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmTableSize', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmTableSize(
				Id int identity(1,1) NOT NULL
				,DatabaseName nvarchar(128) NOT NULL
				,SchemaName nvarchar(128) NOT NULL
				,ObjectName nvarchar(128) NOT NULL
				,IndexName nvarchar(128) NULL
				,PartitionNumber int NOT NULL
				,IsMemoryOptimized bit NOT NULL
				,Rows bigint NOT NULL
				,Reserved int NULL
				,Data int NULL
				,IndexSize int NULL
				,Unused int NULL
				,TimestampUTC datetime NOT NULL
				,Timestamp datetime NOT NULL
				,CONSTRAINT PK_fhsmTableSize PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmTableSize_TimestampUTC ON dbo.fhsmTableSize(TimestampUTC);
			CREATE NONCLUSTERED INDEX NC_fhsmTableSize_Timestamp ON dbo.fhsmTableSize(Timestamp);
			CREATE NONCLUSTERED INDEX NC_fhsmTableSize_DatabaseName_SchemaName_ObjectName_IndexName ON dbo.fhsmTableSize(DatabaseName, SchemaName, ObjectName, IndexName);
		END;

		--
		-- Register extended properties on the table dbo.fhsmTableSize
		--
		BEGIN
			SET @objectName = 'dbo.fhsmTableSize';
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
		-- Create fact view @pbiSchema.[Table size]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Table size') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Table size') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Table size') + '
				AS
				SELECT
					ts.Rows
					,ts.Reserved
					,ts.Data
					,ts.IndexSize
					,ts.Unused
					,CAST(ts.Timestamp AS date) AS Date
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ts.DatabaseName, DEFAULT,       DEFAULT,       DEFAULT,                          DEFAULT,            DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ts.DatabaseName, ts.SchemaName, DEFAULT,       DEFAULT,                          DEFAULT,            DEFAULT) AS k) AS SchemaKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ts.DatabaseName, ts.SchemaName, ts.ObjectName, DEFAULT,                          DEFAULT,            DEFAULT) AS k) AS ObjectKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ts.DatabaseName, ts.SchemaName, ts.ObjectName, COALESCE(ts.IndexName, ''N.A.''), DEFAULT,            DEFAULT) AS k) AS IndexKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ts.DatabaseName, ts.SchemaName, ts.ObjectName, ts.PartitionNumber,               DEFAULT,            DEFAULT) AS k) AS ObjectPartitionKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ts.DatabaseName, ts.SchemaName, ts.ObjectName, COALESCE(ts.IndexName, ''N.A.''), ts.PartitionNumber, DEFAULT) AS k) AS IndexPartitionKey
				FROM dbo.fhsmTableSize AS ts
				WHERE (ts.Timestamp IN (
					SELECT a.Timestamp
					FROM (
						SELECT
							ts2.Timestamp
							,ROW_NUMBER() OVER(PARTITION BY CAST(ts2.Timestamp AS date) ORDER BY ts2.Timestamp DESC) AS _Rnk_
						FROM dbo.fhsmTableSize AS ts2
					) AS a
					WHERE (a._Rnk_ = 1)
				));
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Table size]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Table size');
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
		-- Create stored procedure dbo.fhsmSPSpaceUsed
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPSpaceUsed'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPSpaceUsed AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPSpaceUsed (
					@database nvarchar(128)
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @isMemoryOptimizedStmt nvarchar(max);
					DECLARE @stmt nvarchar(max);

					--
					-- Test if version_generated_inrow (and thereby all other *version*) exists on dm_db_index_operational_stats
					--
					BEGIN
						IF EXISTS(
							SELECT *
							FROM master.sys.system_columns AS sc
							INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
							WHERE (so.name = ''tables'') AND (sc.name = ''is_memory_optimized'')
						)
						BEGIN
							SET @isMemoryOptimizedStmt = ''
								/*
								** If the table is memory-optimized, return NULL for reserved, data, index_size and unused.
								*/
								IF (SELECT t.is_memory_optimized FROM '' + QUOTENAME(@database) + ''.sys.tables AS t WITH (NOLOCK) WHERE t.object_id = @objectId) = 1
								BEGIN
									INSERT INTO @spaceUsed(DatabaseName, SchemaName, ObjectName, IndexName, PartitionNumber, IsMemoryOptimized, Rows, Reserved, Data, IndexSize, Unused)
									SELECT
										@database AS DatabaseName
										,@schema AS SchemaName
										,@object AS ObjectName
										,i.name AS IndexName 
										,1 AS PartitionNumber
										,1 AS IsMemoryOptimized
										,SUM(p.rows) AS Rows
										,NULL AS Reserved
										,NULL AS Data
										,NULL AS IndexSize
										,NULL AS Unused
									FROM '' + QUOTENAME(@database) + ''.sys.partitions AS p WITH (NOLOCK)
									LEFT OUTER JOIN '' + QUOTENAME(@database) + ''.sys.indexes AS i WITH (NOLOCK) ON (i.object_id = p.object_id) AND (i.index_id = p.index_id)
									WHERE (p.index_id IN (0, 1, 5)) AND (p.object_id = @objectId)
									GROUP BY i.name;
								END
							'';
						END
						ELSE BEGIN
							SET @isMemoryOptimizedStmt = ''
								/*
								** Dummy code as this SQL server version does not support memory optimized tables
								*/
								IF (1 = 0)
								BEGIN
									SET @objectId = @objectId;
								END
							'';
						END;
					END;

					SET @stmt = ''
						DECLARE @object nvarchar(128);
						DECLARE @objectId int;
						DECLARE @pages bigint;
						DECLARE @reservedpages bigint;
						DECLARE @rowCount bigint;
						DECLARE @schema nvarchar(128);
						DECLARE @spaceUsed TABLE(
							DatabaseName nvarchar(128), SchemaName nvarchar(128), ObjectName nvarchar(128), IndexName nvarchar(128), PartitionNumber int
							,IsMemoryOptimized bit, Rows bigint, Reserved int, Data int, IndexSize int, Unused int
						);
						DECLARE @usedpages bigint;

						DECLARE oCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
						SELECT sch.name AS [Schema], o.name AS Object, o.object_id AS ObjectId
						FROM '' + QUOTENAME(@database) + ''.sys.schemas AS sch WITH (NOLOCK)
						INNER JOIN '' + QUOTENAME(@database) + ''.sys.objects AS o WITH (NOLOCK) ON (o.schema_id = sch.schema_id)
						WHERE (o.type = ''''U'''')
						ORDER BY sch.name, o.name;

						OPEN OCur;

						WHILE (1 = 1)
						BEGIN
							FETCH NEXT FROM oCur
							INTO @schema, @object, @objectId;

							IF (@@FETCH_STATUS <> 0)
							BEGIN
								BREAK;
							END;

							'' + @isMemoryOptimizedStmt + ''
							ELSE BEGIN
								INSERT INTO @spaceUsed(DatabaseName, SchemaName, ObjectName, IndexName, PartitionNumber, IsMemoryOptimized, Rows, Reserved, Data, IndexSize, Unused)
								SELECT
									@database AS DatabaseName
									,@schema AS SchemaName
									,@object AS ObjectName
									,a.IndexName
									,a.PartitionNumber
									,0 AS IsMemoryOptimized
									,a.[RowCount] AS Rows
									,((a.ReservedPageCount + a.XMLFullReservedPageCount) * 8) AS Reserved
									,(a.Pages * 8) AS Data
									,((CASE WHEN (a.UsedPageCount + a.XMLFullUsedPageCount) > a.Pages THEN ((a.UsedPageCount + a.XMLFullUsedPageCount) - a.Pages) ELSE 0 END) * 8) AS IndexSize
									,((CASE WHEN (a.ReservedPageCount + a.XMLFullReservedPageCount) > (a.UsedPageCount + a.XMLFullUsedPageCount) THEN ((a.ReservedPageCount + a.XMLFullReservedPageCount) - (a.UsedPageCount + a.XMLFullUsedPageCount)) ELSE 0 END) * 8) AS Unused
								FROM (
									/*
									** Now calculate the summary data.
									*  Note that LOB Data and Row-overflow Data are counted as Data Pages for the base table
									*  For non-clustered indices they are counted towards the index pages
									*/
									SELECT
										ddps.object_id
										,i.name AS IndexName
										,ddps.partition_number AS PartitionNumber
										,ddps.reserved_page_count AS ReservedPageCount
										,ddps.used_page_count AS UsedPageCount
										,CASE WHEN (ddps.index_id < 2) THEN (ddps.in_row_data_page_count + ddps.lob_used_page_count + ddps.row_overflow_used_page_count) ELSE 0 END AS Pages
										,CASE WHEN (ddps.index_id < 2) THEN ddps.row_count ELSE 0 END AS [RowCount]
										,COALESCE(XMLFull.ReservedPageCount, 0) AS XMLFullReservedPageCount
										,COALESCE(XMLFull.UsedPageCount, 0) AS XMLFullUsedPageCount
									FROM '' + QUOTENAME(@database) + ''.sys.dm_db_partition_stats AS ddps WITH (NOLOCK)
									LEFT OUTER JOIN '' + QUOTENAME(@database) + ''.sys.indexes AS i WITH (NOLOCK) ON (i.object_id = ddps.object_id) AND (i.index_id = ddps.index_id)
									OUTER APPLY (
										/*
										** Check if table has XML Indexes or Fulltext Indexes which use internal tables tied to this table
										*/
										SELECT
											p.reserved_page_count AS ReservedPageCount
											,p.used_page_count AS UsedPageCount
										FROM '' + QUOTENAME(@database) + ''.sys.dm_db_partition_stats AS p WITH (NOLOCK)
										INNER JOIN '' + QUOTENAME(@database) + ''.sys.internal_tables AS it WITH (NOLOCK) ON (it.object_id = p.object_id)
										WHERE (it.parent_id = ddps.object_id) AND (p.partition_id = ddps.partition_id) AND (it.internal_type IN (202, 204, 207, 211, 212, 213, 214, 215, 216, 221, 222, 236))
									) AS XMLFull
									WHERE (ddps.object_id = @objectId)
								) AS a;
							END;
						END;

						CLOSE OCur;
						DEALLOCATE OCur;

						SELECT *
						FROM @spaceUsed AS su
						ORDER BY su.DatabaseName, su.SchemaName, su.ObjectName, su.IndexName;
					'';
					EXEC sp_executesql
						@stmt
						,N''@database nvarchar(128)''
						,@database = @database;

					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPSpaceUsed
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPSpaceUsed';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create stored procedure dbo.fhsmSPTableSize
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPTableSize'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPTableSize AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPTableSize (
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
					DECLARE @spaceUsed TABLE(DatabaseName nvarchar(128), SchemaName nvarchar(128), ObjectName nvarchar(128), IndexName nvarchar(128), PartitionNumber int, IsMemoryOptimized bit, Rows bigint, Reserved int, Data int, IndexSize int, Unused int);
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
						SET @now = SYSDATETIME();
						SET @nowUTC = SYSUTCDATETIME();

						DECLARE dCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
						SELECT dl.DatabaseName, ' + CASE WHEN (@productVersion1 <= 10) THEN 'NULL' ELSE 'd.replica_id' END + ' AS replica_id
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
			';
			IF (@productVersion1 >= 11)
			BEGIN
				-- SQL Versions SQL2012 or higher
				SET @stmt += '
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
				';
			END;
			SET @stmt += '
							BEGIN
								DELETE @spaceUsed;

								SET @stmt = ''EXEC dbo.fhsmSPSpaceUsed @database = @database;'';
								INSERT INTO @spaceUsed
								EXEC sp_executesql
									@stmt
									,N''@database nvarchar(128)''
									,@database = @database;

								INSERT INTO dbo.fhsmTableSize(DatabaseName, SchemaName, ObjectName, IndexName, PartitionNumber, IsMemoryOptimized, Rows, Reserved, Data, IndexSize, Unused, TimestampUTC, Timestamp)
								SELECT su.DatabaseName, su.SchemaName, su.ObjectName, su.IndexName, su.PartitionNumber, su.IsMemoryOptimized, su.Rows, su.Reserved, su.Data, su.IndexSize, su.Unused, @nowUTC, @now
								FROM @spaceUsed AS su;
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
		-- Register extended properties on the stored procedure dbo.fhsmSPTableSize
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPTableSize';
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
				,'dbo.fhsmTableSize'
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
				1
				,'Table size'
				,PARSENAME('dbo.fhsmSPTableSize', 1)
				,12 * 60 * 60
				,CAST('1900-1-1T23:00:00.0000' AS datetime2(0))
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))
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
				,'dbo.fhsmTableSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Schema' AS DimensionName
				,'SchemaKey' AS DimensionKey
				,'dbo.fhsmTableSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', NULL, NULL, NULL
				,'Database', 'Schema', NULL, NULL, NULL

			UNION ALL

			SELECT
				'Object' AS DimensionName
				,'ObjectKey' AS DimensionKey
				,'dbo.fhsmTableSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', NULL, NULL
				,'Database', 'Schema', 'Object', NULL, NULL

			UNION ALL

			SELECT
				'Index' AS DimensionName
				,'IndexKey' AS DimensionKey
				,'dbo.fhsmTableSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'COALESCE(src.[IndexName], ''N.A.'')', NULL
				,'Database', 'Schema', 'Object', 'Index', NULL

			UNION ALL

			SELECT
				'Object partition' AS DimensionName
				,'ObjectPartitionKey' AS DimensionKey
				,'dbo.fhsmTableSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'CAST(src.[PartitionNumber] AS nvarchar)', NULL
				,'Database', 'Schema', 'Object', 'Partition', NULL

			UNION ALL

			SELECT
				'Index partition' AS DimensionName
				,'IndexPartitionKey' AS DimensionKey
				,'dbo.fhsmTableSize' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'COALESCE(src.[IndexName], ''N.A.'')', 'CAST(src.[PartitionNumber] AS nvarchar)'
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
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmTableSize';
	END;
END;
