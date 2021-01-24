--
-- Disable agent job
--

--
-- Verify that the agent is not executing (Job Activity Monitor)
--

--
-- Backup before upgrade from 1.2 to 1.3 - SQL2012 default path
--
USE [master];
GO
BACKUP DATABASE [FHSQLMonitor]
	TO DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Backup\FHSQLMonitor-BeforeUpgradeFrom1.2To1.3.bak'
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
-- Update the table dbo.fhsmIndexOperational
--
DROP INDEX [NC_fhsmIndexOperational_DatabaseName_SchemaName_ObjectName_IndexName]
	ON [dbo].[fhsmIndexOperational];
GO
CREATE NONCLUSTERED INDEX [NC_fhsmIndexOperational_DatabaseName_SchemaName_ObjectName_IndexName_TimestampUTC]
	ON [dbo].[fhsmIndexOperational]([DatabaseName] ASC, [SchemaName] ASC, [ObjectName] ASC, [IndexName] ASC, [TimestampUTC] ASC);
GO

--
-- Update the table dbo.fhsmIndexPhysical
--
DROP INDEX [NC_fhsmIndexPhysical_DatabaseName_SchemaName_ObjectName_IndexName]
	ON [dbo].[fhsmIndexPhysical];
GO
DROP INDEX [NC_fhsmIndexPhysical_Timestamp]
	ON [dbo].[fhsmIndexPhysical];
GO
DROP INDEX [NC_fhsmIndexPhysical_TimestampUTC]
	ON [dbo].[fhsmIndexPhysical];
GO
ALTER TABLE [dbo].[fhsmIndexPhysical]
	DROP CONSTRAINT [PK_fhsmIndexPhysical] WITH ( ONLINE = OFF );
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ADD [TimestampUTCDate]  DATE   NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ADD [TimestampDate]     DATE   NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ADD [TimeKey]           INT    NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ADD [DatabaseKey]       BIGINT NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ADD [SchemaKey]         BIGINT NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ADD [ObjectKey]         BIGINT NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ADD [IndexKey]          BIGINT NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ADD [IndexTypeKey]      BIGINT NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ADD [IndexAllocTypeKey] BIGINT NULL;
GO
CREATE CLUSTERED INDEX [CL_fhsmIndexPhysical_TimestampUTC]
    ON [dbo].[fhsmIndexPhysical]([TimestampUTC] ASC);
GO
CREATE NONCLUSTERED INDEX [NC_fhsmIndexPhysical_Timestamp]
    ON [dbo].[fhsmIndexPhysical]([Timestamp] ASC);
GO
ALTER TABLE [dbo].[fhsmIndexPhysical]
	ADD CONSTRAINT [NCPK_fhsmIndexPhysical] PRIMARY KEY NONCLUSTERED([Id]);
GO

--
-- Update the table dbo.fhsmQueryStatisticsTemp
--
CREATE CLUSTERED INDEX [CL_fhsmQueryStatisticsTemp]
    ON [dbo].[fhsmQueryStatisticsTemp]([_Rnk_] ASC, [QueryHash] ASC);
GO

--
-- Run the updated scripts
--
--  _Install-FHSQLMonitor.sql		-- !!! REMEBER to set the used database in the file if it sis different to FHSQLMonitor !!!
-- DatabaseIO.sql
-- IndexOperational.sql
-- IndexOptimize-004.sql
-- IndexPhysical.sql
-- InstanceState.sql
-- PerfmonStatistics.sql
-- QueryStatistics.sql
-- WhoIsActive-002.sql
--

--
-- Update the table dbo.fhsmQueryStatisticsTemp
--
ALTER TABLE [dbo].[fhsmQueryStatisticsTemp]
	DROP COLUMN Encrypted;
GO
ALTER TABLE [dbo].[fhsmQueryStatisticsTemp]
	DROP COLUMN QueryPlan;
GO

--
-- Update the dimensions based on the table dbo.fhsmWaitStatistics
--
EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmWaitStatistics';
GO

--
-- Update the table dbo.fhsmPerfmonCounters with PLE per NUMA nodes
--
DECLARE @serviceName nvarchar(128);
SET @serviceName = CASE WHEN @@SERVICENAME = 'MSSQLSERVER' THEN 'SQLServer' ELSE 'MSSQL$' + @@SERVICENAME END;
INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName)
SELECT newPC.ObjectName, newPC.CounterName, newPC.InstanceName
FROM (
	SELECT @serviceName + ':Buffer Node' AS ObjectName, 'Page life expectancy' AS CounterName, NULL AS InstanceName
) AS newPC
LEFT OUTER JOIN dbo.fhsmPerfmonCounters AS pc ON (newPC.ObjectName = pc.ObjectName) AND (newPC.CounterName = pc.CounterName) AND ((newPC.InstanceName = pc.InstanceName) OR ((newPC.InstanceName IS NULL) AND (pc.InstanceName IS NULL)))
WHERE (pc.ObjectName IS NULL);
GO

--
-- Update the retention for the table dbo.fhsmPerfmonStatistics if it still using the default value
--
UPDATE r SET r.Days = 90 FROM dbo.fhsmRetentions AS r WHERE (r.TableName = 'dbo.fhsmPerfmonStatistics') AND (r.Days = 30);
GO

--
-- Enable agent job
--

--
-- Run the script "2 - UpdateIndexPhysical.sql" to update version 1.2 records
-- Wait for the script to finish before continuing
--

--
-- Update the table dbo.fhsmIndexPhysical
--
ALTER TABLE [dbo].[fhsmIndexPhysical] ALTER COLUMN [TimestampUTCDate]  DATE   NOT NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ALTER COLUMN [TimestampDate]     DATE   NOT NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ALTER COLUMN [TimeKey]           INT    NOT NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ALTER COLUMN [DatabaseKey]       BIGINT NOT NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ALTER COLUMN [SchemaKey]         BIGINT NOT NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ALTER COLUMN [ObjectKey]         BIGINT NOT NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ALTER COLUMN [IndexKey]          BIGINT NOT NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ALTER COLUMN [IndexTypeKey]      BIGINT NOT NULL;
GO
ALTER TABLE [dbo].[fhsmIndexPhysical] ALTER COLUMN [IndexAllocTypeKey] BIGINT NOT NULL;
GO
CREATE NONCLUSTERED INDEX [NC_fhsmIndexPhysical_DatabaseKey_SchemaKey_ObjectKey_TimestampUTCDate_Mode]
    ON [dbo].[fhsmIndexPhysical]([DatabaseKey] ASC, [SchemaKey] ASC, [ObjectKey] ASC, [TimestampUTCDate] ASC, [Mode] ASC);
GO
CREATE NONCLUSTERED INDEX [NC_fhsmIndexPhysical_Mode]
    ON [dbo].[fhsmIndexPhysical]([Mode] ASC);
GO

--
-- Run the script "3 - UpdateQueryStatisticsReport.sql" to load dbo.QueryStatisticsReport with content based on data already in dbo.QueryStatistics
--

--
-- Run the script "4 - UpdateIndexOperationalReport.sql" to load dbo.fhsmIndexOperationalReport with content based on data already in dbo.fhsmIndexOperational
--
