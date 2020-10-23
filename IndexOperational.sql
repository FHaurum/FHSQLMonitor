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
					,b.Date
					,b.TimeKey
					,b.DatabaseKey
					,b.SchemaKey
					,b.ObjectKey
					,b.IndexKey
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
						,a.Date
						,a.TimeKey
						,a.DatabaseKey
						,a.SchemaKey
						,a.ObjectKey
						,a.IndexKey
					FROM (
						SELECT
							io.LeafInsertCount
							,LAG(io.LeafInsertCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousLeafInsertCount
							,io.LeafDeleteCount
							,LAG(io.LeafDeleteCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousLeafDeleteCount
							,io.LeafUpdateCount
							,LAG(io.LeafUpdateCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousLeafUpdateCount
							,io.LeafGhostCount
							,LAG(io.LeafGhostCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousLeafGhostCount
							,io.NonleafInsertCount
							,LAG(io.NonleafInsertCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousNonleafInsertCount
							,io.NonleafDeleteCount
							,LAG(io.NonleafDeleteCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousNonleafDeleteCount
							,io.NonleafUpdateCount
							,LAG(io.NonleafUpdateCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousNonleafUpdateCount
							,io.LeafAllocationCount
							,LAG(io.LeafAllocationCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousLeafAllocationCount
							,io.NonleafAllocationCount
							,LAG(io.NonleafAllocationCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousNonleafAllocationCount
							,io.LeafPageMergeCount
							,LAG(io.LeafPageMergeCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousLeafPageMergeCount
							,io.NonleafPageMergeCount
							,LAG(io.NonleafPageMergeCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousNonleafPageMergeCount
							,io.RangeScanCount
							,LAG(io.RangeScanCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousRangeScanCount
							,io.SingletonLookupCount
							,LAG(io.SingletonLookupCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousSingletonLookupCount
							,io.ForwardedFetchCount
							,LAG(io.ForwardedFetchCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousForwardedFetchCount
							,io.LOBFetchInPages
							,LAG(io.LOBFetchInPages) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousLOBFetchInPages
							,io.LOBFetchInBytes
							,LAG(io.LOBFetchInBytes) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousLOBFetchInBytes
							,io.LOBOrphanCreateCount
							,LAG(io.LOBOrphanCreateCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousLOBOrphanCreateCount
							,io.LOBOrphanInsertCount
							,LAG(io.LOBOrphanInsertCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousLOBOrphanInsertCount
							,io.RowOverflowFetchInPages
							,LAG(io.RowOverflowFetchInPages) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousRowOverflowFetchInPages
							,io.RowOverflowFetchInBytes
							,LAG(io.RowOverflowFetchInBytes) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousRowOverflowFetchInBytes
							,io.ColumnValuePushOffRowCount
							,LAG(io.ColumnValuePushOffRowCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousColumnValuePushOffRowCount
							,io.ColumnValuePullInRowCount
							,LAG(io.ColumnValuePullInRowCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousColumnValuePullInRowCount
							,io.RowLockCount
							,LAG(io.RowLockCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousRowLockCount
							,io.RowLockWaitCount
							,LAG(io.RowLockWaitCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousRowLockWaitCount
							,io.RowLockWaitInMS
							,LAG(io.RowLockWaitInMS) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousRowLockWaitInMS
							,io.PageLockCount
							,LAG(io.PageLockCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousPageLockCount
							,io.PageLockWaitCount
							,LAG(io.PageLockWaitCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousPageLockWaitCount
							,io.PageLockWaitInMS
							,LAG(io.PageLockWaitInMS) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousPageLockWaitInMS
							,io.IndexLockPromotionAttemptCount
							,LAG(io.IndexLockPromotionAttemptCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousIndexLockPromotionAttemptCount
							,io.IndexLockPromotionCount
							,LAG(io.IndexLockPromotionCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousIndexLockPromotionCount
							,io.PageLatchWaitCount
							,LAG(io.PageLatchWaitCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousPageLatchWaitCount
							,io.PageLatchWaitInMS
							,LAG(io.PageLatchWaitInMS) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousPageLatchWaitInMS
							,io.PageIOLatchWaitCount
							,LAG(io.PageIOLatchWaitCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousPageIOLatchWaitCount
							,io.PageIOLatchWaitInMS
							,LAG(io.PageIOLatchWaitInMS) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousPageIOLatchWaitInMS
							,io.TreePageLatchWaitCount
							,LAG(io.TreePageLatchWaitCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousTreePageLatchWaitCount
							,io.TreePageLatchWaitInMS
							,LAG(io.TreePageLatchWaitInMS) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousTreePageLatchWaitInMS
							,io.TreePageIOLatchWaitCount
							,LAG(io.TreePageIOLatchWaitCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousTreePageIOLatchWaitCount
							,io.TreePageIOLatchWaitInMS
							,LAG(io.TreePageIOLatchWaitInMS) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousTreePageIOLatchWaitInMS
							,io.PageCompressionAttemptCount
							,LAG(io.PageCompressionAttemptCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousPageCompressionAttemptCount
							,io.PageCompressionSuccessCount
							,LAG(io.PageCompressionSuccessCount) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousPageCompressionSuccessCount
							,io.VersionGeneratedInrow
							,LAG(io.VersionGeneratedInrow) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousVersionGeneratedInrow
							,io.VersionGeneratedOffrow
							,LAG(io.VersionGeneratedOffrow) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousVersionGeneratedOffrow
							,io.GhostVersionInrow
							,LAG(io.GhostVersionInrow) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousGhostVersionInrow
							,io.GhostVersionOffrow
							,LAG(io.GhostVersionOffrow) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousGhostVersionOffrow
							,io.InsertOverGhostVersionInrow
							,LAG(io.InsertOverGhostVersionInrow) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousInsertOverGhostVersionInrow
							,io.InsertOverGhostVersionOffrow
							,LAG(io.InsertOverGhostVersionOffrow) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousInsertOverGhostVersionOffrow
							,io.LastSQLServiceRestart
							,LAG(io.LastSQLServiceRestart) OVER(PARTITION BY io.DatabaseName, io.SchemaName, io.ObjectName, io.IndexName ORDER BY io.TimestampUTC) AS PreviousLastSQLServiceRestart
							,CAST(io.Timestamp AS date) AS Date
							,(DATEPART(HOUR, io.Timestamp) * 60 * 60) + (DATEPART(MINUTE, io.Timestamp) * 60) + (DATEPART(SECOND, io.Timestamp)) AS TimeKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(io.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(io.DatabaseName, io.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(io.DatabaseName, io.SchemaName, io.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(io.DatabaseName, io.SchemaName, io.ObjectName, COALESCE(io.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
						FROM dbo.fhsmIndexOperational AS io
					) AS a
				) AS b;
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
				,4 * 60 * 60
				,TIMEFROMPARTS(6, 0, 0, 0, 0)
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
