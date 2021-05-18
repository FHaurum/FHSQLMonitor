--
-- Disable agent job
--

--
-- Verify that the agent is not executing (Job Activity Monitor)
--

--
-- Backup before upgrade from 1.5 to 1.6 - SQL2012 default path
--
USE [master];
GO
BACKUP DATABASE [FHSQLMonitor]
	TO DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Backup\FHSQLMonitor-BeforeUpgradeFrom1.5To1.6.bak'
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
-- Update the table dbo.fhsmQueryStatistics
--
DROP INDEX [NC_fhsmQueryStatistics_TimestampUTC]
	ON [dbo].[fhsmQueryStatistics];
GO
ALTER TABLE [dbo].[fhsmQueryStatistics]
	DROP CONSTRAINT [PK_fhsmQueryStatistics] WITH ( ONLINE = OFF );
GO
CREATE CLUSTERED INDEX [CL_fhsmQueryStatistics_TimestampUTC]
	ON [dbo].[fhsmQueryStatistics]([TimestampUTC] ASC);
GO
ALTER TABLE [dbo].[fhsmQueryStatistics]
	ADD CONSTRAINT [NCPK_fhsmQueryStatistics] PRIMARY KEY NONCLUSTERED([Id]);
GO

--
-- Run the updated scripts
--
-- IndexOptimize-004.sql			-- !!! REMEBER to set the used OLA database and schema in the file if it is different to FHSQLMonitor !!!
-- InstanceState.sql
-- QueryStatistics.sql

--
-- Enable agent job
--
