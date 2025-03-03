--
-- Disable agent job
--

--
-- Verify that the agent is not executing (Job Activity Monitor)
--

--
-- Backup before upgrade from 1.3 to 1.4 - SQL2012 default path
--
USE [master];
GO
BACKUP DATABASE [FHSQLMonitor]
	TO DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Backup\FHSQLMonitor-BeforeUpgradeFrom1.3To1.4.bak'
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
DROP INDEX [NC_fhsmStatisticsAge_Timestamp_Updated] ON [dbo].[fhsmStatisticsAge]
GO
EXEC sp_rename 'dbo.fhsmStatisticsAge.Updated', 'LastUpdated', 'COLUMN';  
GO
ALTER TABLE dbo.fhsmStatisticsAge ALTER COLUMN LastUpdated datetime2 NULL;
GO
ALTER TABLE dbo.fhsmStatisticsAge ADD Rows bigint NULL;
GO
ALTER TABLE dbo.fhsmStatisticsAge ADD RowsSampled bigint NULL;
GO
ALTER TABLE dbo.fhsmStatisticsAge ADD Steps int NULL;
GO
ALTER TABLE dbo.fhsmStatisticsAge ADD UnfilteredRows bigint NULL;
GO
ALTER TABLE dbo.fhsmStatisticsAge ADD ModificationCounter bigint NULL;
GO
ALTER TABLE dbo.fhsmStatisticsAge ADD PersistedSamplePercent float NULL;
GO
CREATE NONCLUSTERED INDEX NC_fhsmStatisticsAge_Timestamp_LastUpdated ON dbo.fhsmStatisticsAge(Timestamp, LastUpdated) INCLUDE(DatabaseName, SchemaName, ObjectName, IndexName);
GO

--
-- Update the table dbo.fhsmTableSize
--
ALTER TABLE dbo.fhsmTableSize ADD IndexName nvarchar(128) NULL;
GO
ALTER TABLE dbo.fhsmTableSize ADD PartitionNumber int NULL;
GO
UPDATE ts SET ts.PartitionNumber = 1 FROM dbo.fhsmTableSize AS ts WHERE (ts.PartitionNumber IS NULL);
GO
ALTER TABLE dbo.fhsmTableSize ALTER COLUMN PartitionNumber int NOT NULL;
GO
DROP INDEX NC_fhsmTableSize_DatabaseName_SchemaName_ObjectName ON dbo.fhsmTableSize;
GO
CREATE NONCLUSTERED INDEX NC_fhsmTableSize_DatabaseName_SchemaName_ObjectName_IndexName ON dbo.fhsmTableSize(DatabaseName, SchemaName, ObjectName, IndexName);
GO

--
-- Run the updated scripts
--
-- DatabaseIO.sql
-- DatabaseState.sql
-- InstanceState.sql
-- PerfmonStatistics.sql
-- StatisticsAge.sql
-- TableSize.sql
-- WaitStatistics.sql
-- WhoIsActive-002.sql
--

--
-- Enable agent job
--
