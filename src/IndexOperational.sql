SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableIndexOperational bit;

	SET @enableIndexOperational = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing IndexOperational', 0, 1) WITH NOWAIT;
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
		-- Create table dbo.fhsmIndexOperational and indexes if they not already exists
		--
		IF OBJECT_ID('dbo.fhsmIndexOperational', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmIndexOperational', 0, 1) WITH NOWAIT;

			SET @stmt = '
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
					,CONSTRAINT PK_fhsmIndexOperational PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmIndexOperational')) AND (i.name = 'NC_fhsmIndexOperational_TimestampUTC'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmIndexOperational_TimestampUTC] to table dbo.fhsmIndexOperational', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmIndexOperational_TimestampUTC ON dbo.fhsmIndexOperational(TimestampUTC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmIndexOperational')) AND (i.name = 'NC_fhsmIndexOperational_Timestamp'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmIndexOperational_Timestamp] to table dbo.fhsmIndexOperational', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmIndexOperational_Timestamp ON dbo.fhsmIndexOperational(Timestamp)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmIndexOperational')) AND (i.name = 'NC_fhsmIndexOperational_DatabaseName_SchemaName_ObjectName_IndexName_TimestampUTC'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmIndexOperational_DatabaseName_SchemaName_ObjectName_IndexName_TimestampUTC] to table dbo.fhsmIndexOperational', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmIndexOperational_DatabaseName_SchemaName_ObjectName_IndexName_TimestampUTC ON dbo.fhsmIndexOperational(DatabaseName, SchemaName, ObjectName, IndexName, TimestampUTC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
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

		--
		-- Create table dbo.fhsmIndexOperationalReport if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmIndexOperationalReport', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmIndexOperationalReport', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmIndexOperationalReport(
					Id int identity(1,1) NOT NULL
					,LeafInsertCount bigint NULL
					,LeafDeleteCount bigint NULL
					,LeafUpdateCount bigint NULL
					,LeafGhostCount bigint NULL
					,NonleafInsertCount bigint NULL
					,NonleafDeleteCount bigint NULL
					,NonleafUpdateCount bigint NULL
					,LeafAllocationCount bigint NULL
					,NonleafAllocationCount bigint NULL
					,LeafPageMergeCount bigint NULL
					,NonleafPageMergeCount bigint NULL
					,RangeScanCount bigint NULL
					,SingletonLookupCount bigint NULL
					,ForwardedFetchCount bigint NULL
					,LOBFetchInPages bigint NULL
					,LOBFetchInBytes bigint NULL
					,LOBOrphanCreateCount bigint NULL
					,LOBOrphanInsertCount bigint NULL
					,RowOverflowFetchInPages bigint NULL
					,RowOverflowFetchInBytes bigint NULL
					,ColumnValuePushOffRowCount bigint NULL
					,ColumnValuePullInRowCount bigint NULL
					,RowLockCount bigint NULL
					,RowLockWaitCount bigint NULL
					,RowLockWaitInMS bigint NULL
					,PageLockCount bigint NULL
					,PageLockWaitCount bigint NULL
					,PageLockWaitInMS bigint NULL
					,IndexLockPromotionAttemptCount bigint NULL
					,IndexLockPromotionCount bigint NULL
					,PageLatchWaitCount bigint NULL
					,PageLatchWaitInMS bigint NULL
					,PageIOLatchWaitCount bigint NULL
					,PageIOLatchWaitInMS bigint NULL
					,TreePageLatchWaitCount bigint NULL
					,TreePageLatchWaitInMS bigint NULL
					,TreePageIOLatchWaitCount bigint NULL
					,TreePageIOLatchWaitInMS bigint NULL
					,PageCompressionAttemptCount bigint NULL
					,PageCompressionSuccessCount bigint NULL
					,VersionGeneratedInrow bigint NULL
					,VersionGeneratedOffrow bigint NULL
					,GhostVersionInrow bigint NULL
					,GhostVersionOffrow bigint NULL
					,InsertOverGhostVersionInrow bigint NULL
					,InsertOverGhostVersionOffrow bigint NULL
					,TimestampUTC datetime NOT NULL
					,Timestamp datetime NOT NULL
					,DatabaseName nvarchar(128) NOT NULL
					,SchemaName nvarchar(128) NOT NULL
					,ObjectName nvarchar(128) NOT NULL
					,IndexName nvarchar(128) NULL
					,Date date NOT NULL
					,TimeKey int NOT NULL
					,DatabaseKey bigint NOT NULL
					,SchemaKey bigint NOT NULL
					,ObjectKey bigint NOT NULL
					,IndexKey bigint NOT NULL
					,CONSTRAINT NCPK_fhsmIndexOperationalReport PRIMARY KEY NONCLUSTERED(Id)' + @tableCompressionStmt + '
				);

				CREATE CLUSTERED INDEX CL_fhsmIndexOperationalReport_TimestampUTC ON dbo.fhsmIndexOperationalReport(TimestampUTC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmIndexOperationalReport
		--
		BEGIN
			SET @objectName = 'dbo.fhsmIndexOperationalReport';
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
					ior.LeafInsertCount
					,ior.LeafDeleteCount
					,ior.LeafUpdateCount
					,ior.LeafGhostCount
					,ior.NonleafInsertCount
					,ior.NonleafDeleteCount
					,ior.NonleafUpdateCount
					,ior.LeafAllocationCount
					,ior.NonleafAllocationCount
					,ior.LeafPageMergeCount
					,ior.NonleafPageMergeCount
					,ior.RowLockCount
					,ior.RowLockWaitCount
					,ior.RowLockWaitInMS
					,ior.PageLockCount
					,ior.PageLockWaitCount
					,ior.PageLockWaitInMS
					,ior.Date
					,ior.TimeKey
					,ior.DatabaseKey
					,ior.SchemaKey
					,ior.ObjectKey
					,ior.IndexKey
				FROM dbo.fhsmIndexOperationalReport AS ior
				WHERE
					(ior.LeafInsertCount <> 0)
					OR (ior.LeafDeleteCount <> 0)
					OR (ior.LeafUpdateCount <> 0)
					OR (ior.LeafGhostCount <> 0)
					OR (ior.NonleafInsertCount <> 0)
					OR (ior.NonleafDeleteCount <> 0)
					OR (ior.NonleafUpdateCount <> 0)
					OR (ior.LeafAllocationCount <> 0)
					OR (ior.NonleafAllocationCount <> 0)
					OR (ior.LeafPageMergeCount <> 0)
					OR (ior.NonleafPageMergeCount <> 0)
					OR (ior.RowLockCount <> 0)
					OR (ior.RowLockWaitCount <> 0)
					OR (ior.RowLockWaitInMS <> 0)
					OR (ior.PageLockCount <> 0)
					OR (ior.PageLockWaitCount <> 0)
					OR (ior.PageLockWaitInMS <> 0);
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
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @database nvarchar(128);
					DECLARE @databases nvarchar(max);
					DECLARE @errorMsg nvarchar(max);
					DECLARE @ghostVersionInrowStmt nvarchar(max);
					DECLARE @ghostVersionOffrowStmt nvarchar(max);
					DECLARE @insertOverGhostVersionInrowStmt nvarchar(max);
					DECLARE @insertOverGhostVersionOffrowStmt nvarchar(max);
					DECLARE @message nvarchar(max);
					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameters nvarchar(max);
					DECLARE @parametersTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
					DECLARE @replicaId uniqueidentifier;
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);
					DECLARE @versionGeneratedInrowStmt nvarchar(max);
					DECLARE @versionGeneratedOffrowStmt nvarchar(max);

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

			';
			SET @stmt += '
					--
					-- Collect data
					--
					BEGIN
						SELECT
							@now = SYSDATETIME()
							,@nowUTC = SYSUTCDATETIME();

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
			';
			SET @stmt += '

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
								BEGIN TRY
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
								END TRY
								BEGIN CATCH
									SET @errorMsg = ERROR_MESSAGE();

									SET @message = ''Database '''''' + @database + '''''' failed due to - '' + @errorMsg;
									EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Warning'', @message = @message;
								END CATCH;
							END
							ELSE BEGIN
								SET @message = ''Database '''''' + @database + '''''' is member of a replica but this server is not the primary node'';
								EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Warning'', @message = @message;
							END;
						END;

						CLOSE dCur;
						DEALLOCATE dCur;

						--
						-- Insert records into fhsmIndexOperationalReport
						--
						BEGIN
							--
							-- Delete if already processed
							--
							BEGIN
								DELETE ior
								FROM dbo.fhsmIndexOperationalReport AS ior WHERE (ior.TimestampUTC = @nowUTC);
							END;

							--
							-- Process delta
							--
							INSERT INTO dbo.fhsmIndexOperationalReport(
								LeafInsertCount, LeafDeleteCount, LeafUpdateCount, LeafGhostCount
								,NonleafInsertCount, NonleafDeleteCount, NonleafUpdateCount
								,LeafAllocationCount, NonleafAllocationCount
								,LeafPageMergeCount, NonleafPageMergeCount
								,RangeScanCount, SingletonLookupCount, ForwardedFetchCount
								,LOBFetchInPages, LOBFetchInBytes
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
								,TimestampUTC, Timestamp
								,DatabaseName, SchemaName, ObjectName, IndexName
								,Date, TimeKey
								,DatabaseKey, SchemaKey, ObjectKey, IndexKey
							)
							SELECT
								b.DeltaLeafInsertCount AS LeafInsertCount
								,b.DeltaLeafDeleteCount AS LeafDeleteCount
								,b.DeltaLeafUpdateCount AS LeafUpdateCount
								,b.DeltaLeafGhostCount AS LeafGhostCount
								,b.DeltaNonleafInsertCount AS NonleafInsertCount
								,b.DeltaNonleafDeleteCount AS NonleafDeleteCount
								,b.DeltaNonleafUpdateCount AS NonleafUpdateCount
								,b.DeltaLeafAllocationCount AS LeafAllocationCount
								,b.DeltaNonleafAllocationCount AS NonleafAllocationCount
								,b.DeltaLeafPageMergeCount AS LeafPageMergeCount
								,b.DeltaNonleafPageMergeCount AS NonleafPageMergeCount
								,b.DeltaRangeScanCount AS RangeScanCount
								,b.DeltaSingletonLookupCount AS SingletonLookupCount
								,b.DeltaForwardedFetchCount AS ForwardedFetchCount
								,b.DeltaLOBFetchInPages AS LOBFetchInPages
								,b.DeltaLOBFetchInBytes AS LOBFetchInBytes
								,b.DeltaLOBOrphanCreateCount AS LOBOrphanCreateCount
								,b.DeltaLOBOrphanInsertCount AS LOBOrphanInsertCount
								,b.DeltaRowOverflowFetchInPages AS RowOverflowFetchInPages
								,b.DeltaRowOverflowFetchInBytes AS RowOverflowFetchInBytes
								,b.DeltaColumnValuePushOffRowCount AS ColumnValuePushOffRowCount
								,b.DeltaColumnValuePullInRowCount AS ColumnValuePullInRowCount
								,b.DeltaRowLockCount AS RowLockCount
								,b.DeltaRowLockWaitCount AS RowLockWaitCount
								,b.DeltaRowLockWaitInMS AS RowLockWaitInMS
								,b.DeltaPageLockCount AS PageLockCount
								,b.DeltaPageLockWaitCount AS PageLockWaitCount
								,b.DeltaPageLockWaitInMS AS PageLockWaitInMS
								,b.DeltaIndexLockPromotionAttemptCount AS IndexLockPromotionAttemptCount
								,b.DeltaIndexLockPromotionCount AS IndexLockPromotionCount
								,b.DeltaPageLatchWaitCount AS PageLatchWaitCount
								,b.DeltaPageLatchWaitInMS AS PageLatchWaitInMS
								,b.DeltaPageIOLatchWaitCount AS PageIOLatchWaitCount
								,b.DeltaPageIOLatchWaitInMS AS PageIOLatchWaitInMS
								,b.DeltaTreePageLatchWaitCount AS TreePageLatchWaitCount
								,b.DeltaTreePageLatchWaitInMS AS TreePageLatchWaitInMS
								,b.DeltaTreePageIOLatchWaitCount AS TreePageIOLatchWaitCount
								,b.DeltaTreePageIOLatchWaitInMS AS TreePageIOLatchWaitInMS
								,b.DeltaPageCompressionAttemptCount AS PageCompressionAttemptCount
								,b.DeltaPageCompressionSuccessCount AS PageCompressionSuccessCount
								,b.DeltaVersionGeneratedInrow AS VersionGeneratedInrow
								,b.DeltaVersionGeneratedOffrow AS VersionGeneratedOffrow
								,b.DeltaGhostVersionInrow AS GhostVersionInrow
								,b.DeltaGhostVersionOffrow AS GhostVersionOffrow
								,b.DeltaInsertOverGhostVersionInrow AS InsertOverGhostVersionInrow
								,b.DeltaInsertOverGhostVersionOffrow AS InsertOverGhostVersionOffrow
								,b.TimestampUTC
								,b.Timestamp
								,b.DatabaseName
								,b.SchemaName
								,b.ObjectName
								,b.IndexName
								,CAST(b.Timestamp AS date) AS Date
								,(DATEPART(HOUR, b.Timestamp) * 60 * 60) + (DATEPART(MINUTE, b.Timestamp) * 60) + (DATEPART(SECOND, b.Timestamp)) AS TimeKey
								,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(b.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
								,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(b.DatabaseName, b.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
								,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(b.DatabaseName, b.SchemaName, b.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
								,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(b.DatabaseName, b.SchemaName, b.ObjectName, COALESCE(b.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
							FROM (
								SELECT
									CASE
										WHEN (a.PreviousLeafInsertCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL													-- Ignore 1. data set - Yes we loose one data set but better than having visuals showing very high data
										WHEN (a.PreviousLeafInsertCount > a.LeafInsertCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.LeafInsertCount		-- Either has the counters had an overflow or the server har been restarted
										ELSE a.LeafInsertCount - a.PreviousLeafInsertCount																								-- Difference
									END AS DeltaLeafInsertCount
									,CASE
										WHEN (a.PreviousLeafDeleteCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousLeafDeleteCount > a.LeafDeleteCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.LeafDeleteCount
										ELSE a.LeafDeleteCount - a.PreviousLeafDeleteCount
									END AS DeltaLeafDeleteCount
									,CASE
										WHEN (a.PreviousLeafUpdateCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousLeafUpdateCount > a.LeafUpdateCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.LeafUpdateCount
										ELSE a.LeafUpdateCount - a.PreviousLeafUpdateCount
									END AS DeltaLeafUpdateCount
									,CASE
										WHEN (a.PreviousLeafGhostCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousLeafGhostCount > a.LeafGhostCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.LeafGhostCount
										ELSE a.LeafGhostCount - a.PreviousLeafGhostCount
									END AS DeltaLeafGhostCount
									,CASE
										WHEN (a.PreviousNonleafInsertCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousNonleafInsertCount > a.NonleafInsertCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.NonleafInsertCount
										ELSE a.NonleafInsertCount - a.PreviousNonleafInsertCount
									END AS DeltaNonleafInsertCount
									,CASE
										WHEN (a.PreviousNonleafDeleteCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousNonleafDeleteCount > a.NonleafDeleteCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.NonleafDeleteCount
										ELSE a.NonleafDeleteCount - a.PreviousNonleafDeleteCount
									END AS DeltaNonleafDeleteCount
									,CASE
										WHEN (a.PreviousNonleafUpdateCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousNonleafUpdateCount > a.NonleafUpdateCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.NonleafUpdateCount
										ELSE a.NonleafUpdateCount - a.PreviousNonleafUpdateCount
									END AS DeltaNonleafUpdateCount
									,CASE
										WHEN (a.PreviousLeafAllocationCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousLeafAllocationCount > a.LeafAllocationCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.LeafAllocationCount
										ELSE a.LeafAllocationCount - a.PreviousLeafAllocationCount
									END AS DeltaLeafAllocationCount
									,CASE
										WHEN (a.PreviousNonleafAllocationCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousNonleafAllocationCount > a.NonleafAllocationCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.NonleafAllocationCount
										ELSE a.NonleafAllocationCount - a.PreviousNonleafAllocationCount
									END AS DeltaNonleafAllocationCount
									,CASE
										WHEN (a.PreviousLeafPageMergeCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousLeafPageMergeCount > a.LeafPageMergeCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.LeafPageMergeCount
										ELSE a.LeafPageMergeCount - a.PreviousLeafPageMergeCount
									END AS DeltaLeafPageMergeCount
									,CASE
										WHEN (a.PreviousNonleafPageMergeCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousNonleafPageMergeCount > a.NonleafPageMergeCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.NonleafPageMergeCount
										ELSE a.NonleafPageMergeCount - a.PreviousNonleafPageMergeCount
									END AS DeltaNonleafPageMergeCount
									,CASE
										WHEN (a.PreviousRangeScanCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousRangeScanCount > a.RangeScanCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.RangeScanCount
										ELSE a.RangeScanCount - a.PreviousRangeScanCount
									END AS DeltaRangeScanCount
									,CASE
										WHEN (a.PreviousSingletonLookupCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousSingletonLookupCount > a.SingletonLookupCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.SingletonLookupCount
										ELSE a.SingletonLookupCount - a.PreviousSingletonLookupCount
									END AS DeltaSingletonLookupCount
									,CASE
										WHEN (a.PreviousForwardedFetchCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousForwardedFetchCount > a.ForwardedFetchCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.ForwardedFetchCount
										ELSE a.ForwardedFetchCount - a.PreviousForwardedFetchCount
									END AS DeltaForwardedFetchCount
									,CASE
										WHEN (a.PreviousLOBFetchInPages IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousLOBFetchInPages > a.LOBFetchInPages) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.LOBFetchInPages
										ELSE a.LOBFetchInPages - a.PreviousLOBFetchInPages
									END AS DeltaLOBFetchInPages
									,CASE
										WHEN (a.PreviousLOBFetchInBytes IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousLOBFetchInBytes > a.LOBFetchInBytes) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.LOBFetchInBytes
										ELSE a.LOBFetchInBytes - a.PreviousLOBFetchInBytes
									END AS DeltaLOBFetchInBytes
									,CASE
										WHEN (a.PreviousLOBOrphanCreateCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousLOBOrphanCreateCount > a.LOBOrphanCreateCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.LOBOrphanCreateCount
										ELSE a.LOBOrphanCreateCount - a.PreviousLOBOrphanCreateCount
									END AS DeltaLOBOrphanCreateCount
									,CASE
										WHEN (a.PreviousLOBOrphanInsertCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousLOBOrphanInsertCount > a.LOBOrphanInsertCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.LOBOrphanInsertCount
										ELSE a.LOBOrphanInsertCount - a.PreviousLOBOrphanInsertCount
									END AS DeltaLOBOrphanInsertCount
									,CASE
										WHEN (a.PreviousRowOverflowFetchInPages IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousRowOverflowFetchInPages > a.RowOverflowFetchInPages) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.RowOverflowFetchInPages
										ELSE a.RowOverflowFetchInPages - a.PreviousRowOverflowFetchInPages
									END AS DeltaRowOverflowFetchInPages
									,CASE
										WHEN (a.PreviousRowOverflowFetchInBytes IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousRowOverflowFetchInBytes > a.RowOverflowFetchInBytes) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.RowOverflowFetchInBytes
										ELSE a.RowOverflowFetchInBytes - a.PreviousRowOverflowFetchInBytes
									END AS DeltaRowOverflowFetchInBytes
									,CASE
										WHEN (a.PreviousColumnValuePushOffRowCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousColumnValuePushOffRowCount > a.ColumnValuePushOffRowCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.ColumnValuePushOffRowCount
										ELSE a.ColumnValuePushOffRowCount - a.PreviousColumnValuePushOffRowCount
									END AS DeltaColumnValuePushOffRowCount
									,CASE
										WHEN (a.PreviousColumnValuePullInRowCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousColumnValuePullInRowCount > a.ColumnValuePullInRowCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.ColumnValuePullInRowCount
										ELSE a.ColumnValuePullInRowCount - a.PreviousColumnValuePullInRowCount
									END AS DeltaColumnValuePullInRowCount
									,CASE
										WHEN (a.PreviousRowLockCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousRowLockCount > a.RowLockCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.RowLockCount
										ELSE a.RowLockCount - a.PreviousRowLockCount
									END AS DeltaRowLockCount
									,CASE
										WHEN (a.PreviousRowLockWaitCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousRowLockWaitCount > a.RowLockWaitCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.RowLockWaitCount
										ELSE a.RowLockWaitCount - a.PreviousRowLockWaitCount
									END AS DeltaRowLockWaitCount
									,CASE
										WHEN (a.PreviousRowLockWaitInMS IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousRowLockWaitInMS > a.RowLockWaitInMS) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.RowLockWaitInMS
										ELSE a.RowLockWaitInMS - a.PreviousRowLockWaitInMS
									END AS DeltaRowLockWaitInMS
									,CASE
										WHEN (a.PreviousPageLockCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousPageLockCount > a.PageLockCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.PageLockCount
										ELSE a.PageLockCount - a.PreviousPageLockCount
									END AS DeltaPageLockCount
									,CASE
										WHEN (a.PreviousPageLockWaitCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousPageLockWaitCount > a.PageLockWaitCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.PageLockWaitCount
										ELSE a.PageLockWaitCount - a.PreviousPageLockWaitCount
									END AS DeltaPageLockWaitCount
									,CASE
										WHEN (a.PreviousPageLockWaitInMS IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousPageLockWaitInMS > a.PageLockWaitInMS) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.PageLockWaitInMS
										ELSE a.PageLockWaitInMS - a.PreviousPageLockWaitInMS
									END AS DeltaPageLockWaitInMS
									,CASE
										WHEN (a.PreviousIndexLockPromotionAttemptCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousIndexLockPromotionAttemptCount > a.IndexLockPromotionAttemptCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.IndexLockPromotionAttemptCount
										ELSE a.IndexLockPromotionAttemptCount - a.PreviousIndexLockPromotionAttemptCount
									END AS DeltaIndexLockPromotionAttemptCount
									,CASE
										WHEN (a.PreviousIndexLockPromotionCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousIndexLockPromotionCount > a.IndexLockPromotionCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.IndexLockPromotionCount
										ELSE a.IndexLockPromotionCount - a.PreviousIndexLockPromotionCount
									END AS DeltaIndexLockPromotionCount
									,CASE
										WHEN (a.PreviousPageLatchWaitCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousPageLatchWaitCount > a.PageLatchWaitCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.PageLatchWaitCount
										ELSE a.PageLatchWaitCount - a.PreviousPageLatchWaitCount
									END AS DeltaPageLatchWaitCount
									,CASE
										WHEN (a.PreviousPageLatchWaitInMS IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousPageLatchWaitInMS > a.PageLatchWaitInMS) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.PageLatchWaitInMS
										ELSE a.PageLatchWaitInMS - a.PreviousPageLatchWaitInMS
									END AS DeltaPageLatchWaitInMS
									,CASE
										WHEN (a.PreviousPageIOLatchWaitCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousPageIOLatchWaitCount > a.PageIOLatchWaitCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.PageIOLatchWaitCount
										ELSE a.PageIOLatchWaitCount - a.PreviousPageIOLatchWaitCount
									END AS DeltaPageIOLatchWaitCount
									,CASE
										WHEN (a.PreviousPageIOLatchWaitInMS IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousPageIOLatchWaitInMS > a.PageIOLatchWaitInMS) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.PageIOLatchWaitInMS
										ELSE a.PageIOLatchWaitInMS - a.PreviousPageIOLatchWaitInMS
									END AS DeltaPageIOLatchWaitInMS
									,CASE
										WHEN (a.PreviousTreePageLatchWaitCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousTreePageLatchWaitCount > a.TreePageLatchWaitCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.TreePageLatchWaitCount
										ELSE a.TreePageLatchWaitCount - a.PreviousTreePageLatchWaitCount
									END AS DeltaTreePageLatchWaitCount
									,CASE
										WHEN (a.PreviousTreePageLatchWaitInMS IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousTreePageLatchWaitInMS > a.TreePageLatchWaitInMS) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.TreePageLatchWaitInMS
										ELSE a.TreePageLatchWaitInMS - a.PreviousTreePageLatchWaitInMS
									END AS DeltaTreePageLatchWaitInMS
									,CASE
										WHEN (a.PreviousTreePageIOLatchWaitCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousTreePageIOLatchWaitCount > a.TreePageIOLatchWaitCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.TreePageIOLatchWaitCount
										ELSE a.TreePageIOLatchWaitCount - a.PreviousTreePageIOLatchWaitCount
									END AS DeltaTreePageIOLatchWaitCount
									,CASE
										WHEN (a.PreviousTreePageIOLatchWaitInMS IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousTreePageIOLatchWaitInMS > a.TreePageIOLatchWaitInMS) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.TreePageIOLatchWaitInMS
										ELSE a.TreePageIOLatchWaitInMS - a.PreviousTreePageIOLatchWaitInMS
									END AS DeltaTreePageIOLatchWaitInMS
									,CASE
										WHEN (a.PreviousPageCompressionAttemptCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousPageCompressionAttemptCount > a.PageCompressionAttemptCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.PageCompressionAttemptCount
										ELSE a.PageCompressionAttemptCount - a.PreviousPageCompressionAttemptCount
									END AS DeltaPageCompressionAttemptCount
									,CASE
										WHEN (a.PreviousPageCompressionSuccessCount IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousPageCompressionSuccessCount > a.PageCompressionSuccessCount) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.PageCompressionSuccessCount
										ELSE a.PageCompressionSuccessCount - a.PreviousPageCompressionSuccessCount
									END AS DeltaPageCompressionSuccessCount
									,CASE
										WHEN (a.PreviousVersionGeneratedInrow IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousVersionGeneratedInrow > a.VersionGeneratedInrow) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.VersionGeneratedInrow
										ELSE a.VersionGeneratedInrow - a.PreviousVersionGeneratedInrow
									END AS DeltaVersionGeneratedInrow
									,CASE
										WHEN (a.PreviousVersionGeneratedOffrow IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousVersionGeneratedOffrow > a.VersionGeneratedOffrow) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.VersionGeneratedOffrow
										ELSE a.VersionGeneratedOffrow - a.PreviousVersionGeneratedOffrow
									END AS DeltaVersionGeneratedOffrow
									,CASE
										WHEN (a.PreviousGhostVersionInrow IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousGhostVersionInrow > a.GhostVersionInrow) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.GhostVersionInrow
										ELSE a.GhostVersionInrow - a.PreviousGhostVersionInrow
									END AS DeltaGhostVersionInrow
									,CASE
										WHEN (a.PreviousGhostVersionOffrow IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousGhostVersionOffrow > a.GhostVersionOffrow) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.GhostVersionOffrow
										ELSE a.GhostVersionOffrow - a.PreviousGhostVersionOffrow
									END AS DeltaGhostVersionOffrow
									,CASE
										WHEN (a.PreviousInsertOverGhostVersionInrow IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousInsertOverGhostVersionInrow > a.InsertOverGhostVersionInrow) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.InsertOverGhostVersionInrow
										ELSE a.InsertOverGhostVersionInrow - a.PreviousInsertOverGhostVersionInrow
									END AS DeltaInsertOverGhostVersionInrow
									,CASE
										WHEN (a.PreviousInsertOverGhostVersionOffrow IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
										WHEN (a.PreviousInsertOverGhostVersionOffrow > a.InsertOverGhostVersionOffrow) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.InsertOverGhostVersionOffrow
										ELSE a.InsertOverGhostVersionOffrow - a.PreviousInsertOverGhostVersionOffrow
									END AS DeltaInsertOverGhostVersionOffrow
									,a.TimestampUTC
									,a.Timestamp
									,a.DatabaseName
									,a.SchemaName
									,a.ObjectName
									,a.IndexName
								FROM (
									SELECT
										curIO.LeafInsertCount
										,prevIO.LeafInsertCount AS PreviousLeafInsertCount
										,curIO.LeafDeleteCount
										,prevIO.LeafDeleteCount AS PreviousLeafDeleteCount
										,curIO.LeafUpdateCount
										,prevIO.LeafUpdateCount AS PreviousLeafUpdateCount
										,curIO.LeafGhostCount
										,prevIO.LeafGhostCount AS PreviousLeafGhostCount
										,curIO.NonleafInsertCount
										,prevIO.NonleafInsertCount AS PreviousNonleafInsertCount
										,curIO.NonleafDeleteCount
										,prevIO.NonleafDeleteCount AS PreviousNonleafDeleteCount
										,curIO.NonleafUpdateCount
										,prevIO.NonleafUpdateCount AS PreviousNonleafUpdateCount
										,curIO.LeafAllocationCount
										,prevIO.LeafAllocationCount AS PreviousLeafAllocationCount
										,curIO.NonleafAllocationCount
										,prevIO.NonleafAllocationCount AS PreviousNonleafAllocationCount
										,curIO.LeafPageMergeCount
										,prevIO.LeafPageMergeCount AS PreviousLeafPageMergeCount
										,curIO.NonleafPageMergeCount
										,prevIO.NonleafPageMergeCount AS PreviousNonleafPageMergeCount
										,curIO.RangeScanCount
										,prevIO.RangeScanCount AS PreviousRangeScanCount
										,curIO.SingletonLookupCount
										,prevIO.SingletonLookupCount AS PreviousSingletonLookupCount
										,curIO.ForwardedFetchCount
										,prevIO.ForwardedFetchCount AS PreviousForwardedFetchCount
										,curIO.LOBFetchInPages
										,prevIO.LOBFetchInPages AS PreviousLOBFetchInPages
										,curIO.LOBFetchInBytes
										,prevIO.LOBFetchInBytes AS PreviousLOBFetchInBytes
										,curIO.LOBOrphanCreateCount
										,prevIO.LOBOrphanCreateCount AS PreviousLOBOrphanCreateCount
										,curIO.LOBOrphanInsertCount
										,prevIO.LOBOrphanInsertCount AS PreviousLOBOrphanInsertCount
										,curIO.RowOverflowFetchInPages
										,prevIO.RowOverflowFetchInPages AS PreviousRowOverflowFetchInPages
										,curIO.RowOverflowFetchInBytes
										,prevIO.RowOverflowFetchInBytes AS PreviousRowOverflowFetchInBytes
										,curIO.ColumnValuePushOffRowCount
										,prevIO.ColumnValuePushOffRowCount AS PreviousColumnValuePushOffRowCount
										,curIO.ColumnValuePullInRowCount
										,prevIO.ColumnValuePullInRowCount AS PreviousColumnValuePullInRowCount
										,curIO.RowLockCount
										,prevIO.RowLockCount AS PreviousRowLockCount
										,curIO.RowLockWaitCount
										,prevIO.RowLockWaitCount AS PreviousRowLockWaitCount
										,curIO.RowLockWaitInMS
										,prevIO.RowLockWaitInMS AS PreviousRowLockWaitInMS
										,curIO.PageLockCount
										,prevIO.PageLockCount AS PreviousPageLockCount
										,curIO.PageLockWaitCount
										,prevIO.PageLockWaitCount AS PreviousPageLockWaitCount
										,curIO.PageLockWaitInMS
										,prevIO.PageLockWaitInMS AS PreviousPageLockWaitInMS
										,curIO.IndexLockPromotionAttemptCount
										,prevIO.IndexLockPromotionAttemptCount AS PreviousIndexLockPromotionAttemptCount
										,curIO.IndexLockPromotionCount
										,prevIO.IndexLockPromotionCount AS PreviousIndexLockPromotionCount
										,curIO.PageLatchWaitCount
										,prevIO.PageLatchWaitCount AS PreviousPageLatchWaitCount
										,curIO.PageLatchWaitInMS
										,prevIO.PageLatchWaitInMS AS PreviousPageLatchWaitInMS
										,curIO.PageIOLatchWaitCount
										,prevIO.PageIOLatchWaitCount AS PreviousPageIOLatchWaitCount
										,curIO.PageIOLatchWaitInMS
										,prevIO.PageIOLatchWaitInMS AS PreviousPageIOLatchWaitInMS
										,curIO.TreePageLatchWaitCount
										,prevIO.TreePageLatchWaitCount AS PreviousTreePageLatchWaitCount
										,curIO.TreePageLatchWaitInMS
										,prevIO.TreePageLatchWaitInMS AS PreviousTreePageLatchWaitInMS
										,curIO.TreePageIOLatchWaitCount
										,prevIO.TreePageIOLatchWaitCount AS PreviousTreePageIOLatchWaitCount
										,curIO.TreePageIOLatchWaitInMS
										,prevIO.TreePageIOLatchWaitInMS AS PreviousTreePageIOLatchWaitInMS
										,curIO.PageCompressionAttemptCount
										,prevIO.PageCompressionAttemptCount AS PreviousPageCompressionAttemptCount
										,curIO.PageCompressionSuccessCount
										,prevIO.PageCompressionSuccessCount AS PreviousPageCompressionSuccessCount
										,curIO.VersionGeneratedInrow
										,prevIO.VersionGeneratedInrow AS PreviousVersionGeneratedInrow
										,curIO.VersionGeneratedOffrow
										,prevIO.VersionGeneratedOffrow AS PreviousVersionGeneratedOffrow
										,curIO.GhostVersionInrow
										,prevIO.GhostVersionInrow AS PreviousGhostVersionInrow
										,curIO.GhostVersionOffrow
										,prevIO.GhostVersionOffrow AS PreviousGhostVersionOffrow
										,curIO.InsertOverGhostVersionInrow
										,prevIO.InsertOverGhostVersionInrow AS PreviousInsertOverGhostVersionInrow
										,curIO.InsertOverGhostVersionOffrow
										,prevIO.InsertOverGhostVersionOffrow AS PreviousInsertOverGhostVersionOffrow
										,curIO.LastSQLServiceRestart
										,prevIO.LastSQLServiceRestart AS PreviousLastSQLServiceRestart
										,curIO.TimestampUTC
										,curIO.Timestamp
										,curIO.DatabaseName
										,curIO.SchemaName
										,curIO.ObjectName
										,curIO.IndexName
									FROM dbo.fhsmIndexOperational AS curIO
									OUTER APPLY (
										SELECT TOP (1) io.*
										FROM dbo.fhsmIndexOperational AS io
										WHERE
											(io.DatabaseName = curIO.DatabaseName)
											AND (io.SchemaName = curIO.SchemaName)
											AND (io.ObjectName = curIO.ObjectName)
											AND ((io.IndexName = curIO.IndexName) OR ((io.IndexName IS NULL) AND (curIO.IndexName IS NULL)))
											AND (io.TimestampUTC < curIO.TimestampUTC)
										ORDER BY io.TimestampUTC DESC
									) AS prevIO
									WHERE (curIO.TimestampUTC = @nowUTC)
								) AS a
							) AS b;
						END;
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
		retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter) AS(
			SELECT
				1
				,'dbo.fhsmIndexOperational'
				,1
				,'TimestampUTC'
				,1
				,90
				,NULL

			UNION ALL

			SELECT
				1
				,'dbo.fhsmIndexOperationalReport'
				,1
				,'TimestampUTC'
				,1
				,90
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
				@enableIndexOperational
				,'Index operational'
				,PARSENAME('dbo.fhsmSPIndexOperational', 1)
				,4 * 60 * 60
				,CAST('1900-1-1T06:00:00.0000' AS datetime2(0))
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))
				,1, 1, 1, 1, 1, 1, 1
				,'@Databases = ''USER_DATABASES, msdb'''
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
			,SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4
			,OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4
		) AS (
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
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmIndexOperational';
	END;
END;
