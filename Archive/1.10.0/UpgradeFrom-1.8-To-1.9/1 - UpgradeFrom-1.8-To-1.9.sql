--
-- Disable agent job
--

--
-- Verify that the agent is not executing (Job Activity Monitor)
--

--
-- Backup before upgrade from 1.8 to 1.9 - SQL2012 default path
--
USE [master];
GO
BACKUP DATABASE [FHSQLMonitor]
	TO DISK = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Backup\FHSQLMonitor-BeforeUpgradeFrom1.8To1.9.bak'
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
-- Add column ProductMinorVersion to table dbo.fhsmInstanceConfigurations
--
DROP INDEX NC_fhsmInstanceConfigurations_ConfigurationId_ProductMajorVersion ON dbo.fhsmInstanceConfigurations;
GO
ALTER TABLE dbo.fhsmInstanceConfigurations ADD ProductMinorVersion int NULL;
GO
UPDATE dbo.fhsmInstanceConfigurations
SET ProductMinorVersion = 0;
GO
ALTER TABLE dbo.fhsmInstanceConfigurations ALTER COLUMN ProductMinorVersion int NOT NULL;
GO
CREATE NONCLUSTERED INDEX NC_fhsmInstanceConfigurations_ConfigurationId_ProductMajorVersion_ProductMinorVersion ON dbo.fhsmInstanceConfigurations(ConfigurationId, ProductMajorVersion, ProductMinorVersion);
GO

--
-- Add column ProductMinorVersion to table dbo.fhsmTraceFlags
--
DROP INDEX NC_fhsmTraceFlags_TraceFlag_ProductMajorVersion ON dbo.fhsmTraceFlags;
GO
ALTER TABLE dbo.fhsmTraceFlags ADD ProductMinorVersion int NULL;
GO
UPDATE dbo.fhsmTraceFlags
SET ProductMinorVersion = 0;
GO
ALTER TABLE dbo.fhsmTraceFlags ALTER COLUMN ProductMinorVersion int NOT NULL;
GO
CREATE NONCLUSTERED INDEX NC_fhsmTraceFlags_TraceFlag_ProductMajorVersion_ProductMinorVersion ON dbo.fhsmTraceFlags(TraceFlag, ProductMajorVersion, ProductMinorVersion);
GO

--
-- Run the updated scripts in the order listed here
--
-- AgentJobs.sql
-- BackupStatus.sql
-- DatabaseState.sql
-- IndexOptimize-002-OlaHallengren-CommandExecute.sql
-- IndexOptimize-003-OlaHallengren-IndexOptimize.sql
-- IndexOptimize-004.sql			-- !!! REMEBER to set the used OLA database and schema in the file if it is different to FHSQLMonitor !!!
-- InstanceState.sql
-- PlanCacheUsage.sql
-- PlanGuides.sql
-- Triggers.sql
-- WhoIsActive-001-AdamMachanic-12.00-sp_WhoIsActive.sql
--

--
-- Update the table dbo.fhsmWhoIsActive to match the layout of sp_whoIsActive version 12.00
--
BEGIN TRANSACTION;
	DECLARE @stmt nvarchar(max);

	EXEC dbo.sp_WhoIsActive
		@format_output = 0
		,@get_transaction_info = 1
		,@get_outer_command = 1
		,@get_plans = 1
		,@return_schema = 1
		,@schema = @stmt OUTPUT;

	SET @stmt = REPLACE(@stmt, '<table_name>', QUOTENAME(DB_NAME()) + '.dbo.fhsmWhoIsActive_12_00');
	EXEC(@stmt);

	-- Insert into new table layout using the old column order	
	INSERT INTO dbo.fhsmWhoIsActive_12_00([session_id], [sql_text], [sql_command], [login_name], [wait_info], [tran_log_writes], [tempdb_allocations], [tempdb_current], [blocking_session_id], [reads], [writes], [physical_reads], [query_plan], [CPU], [used_memory], [status], [tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], [start_time], [login_time], [request_id], [collection_time], [implicit_tran])
	SELECT [session_id], [sql_text], [sql_command], [login_name], [wait_info], [tran_log_writes], [tempdb_allocations], [tempdb_current], [blocking_session_id], [reads], [writes], [physical_reads], [query_plan], [CPU], [used_memory], [status], [tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], [start_time], [login_time], [request_id], [collection_time], NULL AS [implicit_tran]
	FROM dbo.fhsmWhoIsActive;

	DROP TABLE dbo.fhsmWhoIsActive;

	EXEC sp_rename 'dbo.fhsmWhoIsActive_12_00', 'fhsmWhoIsActive';  
COMMIT TRANSACTION;
GO

--
-- Run the updated scripts in the order listed here
--
-- WhoIsActive-002
--

--
-- Enable agent job
--
