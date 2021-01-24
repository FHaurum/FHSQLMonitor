--SET STATISTICS IO ON;
--SET STATISTICS TIME ON;

--TRUNCATE TABLE dbo.fhsmIndexOperationalReport;
--GO

SET NOCOUNT ON;

DECLARE @message nvarchar(max);
DECLARE @nowUTC datetime;

SET @message = CONVERT(nvarchar, SYSUTCDATETIME(), 126) + ': Start processing fhsmIndexOperational';
RAISERROR(@message, 0, 1) WITH NOWAIT;

WHILE (1 = 1)
BEGIN
	SET @message = CONVERT(nvarchar, SYSUTCDATETIME(), 126) + ': going to find a @nowUTC';
	RAISERROR(@message, 0, 1) WITH NOWAIT;

	SET @nowUTC = (
		SELECT TOP (1) distIO.TimestampUTC
		FROM (
			SELECT DISTINCT io.TimestampUTC
			FROM dbo.fhsmIndexOperational AS io
		) AS distIO
		WHERE NOT EXISTS (
			SELECT *
			FROM dbo.fhsmIndexOperationalReport AS ior
			WHERE (ior.TimestampUTC = distIO.TimestampUTC)
		)
		ORDER BY distIO.TimestampUTC
	);

	IF (@nowUTC IS NULL)
	BEGIN
		SET @message = CONVERT(nvarchar, SYSUTCDATETIME(), 126) + ': no more dates found to be processed';
		RAISERROR(@message, 0, 1) WITH NOWAIT;
		BREAK;
	END;

	SET @message = CONVERT(nvarchar, SYSUTCDATETIME(), 126) + ': ready to process ' + CONVERT(nvarchar, @nowUTC, 126);
	RAISERROR(@message, 0, 1) WITH NOWAIT;

	BEGIN
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
			,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(b.DatabaseName, b.SchemaName, b.ObjectName, COALESCE(b.IndexName, 'N.A.'), DEFAULT, DEFAULT) AS k) AS IndexKey
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

	SET @message = CONVERT(nvarchar, SYSUTCDATETIME(), 126) + ': going to sleep before processing next date';
	RAISERROR(@message, 0, 1) WITH NOWAIT;

	WAITFOR DELAY '00:00:01';
END;
