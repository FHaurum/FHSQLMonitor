SET NOCOUNT ON;

--
-- Test if we are in a database with FHSM registered
--
IF (dbo.fhsmFNIsValidInstallation() = 0)
BEGIN
	RAISERROR('Can not install as it appears the database is not correct installed', 0, 1) WITH NOWAIT;
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
		-- Create table dbo.fhsmIndexOperational if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmIndexOperational', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmIndexOperational', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmIndexOperational(
				Id int identity(1,1) NOT NULL
				,DatabaseName nvarchar(128) NOT NULL
				,SchemaName nvarchar(128) NOT NULL
				,ObjectName nvarchar(128) NOT NULL
				,IndexName nvarchar(128) NULL
				,LeafInsertCount bigint NOT NULL
				,LeafDeleteCount bigint NOT NULL
				,LeafUpdateCount bigint NOT NULL
				,LeafGhostCount bigint NOT NULL
				,NonleafInsertCount bigint NOT NULL
				,NonleafDeleteCount bigint NOT NULL
				,NonleafUpdateCount bigint NOT NULL
				,LeafAllocationCount bigint NOT NULL
				,NonleafAllocationCount bigint NOT NULL
				,LeafPageMergeCount bigint NOT NULL
				,NonleafPageMergeCount bigint NOT NULL
				,RangeScanCount bigint NOT NULL
				,SingletonLookupCount bigint NOT NULL
				,ForwardedFetchCount bigint NOT NULL
				,LOBFetchInPages bigint NOT NULL
				,LOBFetchInBytes bigint NOT NULL
				,LOBOrphanCreateCount bigint NOT NULL
				,LOBOrphanInsertCount bigint NOT NULL
				,RowOverflowFetchInPages bigint NOT NULL
				,RowOverflowFetchInBytes bigint NOT NULL
				,ColumnValuePushOffRowCount bigint NOT NULL
				,ColumnValuePullInRowCount bigint NOT NULL
				,RowLockCount bigint NOT NULL
				,RowLockWaitCount bigint NOT NULL
				,RowLockWaitInMS bigint NOT NULL
				,PageLockCount bigint NOT NULL
				,PageLockWaitCount bigint NOT NULL
				,PageLockWaitInMS bigint NOT NULL
				,IndexLockPromotionAttemptCount bigint NOT NULL
				,IndexLockPromotionCount bigint NOT NULL
				,PageLatchWaitCount bigint NOT NULL
				,PageLatchWaitInMS bigint NOT NULL
				,PageIOLatchWaitCount bigint NOT NULL
				,PageIOLatchWaitInMS bigint NOT NULL
				,TreePageLatchWaitCount bigint NOT NULL
				,TreePageLatchWaitInMS bigint NOT NULL
				,TreePageIOLatchWaitCount bigint NOT NULL
				,TreePageIOLatchWaitInMS bigint NOT NULL
				,PageCompressionAttemptCount bigint NOT NULL
				,PageCompressionSuccessCount bigint NOT NULL
				,VersionGeneratedInrow bigint NULL
				,VersionGeneratedOffrow bigint NULL
				,GhostVersionInrow bigint NULL
				,GhostVersionOffrow bigint NULL
				,InsertOverGhostVersionInrow bigint NULL
				,InsertOverGhostVersionOffrow bigint NULL
				,LastSQLServiceRestart datetime NOT NULL
				,TimestampUTC datetime NOT NULL
				,Timestamp datetime NOT NULL
				,CONSTRAINT PK_fhsmIndexOperational PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmIndexOperational_TimestampUTC ON dbo.fhsmIndexOperational(TimestampUTC);
			CREATE NONCLUSTERED INDEX NC_fhsmIndexOperational_Timestamp ON dbo.fhsmIndexOperational(Timestamp);
			CREATE NONCLUSTERED INDEX NC_fhsmIndexOperational_DatabaseName_SchemaName_ObjectName_IndexName ON dbo.fhsmIndexOperational(DatabaseName, SchemaName, ObjectName, IndexName);
		END;

		--
		-- Register extended properties on the table dbo.fhsmIndexOperational
		--
		BEGIN
			SET @objectName = 'dbo.fhsmIndexOperational';
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
		-- Create fact view @pbiSchema.[Index operational]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index operational') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index operational') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index operational') + '
				AS
				SELECT
					io.LeafInsertCount
					,io.LeafDeleteCount
					,io.LeafUpdateCount
					,io.LeafGhostCount
					,io.NonleafInsertCount
					,io.NonleafDeleteCount
					,io.NonleafUpdateCount
					,io.LeafAllocationCount
					,io.NonleafAllocationCount
					,io.LeafPageMergeCount
					,io.NonleafPageMergeCount
					,io.RangeScanCount
					,io.SingletonLookupCount
					,io.ForwardedFetchCount
					,io.LOBFetchInPages
					,io.LOBFetchInBytes
					,io.LOBOrphanCreateCount
					,io.LOBOrphanInsertCount
					,io.RowOverflowFetchInPages
					,io.RowOverflowFetchInBytes
					,io.ColumnValuePushOffRowCount
					,io.ColumnValuePullInRowCount
					,io.RowLockCount
					,io.RowLockWaitCount
					,io.RowLockWaitInMS
					,io.PageLockCount
					,io.PageLockWaitCount
					,io.PageLockWaitInMS
					,io.IndexLockPromotionAttemptCount
					,io.IndexLockPromotionCount
					,io.PageLatchWaitCount
					,io.PageLatchWaitInMS
					,io.PageIOLatchWaitCount
					,io.PageIOLatchWaitInMS
					,io.TreePageLatchWaitCount
					,io.TreePageLatchWaitInMS
					,io.TreePageIOLatchWaitCount
					,io.TreePageIOLatchWaitInMS
					,io.PageCompressionAttemptCount
					,io.PageCompressionSuccessCount
					,io.VersionGeneratedInrow
					,io.VersionGeneratedOffrow
					,io.GhostVersionInrow
					,io.GhostVersionOffrow
					,io.InsertOverGhostVersionInrow
					,io.InsertOverGhostVersionOffrow
					,io.LastSQLServiceRestart
					,CAST(io.Timestamp AS date) AS Date
					,(DATEPART(HOUR, io.Timestamp) * 60 * 60) + (DATEPART(MINUTE, io.Timestamp) * 60) + (DATEPART(SECOND, io.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(io.DatabaseName, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(io.DatabaseName, io.SchemaName, DEFAULT, DEFAULT) AS k) AS SchemaKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(io.DatabaseName, io.SchemaName, io.ObjectName, DEFAULT) AS k) AS ObjectKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(io.DatabaseName, io.SchemaName, io.ObjectName, COALESCE(io.IndexName, ''N.A.'')) AS k) AS IndexKey
				FROM dbo.fhsmIndexOperational AS io
				WHERE (io.Timestamp IN (
					SELECT a.Timestamp
					FROM (
						SELECT
							io2.Timestamp
							,ROW_NUMBER() OVER(PARTITION BY CAST(io2.Timestamp AS date) ORDER BY io2.Timestamp DESC) AS _Rnk_
						FROM dbo.fhsmIndexOperational AS io2
					) AS a
					WHERE (a._Rnk_ = 1)
				));
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Index operational]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index operational');
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
		-- Create stored procedure dbo.fhsmSPIndexOperational
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPIndexOperational'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPIndexOperational AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPIndexOperational (
					@name nvarchar(128)
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @database nvarchar(128);
					DECLARE @databases nvarchar(max);
					DECLARE @ghostVersionInrowStmt nvarchar(max);
					DECLARE @ghostVersionOffrowStmt nvarchar(max);
					DECLARE @insertOverGhostVersionInrowStmt nvarchar(max);
					DECLARE @insertOverGhostVersionOffrowStmt nvarchar(max);
					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameters nvarchar(max);
					DECLARE @parametersTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);
					DECLARE @versionGeneratedInrowStmt nvarchar(max);
					DECLARE @versionGeneratedOffrowStmt nvarchar(max);

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

						--
						-- Test if version_generated_inrow (and thereby all other *version*) exists on dm_db_index_operational_stats
						--
						BEGIN
							IF EXISTS(
								SELECT *
								FROM master.sys.system_columns AS sc
								INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
								WHERE (so.name = ''dm_db_index_operational_stats'') AND (sc.name = ''version_generated_inrow'')
							)
							BEGIN
								SET @versionGeneratedInrowStmt = ''SUM(ddios.version_generated_inrow)'';
								SET @versionGeneratedOffrowStmt = ''SUM(ddios.version_generated_offrow)'';
								SET @ghostVersionInrowStmt = ''SUM(ddios.ghost_version_inrow)'';
								SET @ghostVersionOffrowStmt = ''SUM(ddios.ghost_version_offrow)'';
								SET @insertOverGhostVersionInrowStmt = ''SUM(ddios.insert_over_ghost_version_inrow)'';
								SET @insertOverGhostVersionOffrowStmt = ''SUM(ddios.insert_over_ghost_version_offrow)'';
							END
							ELSE BEGIN
								SET @versionGeneratedInrowStmt = ''NULL'';
								SET @versionGeneratedOffrowStmt = ''NULL'';
								SET @ghostVersionInrowStmt = ''NULL'';
								SET @ghostVersionOffrowStmt = ''NULL'';
								SET @insertOverGhostVersionInrowStmt = ''NULL'';
								SET @insertOverGhostVersionOffrowStmt = ''NULL'';
							END;
						END;

						DECLARE dCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
						SELECT d.DatabaseName
						FROM #dbList AS d
						ORDER BY d.[Order];

						OPEN dCur;

						WHILE (1 = 1)
						BEGIN
							FETCH NEXT FROM dCur
							INTO @database;

							IF (@@FETCH_STATUS <> 0)
							BEGIN
								BREAK;
							END;

							SET @stmt = ''
								USE '' + QUOTENAME(@database) + '';

								SELECT
									DB_NAME() AS DatabaseName
									,sch.name AS SchemaName
									,o.name AS ObjectName
									,i.name AS IndexName
									,SUM(ddios.leaf_insert_count) AS LeafInsertCount
									,SUM(ddios.leaf_delete_count) AS LeafDeleteCount
									,SUM(ddios.leaf_update_count) AS LeafUpdateCount
									,SUM(ddios.leaf_ghost_count) AS LeafGhostCount
									,SUM(ddios.nonleaf_insert_count) AS NonleafInsertCount
									,SUM(ddios.nonleaf_delete_count) AS NonleafDeleteCount
									,SUM(ddios.nonleaf_update_count) AS NonleafUpdateCount
									,SUM(ddios.leaf_allocation_count) AS LeafAllocationCount
									,SUM(ddios.nonleaf_allocation_count) AS NonleafAllocationCount
									,SUM(ddios.leaf_page_merge_count) AS LeafPageMergeCount
									,SUM(ddios.nonleaf_page_merge_count) AS NonleafPageMergeCount
									,SUM(ddios.range_scan_count) AS RangeScanCount
									,SUM(ddios.singleton_lookup_count) AS SingletonLookupCount
									,SUM(ddios.forwarded_fetch_count) AS ForwardedFetchCount
									,SUM(ddios.lob_fetch_in_pages) AS LOBFetchInPages
									,SUM(ddios.lob_fetch_in_bytes) AS LOBFetchInBytes
									,SUM(ddios.lob_orphan_create_count) AS LOBOrphanCreateCount
									,SUM(ddios.lob_orphan_insert_count) AS LOBOrphanInsertCount
									,SUM(ddios.row_overflow_fetch_in_pages) AS RowOverflowFetchInPages
									,SUM(ddios.row_overflow_fetch_in_bytes) AS RowOverflowFetchInBytes
									,SUM(ddios.column_value_push_off_row_count) AS ColumnValuePushOffRowCount
									,SUM(ddios.column_value_pull_in_row_count) AS ColumnValuePullInRowCount
									,SUM(ddios.row_lock_count) AS RowLockCount
									,SUM(ddios.row_lock_wait_count) AS RowLockWaitCount
									,SUM(ddios.row_lock_wait_in_ms) AS RowLockWaitInMS
									,SUM(ddios.page_lock_count) AS PageLockCount
									,SUM(ddios.page_lock_wait_count) AS PageLockWaitCount
									,SUM(ddios.page_lock_wait_in_ms) AS PageLockWaitInMS
									,SUM(ddios.index_lock_promotion_attempt_count) AS IndexLockPromotionAttemptCount
									,SUM(ddios.index_lock_promotion_count) AS IndexLockPromotionCount
									,SUM(ddios.page_latch_wait_count) AS PageLatchWaitCount
									,SUM(ddios.page_latch_wait_in_ms) AS PageLatchWaitInMS
									,SUM(ddios.page_io_latch_wait_count) AS PageIOLatchWaitCount
									,SUM(ddios.page_io_latch_wait_in_ms) AS PageIOLatchWaitInMS
									,SUM(ddios.tree_page_latch_wait_count) AS TreePageLatchWaitCount
									,SUM(ddios.tree_page_latch_wait_in_ms) AS TreePageLatchWaitInMS
									,SUM(ddios.tree_page_io_latch_wait_count) AS TreePageIOLatchWaitCount
									,SUM(ddios.tree_page_io_latch_wait_in_ms) AS TreePageIOLatchWaitInMS
									,SUM(ddios.page_compression_attempt_count) AS PageCompressionAttemptCount
									,SUM(ddios.page_compression_success_count) AS PageCompressionSuccessCount
									,'' + @versionGeneratedInrowStmt + '' AS VersionGeneratedInrow
									,'' + @versionGeneratedOffrowStmt + '' AS VersionGeneratedOffrow
									,'' + @ghostVersionInrowStmt + '' AS GhostVersionInrow
									,'' + @ghostVersionOffrowStmt + '' AS GhostVersionOffrow
									,'' + @insertOverGhostVersionInrowStmt + '' AS InsertOverGhostVersionInrow
									,'' + @insertOverGhostVersionOffrowStmt + '' AS InsertOverGhostVersionOffrow
									,(SELECT d.create_date FROM sys.databases AS d WITH (NOLOCK) WHERE (d.name = ''''tempdb'''')) AS LastSQLServiceRestart
									,@nowUTC, @now
								FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL) AS ddios
								INNER JOIN sys.objects AS o WITH (NOLOCK) ON (o.object_id = ddios.object_id)
								INNER JOIN sys.schemas AS sch WITH (NOLOCK) ON (sch.schema_id = o.schema_id)
								INNER JOIN sys.indexes AS i ON (i.object_id = ddios.object_id) AND (i.index_id = ddios.index_id)
								WHERE (o.type IN (''''U'''', ''''V''''))
								GROUP BY DB_NAME(ddios.database_id), sch.name, o.name, i.name;
							'';
							INSERT INTO dbo.fhsmIndexOperational(
								DatabaseName, SchemaName, ObjectName, IndexName
								,LeafInsertCount, LeafDeleteCount, LeafUpdateCount, LeafGhostCount
								,NonleafInsertCount, NonleafDeleteCount, NonleafUpdateCount
								,LeafAllocationCount, NonleafAllocationCount
								,LeafPageMergeCount, NonleafPageMergeCount
								,RangeScanCount, SingletonLookupCount
								,ForwardedFetchCount, LOBFetchInPages, LOBFetchInBytes
								,LOBOrphanCreateCount, LOBOrphanInsertCount
								,RowOverflowFetchInPages, RowOverflowFetchInBytes
								,ColumnValuePushOffRowCount, ColumnValuePullInRowCount
								,RowLockCount, RowLockWaitCount, RowLockWaitInMS
								,PageLockCount, PageLockWaitCount, PageLockWaitInMS
								,IndexLockPromotionAttemptCount, IndexLockPromotionCount
								,PageLatchWaitCount, PageLatchWaitInMS
								,PageIOLatchWaitCount, PageIOLatchWaitInMS
								,TreePageLatchWaitCount, TreePageLatchWaitInMS
								,TreePageIOLatchWaitCount, TreePageIOLatchWaitInMS
								,PageCompressionAttemptCount, PageCompressionSuccessCount
								,VersionGeneratedInrow, VersionGeneratedOffrow
								,GhostVersionInrow, GhostVersionOffrow
								,InsertOverGhostVersionInrow, InsertOverGhostVersionOffrow
								,LastSQLServiceRestart
								,TimestampUTC, Timestamp
							)
							EXEC sp_executesql
								@stmt
								,N''@now datetime, @nowUTC datetime''
								,@now = @now, @nowUTC = @nowUTC;
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
		-- Register extended properties on the stored procedure dbo.fhsmSPIndexOperational
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPIndexOperational';
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
				,'dbo.fhsmIndexOperational'
				,'TimestampUTC'
				,1
				,90
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
				,'Index operational'
				,PARSENAME('dbo.fhsmSPIndexOperational', 1)
				,12 * 60 * 60
				,TIMEFROMPARTS(23, 0, 0, 0, 0)
				,TIMEFROMPARTS(23, 59, 59, 0, 0)
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
		dimensions(DimensionName, DimensionKey, SrcTable, SrcAlias, SrcWhere, SrcDateColumn, SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4, OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4) AS(
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmIndexOperational' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL
				,'Database', NULL, NULL, NULL

			UNION ALL

			SELECT
				'Schema' AS DimensionName
				,'SchemaKey' AS DimensionKey
				,'dbo.fhsmIndexOperational' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', NULL, NULL
				,'Database', 'Schema', NULL, NULL

			UNION ALL

			SELECT
				'Object' AS DimensionName
				,'ObjectKey' AS DimensionKey
				,'dbo.fhsmIndexOperational' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', NULL
				,'Database', 'Schema', 'Object', NULL

			UNION ALL

			SELECT
				'Index' AS DimensionName
				,'IndexKey' AS DimensionKey
				,'dbo.fhsmIndexOperational' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
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
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmIndexOperational';
	END;
END;
