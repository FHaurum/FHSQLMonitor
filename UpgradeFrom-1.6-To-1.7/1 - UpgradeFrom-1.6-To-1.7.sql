--
-- Disable agent job
--

--
-- Verify that the agent is not executing (Job Activity Monitor)
--

--
-- Backup before upgrade from 1.6 to 1.7 - SQL2012 default path
--
USE [master];
GO
BACKUP DATABASE [FHSQLMonitor]
	TO DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Backup\FHSQLMonitor-BeforeUpgradeFrom1.6To1.7.bak'
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
-- Update the table dbo.fhsmRetentions
--
DELETE r
FROM dbo.fhsmRetentions AS r
WHERE (r.TableName = 'dbo.fhsmQueryStatisticsDelta');
GO
ALTER TABLE [dbo].[fhsmRetentions]
	ADD Sequence tinyint NULL;
GO
UPDATE r
SET r.Sequence = 1
FROM dbo.fhsmRetentions AS r
WHERE (r.Sequence IS NULL);
GO
ALTER TABLE dbo.fhsmRetentions
	DROP CONSTRAINT UQ_fhsmRetentions_TableName;
GO
ALTER TABLE dbo.fhsmRetentions
	ADD CONSTRAINT UQ_fhsmRetentions_TableName_Sequence UNIQUE(TableName, Sequence);
GO
ALTER TABLE [dbo].[fhsmRetentions]
	ADD Filter nvarchar(max) NULL;
GO

--
-- Update the table dbo.fhsmSchedules
--
UPDATE s
SET s.Parameters = '@NumberOfRows=1000'
FROM dbo.fhsmSchedules AS s
WHERE (s.Name = 'Query statistics') AND (s.Parameters IS NULL)
GO

--
-- Run the updated scripts in the listed sequence
--
--_Install-FHSQLMonitor.sql
-- BackupStatus.sql
-- DatabaseIO.sql
-- DatabaseSize.sql
-- DatabaseState.sql
-- IndexOperational.sql
-- IndexOptimize-004.sql			-- !!! REMEBER to set the used OLA database and schema in the file if it is different to FHSQLMonitor !!!
-- IndexPhysical.sql
-- IndexUsage.sql
-- InstanceState.sql
-- MissingIndexes.sql
-- PerfmonStatistics.sql
-- QueryStatistics.sql
-- StatisticsAge.sql
-- TableSize.sql
-- WaitStatistics.sql
-- WhoIsActive-002.sql

--
-- Enable agent job
--
