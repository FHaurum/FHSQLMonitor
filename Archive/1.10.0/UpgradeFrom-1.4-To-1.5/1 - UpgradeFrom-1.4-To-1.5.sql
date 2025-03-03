--
-- Disable agent job
--

--
-- Verify that the agent is not executing (Job Activity Monitor)
--

--
-- Backup before upgrade from 1.4 to 1.5 - SQL2012 default path
--
USE [master];
GO
BACKUP DATABASE [FHSQLMonitor]
	TO DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Backup\FHSQLMonitor-BeforeUpgradeFrom1.4To1.5.bak'
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
-- Update the table dbo.fhsmStatisticsAge
--
ALTER TABLE dbo.fhsmStatisticsAge ADD IsHypothetical bit NULL;
GO

--
-- Update the table dbo.fhsmStatisticsAgeIncremental
--
ALTER TABLE dbo.fhsmStatisticsAgeIncremental ADD IsHypothetical bit NULL;
GO

--
-- Update the table dbo.fhsmTableSize
--
ALTER TABLE dbo.fhsmTableSize ALTER COLUMN IndexName nvarchar(128) NULL;
GO

--
-- Update the table dbo.fhsmTraceFlags
--
ALTER TABLE dbo.fhsmTraceFlags ALTER COLUMN URL nvarchar(max) NULL;
GO

--
-- Run the updated scripts
--
-- _Install-FHSQLMonitor.sql
-- BackupStatus.sql
-- DatabaseIO.sql
-- DatabaseSize.sql
-- IndexOperational.sql
-- IndexPhysical.sql
-- IndexUsage.sql
-- InstanceState.sql
-- StatisticsAge.sql
-- TableSize.sql
--

--
-- Enable agent job
--
