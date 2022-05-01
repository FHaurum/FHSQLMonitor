--
-- Disable agent job
--

--
-- Verify that the agent is not executing (Job Activity Monitor)
--

--
-- Backup before upgrade from 1.9 to 1.10 - SQL2012 default path
--
USE [master];
GO
BACKUP DATABASE [FHSQLMonitor]
	TO DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Backup\FHSQLMonitor-BeforeUpgradeFrom1.9To1.10.bak'
	WITH COPY_ONLY
		,NOFORMAT
		,INIT
		,NAME = N'FHSQLMonitor-Full Database Backup'
		,SKIP
		,NOREWIND
		,NOUNLOAD
		,COMPRESSION
		,STATS = 5
		,CHECKSUM;
GO

--
-- Switch to the database to be upgraded
--
USE [FHSQLMonitor];
GO

--
-- Remove records for InstantState if they are standard (not modified by user)
--
BEGIN
	IF EXISTS (
		SELECT *
		FROM dbo.fhsmSchedules AS s
		WHERE
			(s.Enabled = 1)
			AND (s.Name = 'Instance State')
			AND (s.Task = PARSENAME('dbo.fhsmSPInstanceState', 1))
			AND (s.ExecutionDelaySec = 12 * 60 * 60)
			AND (s.FromTime = CAST('1900-1-1T08:00:00.0000' AS time(0)))
			AND (s.ToTime = CAST('1900-1-1T09:00:00.0000' AS time(0)))
			AND (s.Monday = 1)
			AND (s.Tuesday = 1)
			AND (s.Wednesday = 1)
			AND (s.Thursday = 1)
			AND (s.Friday = 1)
			AND (s.Saturday = 1)
			AND (s.Sunday = 1)
			AND (s.Parameters IS NULL)
	)
	BEGIN
		DELETE s
		FROM dbo.fhsmSchedules AS s
		WHERE (s.Name = 'Instance State') AND (s.Task = PARSENAME('dbo.fhsmSPInstanceState', 1));
	END;
END;

--
-- Remove records for PerfmonStatistics if they are standard (not modified by user)
--
BEGIN
	IF EXISTS (
		SELECT *
		FROM dbo.fhsmRetentions AS r
		WHERE
			(r.Enabled = 1)
			AND (r.TableName = 'dbo.fhsmPerfmonStatistics')
			AND (r.Sequence = 1)
			AND (r.TimeColumn = 'TimestampUTC')
			AND (r.IsUtc = 1)
			AND (r.Days = 90)
			AND (r.Filter IS NULL)
	)
	BEGIN
		DELETE r
		FROM dbo.fhsmRetentions AS r
		WHERE (r.TableName = 'dbo.fhsmPerfmonStatistics');
	END;

	IF EXISTS (
		SELECT *
		FROM dbo.fhsmSchedules AS s
		WHERE
			(s.Enabled = 1)
			AND (s.Name = 'Performance statistics')
			AND (s.Task = PARSENAME('dbo.fhsmSPPerfmonStatistics', 1))
			AND (s.ExecutionDelaySec = 15 * 60)
			AND (s.FromTime = CAST('1900-1-1T00:00:00.0000' AS time(0)))
			AND (s.ToTime = CAST('1900-1-1T23:59:59.0000' AS time(0)))
			AND (s.Monday = 1)
			AND (s.Tuesday = 1)
			AND (s.Wednesday = 1)
			AND (s.Thursday = 1)
			AND (s.Friday = 1)
			AND (s.Saturday = 1)
			AND (s.Sunday = 1)
			AND (s.Parameters IS NULL)
	)
	BEGIN
		DELETE s
		FROM dbo.fhsmSchedules AS s
		WHERE (s.Name = 'Performance statistics') AND (s.Task = PARSENAME('dbo.fhsmSPPerfmonStatistics', 1));
	END;
END;

--
-- Run the updated scripts in the order listed here
--
-- InstanceState.sql
-- PerfmonStatistics.sql
--

--
-- Enable agent job
--
