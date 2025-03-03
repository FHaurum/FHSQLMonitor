--SET STATISTICS IO ON;
--SET STATISTICS TIME ON;

--TRUNCATE TABLE dbo.fhsmQueryStatisticsReport;
--GO

SET NOCOUNT ON;

DECLARE @maxDate datetime;
DECLARE @message nvarchar(max);
DECLARE @minDate datetime;
DECLARE @numberOfTimestamps int;
DECLARE @numberOfTimestampsProcessed int;
DECLARE @numberOfTimestampsToBeProcessed int;

SET @numberOfTimestamps = 100;
SET @numberOfTimestampsProcessed = 0;

IF OBJECT_ID('tempdb..#datesToProcess') IS NULL
BEGIN
	CREATE TABLE #datesToProcess(
		curTimestampUTC datetime
		,prevTimestampUTC datetime
	);
END;

SET @message = CONVERT(nvarchar, SYSUTCDATETIME(), 126) + ': Start processing fhsmQueryStatistics in batches of ' + CAST(@numberOfTimestamps AS nvarchar) + ' dates';
RAISERROR(@message, 0, 1) WITH NOWAIT;

WHILE (1 = 1)
BEGIN
	TRUNCATE TABLE #datesToProcess;

	WITH
	dates AS (
		SELECT
			a.TimestampUTC
			,a._Rnk_
		FROM (
			SELECT
				distTS.TimestampUTC
				,ROW_NUMBER() OVER(ORDER BY distTS.TimestampUTC DESC) AS _Rnk_
			FROM (
				SELECT DISTINCT qs.TimestampUTC
				FROM dbo.fhsmQueryStatistics AS qs
			) AS distTS
		) AS a
	)
	,pairedDates AS (
		SELECT
			curDates.TimestampUTC AS curTimestampUTC
			,prevDates.TimestampUTC AS prevTimestampUTC
		FROM dates AS curDates
		INNER JOIN dates AS prevDates ON (prevDates._Rnk_ = (curDates._Rnk_ + 1))
	)
	,datesToProcess AS (
		SELECT TOP (@numberOfTimestamps) *
		FROM pairedDates AS pd
		WHERE (pd.curTimestampUTC NOT IN (
			SELECT
				DISTINCT
				qsd.TimestampUTC
			FROM dbo.fhsmQueryStatisticsReport AS qsd
		))
		ORDER BY pd.curTimestampUTC
	)
	INSERT INTO #datesToProcess(curTimestampUTC, prevTimestampUTC)
	SELECT dtp.curTimestampUTC, dtp.prevTimestampUTC
	FROM datesToProcess AS dtp;

	IF NOT EXISTS(SELECT * FROM #datesToProcess)
	BEGIN
		SET @message = CONVERT(nvarchar, SYSUTCDATETIME(), 126) + ': no more dates found to be processed';
		RAISERROR(@message, 0, 1) WITH NOWAIT;
		BREAK;
	END;

	SELECT
		@numberOfTimestampsToBeProcessed = COUNT(dtp.curTimestampUTC)
		,@minDate = MIN(dtp.curTimestampUTC)
		,@maxDate = MAX(dtp.curTimestampUTC)
	FROM #datesToProcess AS dtp;

	SET @message = CONVERT(nvarchar, SYSUTCDATETIME(), 126) + ': ready to process ' + CAST(@numberOfTimestampsToBeProcessed AS nvarchar) + ' batches from ' + CONVERT(nvarchar, @minDate, 126) + ' to ' + CONVERT(nvarchar, @maxDate, 126);
	RAISERROR(@message, 0, 1) WITH NOWAIT;

	WITH
	summarizedQS AS (
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
		WHERE (qs.TimestampUTC IN (
			SELECT dtp.curTimestampUTC AS TimestampUTC FROM #datesToProcess AS dtp
			UNION
			SELECT dtp.prevTimestampUTC AS TimestampUTC FROM #datesToProcess AS dtp
		))
		GROUP BY
			qs.DatabaseName
			,qs.QueryHash
			,qs.PlanHandle
			,qs.CreationTime
			,qs.TimestampUTC
			,qs.Timestamp
			,qs.LastSQLServiceRestart
	)
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
		FROM #datesToProcess AS dtp
		INNER JOIN summarizedQS AS curQS ON (curQS.TimestampUTC = dtp.curTimestampUTC)
		LEFT OUTER JOIN summarizedQS AS prevQS ON (prevQS.TimestampUTC = dtp.prevTimestampUTC)
			AND (prevQS.DatabaseName = curQS.DatabaseName)
			AND (prevQS.QueryHash = curQS.QueryHash)
			AND (prevQS.PlanHandle = curQS.PlanHandle)
			AND (prevQS.CreationTime = curQS.CreationTime)
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

	SET @numberOfTimestampsProcessed += @numberOfTimestampsToBeProcessed;

	SET @message = CONVERT(nvarchar, SYSUTCDATETIME(), 126) + ': going to sleep before processing next batch - @numberOfTimestampsProcessed:' + CAST(@numberOfTimestampsProcessed AS nvarchar);
	RAISERROR(@message, 0, 1) WITH NOWAIT;

	WAITFOR DELAY '00:00:30';
END;
