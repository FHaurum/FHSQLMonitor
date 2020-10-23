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
	DECLARE @serviceName nvarchar(128);
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
		-- Create table dbo.fhsmPerfmonCounters if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmPerfmonCounters', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmPerfmonCounters', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmPerfmonCounters(
				Id int identity(1,1)
				,ObjectName nvarchar(128) NOT NULL
				,CounterName nvarchar(128) NOT NULL
				,InstanceName nvarchar(128) NULL
				,CONSTRAINT PK_fhsmPerfmonCounters PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmPerfmonCounters_ObjectName_CounterName_InstanceName_TimestampUTC ON dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName);
		END;

		--
		-- Register extended properties on the table dbo.fhsmPerfmonCounters
		--
		BEGIN
			SET @objectName = 'dbo.fhsmPerfmonCounters';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create table dbo.fhsmPerfmonStatistics if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmPerfmonStatistics', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmPerfmonStatistics', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmPerfmonStatistics(
				Id int identity(1,1)
				,ObjectName nvarchar(128) NOT NULL
				,CounterName nvarchar(128) NOT NULL
				,InstanceName nvarchar(128) NOT NULL
				,CounterValue bigint NOT NULL
				,CounterType int NOT NULL
				,LastSQLServiceRestart datetime NOT NULL
				,TimestampUTC datetime NOT NULL
				,Timestamp datetime NOT NULL
				,CONSTRAINT PK_fhsmPerfmonStatistics PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmPerfmonStatistics_TimestampUTC ON dbo.fhsmPerfmonStatistics(TimestampUTC);
			CREATE NONCLUSTERED INDEX NC_fhsmPerfmonStatistics_Timestamp ON dbo.fhsmPerfmonStatistics(Timestamp);
			CREATE NONCLUSTERED INDEX NC_fhsmPerfmonStatistics_ObjectName_CounterName_InstanceName_TimestampUTC ON dbo.fhsmPerfmonStatistics(ObjectName, CounterName, InstanceName, TimestampUTC) INCLUDE(CounterValue);
		END;

		--
		-- Register extended properties on the table dbo.fhsmPerfmonStatistics
		--
		BEGIN
			SET @objectName = 'dbo.fhsmPerfmonStatistics';
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
	-- Create default perfmon counters
	--
	BEGIN
		IF ((SELECT COUNT(*) FROM dbo.fhsmPerfmonCounters) = 0)
		BEGIN
			SET @serviceName = CASE WHEN @@SERVICENAME = 'MSSQLSERVER' THEN 'SQLServer' ELSE 'MSSQL$' + @@SERVICENAME END;

			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Access Methods','Forwarded Records/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Access Methods','Page compression attempts/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Access Methods','Page Splits/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Access Methods','Skipped Ghosted Records/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Access Methods','Table Lock Escalations/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Access Methods','Worktables Created/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Availability Group','Active Hadr Threads','_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Availability Replica','Bytes Received from Replica/sec','_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Availability Replica','Bytes Sent to Replica/sec','_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Availability Replica','Bytes Sent to Transport/sec','_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Availability Replica','Flow Control Time (ms/sec)','_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Availability Replica','Flow Control/sec','_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Availability Replica','Resent Messages/sec','_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Availability Replica','Sends to Replica/sec','_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Page life expectancy', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Page reads/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Page writes/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Readahead pages/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Target pages', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Total pages', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Databases','', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Active Transactions','_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Database Replica','Database Flow Control Delay', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Database Replica','Database Flow Controls/sec', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Database Replica','Group Commit Time', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Database Replica','Group Commits/Sec', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Database Replica','Log Apply Pending Queue', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Database Replica','Log Apply Ready Queue', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Database Replica','Log Compression Cache misses/sec', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Database Replica','Log remaining for undo', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Database Replica','Log Send Queue', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Database Replica','Recovery Queue', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Database Replica','Redo blocked/sec', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Database Replica','Redo Bytes Remaining', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Database Replica','Redone Bytes/sec', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Databases','Log Bytes Flushed/sec', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Databases','Log Growths', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Databases','Log Pool LogWriter Pushes/sec', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Databases','Log Shrinks', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Databases','Transactions/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Databases','Write Transactions/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Databases','XTP Memory Used (KB)',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Exec Statistics','Distributed Query', 'Execs in progress');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Exec Statistics','DTC calls', 'Execs in progress');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Exec Statistics','Extended Procedures', 'Execs in progress');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Exec Statistics','OLEDB calls', 'Execs in progress');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':General Statistics','Active Temp Tables', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':General Statistics','Logins/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':General Statistics','Logouts/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':General Statistics','Mars Deadlocks', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':General Statistics','Processes blocked', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Locks','Number of Deadlocks/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Memory Manager','Memory Grants Pending', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':SQL Errors','Errors/sec', '_Total');
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':SQL Statistics','Batch Requests/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':SQL Statistics','Forced Parameterizations/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':SQL Statistics','Guided plan executions/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':SQL Statistics','SQL Attention rate', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':SQL Statistics','SQL Compilations/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':SQL Statistics','SQL Re-Compilations/sec', NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Workload Group Stats','Query optimizations/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Workload Group Stats','Suboptimal plans/sec',NULL);
			/* Below counters added by Jefferson Elias */
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Access Methods','Worktables From Cache Base',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Access Methods','Worktables From Cache Ratio',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Database pages',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Free pages',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Stolen pages',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Memory Manager','Granted Workspace Memory (KB)',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Memory Manager','Maximum Workspace Memory (KB)',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Memory Manager','Target Server Memory (KB)',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Memory Manager','Total Server Memory (KB)',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Buffer cache hit ratio',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Buffer cache hit ratio base',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Checkpoint pages/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Free list stalls/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Lazy writes/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':SQL Statistics','Auto-Param Attempts/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':SQL Statistics','Failed Auto-Params/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':SQL Statistics','Safe Auto-Params/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':SQL Statistics','Unsafe Auto-Params/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Access Methods','Workfiles Created/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':General Statistics','User Connections',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Latches','Average Latch Wait Time (ms)',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Latches','Average Latch Wait Time Base',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Latches','Latch Waits/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Latches','Total Latch Wait Time (ms)',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Locks','Average Wait Time (ms)',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Locks','Average Wait Time Base',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Locks','Lock Requests/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Locks','Lock Timeouts/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Locks','Lock Wait Time (ms)',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Locks','Lock Waits/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Transactions','Longest Transaction Running Time',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Access Methods','Full Scans/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Access Methods','Index Searches/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Buffer Manager','Page lookups/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES(@serviceName + ':Cursor Manager by Type','Active cursors',NULL);
			/* Below counters are for In-Memory OLTP (Hekaton), which have a different naming convention.
				And yes, they actually hard-coded the version numbers into the counters, and SQL 2019 still says 2017, oddly.
				For why, see: https://connect.microsoft.com/SQLServer/feedback/details/817216/xtp-perfmon-counters-should-appear-under-sql-server-perfmon-counter-group
			*/
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2014 XTP Cursors','Expired rows removed/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2014 XTP Cursors','Expired rows touched/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2014 XTP Garbage Collection','Rows processed/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2014 XTP IO Governor','Io Issued/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2014 XTP Phantom Processor','Phantom expired rows touched/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2014 XTP Phantom Processor','Phantom rows touched/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2014 XTP Transaction Log','Log bytes written/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2014 XTP Transaction Log','Log records written/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2014 XTP Transactions','Transactions aborted by user/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2014 XTP Transactions','Transactions aborted/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2014 XTP Transactions','Transactions created/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2016 XTP Cursors','Expired rows removed/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2016 XTP Cursors','Expired rows touched/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2016 XTP Garbage Collection','Rows processed/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2016 XTP IO Governor','Io Issued/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2016 XTP Phantom Processor','Phantom expired rows touched/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2016 XTP Phantom Processor','Phantom rows touched/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2016 XTP Transaction Log','Log bytes written/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2016 XTP Transaction Log','Log records written/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2016 XTP Transactions','Transactions aborted by user/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2016 XTP Transactions','Transactions aborted/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2016 XTP Transactions','Transactions created/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2017 XTP Cursors','Expired rows removed/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2017 XTP Cursors','Expired rows touched/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2017 XTP Garbage Collection','Rows processed/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2017 XTP IO Governor','Io Issued/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2017 XTP Phantom Processor','Phantom expired rows touched/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2017 XTP Phantom Processor','Phantom rows touched/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2017 XTP Transaction Log','Log bytes written/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2017 XTP Transaction Log','Log records written/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2017 XTP Transactions','Transactions aborted by user/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2017 XTP Transactions','Transactions aborted/sec',NULL);
			INSERT INTO dbo.fhsmPerfmonCounters(ObjectName, CounterName, InstanceName) VALUES ('SQL Server 2017 XTP Transactions','Transactions created/sec',NULL);
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
		-- Create helper view dbo.fhsmPerformStatisticsActual
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmPerformStatisticsActual'', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW dbo.fhsmPerformStatisticsActual AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW dbo.fhsmPerformStatisticsActual
				AS
					WITH
					rowDates AS (
						SELECT
							DISTINCT
							TimestampUTC
						FROM dbo.fhsmPerfmonStatistics
					)
					,checkDates AS (
						SELECT
							a.TimestampUTC
							,a.PreviousTimestampUTC
						FROM (
							SELECT
								thisDate.TimestampUTC
								,LAG(thisDate.TimestampUTC) OVER(ORDER BY thisDate.TimestampUTC) PreviousTimestampUTC
							FROM rowDates AS thisDate
						) AS a
						WHERE (a.PreviousTimestampUTC IS NOT NULL)
					)
					,PerfmonDeltas AS (
						SELECT
							pMon.ObjectName
							,pMon.CounterName
							,pMon.InstanceName
							,DATEDIFF(SECOND, pMonPrior.TimestampUTC, pMon.TimestampUTC) AS ElapsedSeconds
							,pMon.CounterValue
							,pMon.CounterType
							,(pMon.CounterValue - pMonPrior.CounterValue) AS CounterDelta
							,(pMon.CounterValue - pMonPrior.CounterValue) * 1.0 / DATEDIFF(SECOND, pMonPrior.TimestampUTC, pMon.TimestampUTC) AS CounterDeltaPerSecond
							,pMon.TimestampUTC
							,pMon.Timestamp
						FROM dbo.fhsmPerfmonStatistics AS pMon
						INNER JOIN checkDates AS dates ON (dates.TimestampUTC = pMon.TimestampUTC)
						INNER JOIN dbo.fhsmPerfmonStatistics AS pMonPrior
							ON (pMonPrior.TimestampUTC = dates.PreviousTimestampUTC)
							AND (pMonPrior.ObjectName = pMon.ObjectName)
							AND (pMonPrior.CounterName = pMon.CounterName)
							AND (pMonPrior.InstanceName = pMon.InstanceName)
						WHERE DATEDIFF(MINUTE, dates.PreviousTimestampUTC, dates.TimestampUTC) BETWEEN 1 AND 60
					)
					,PerfAverageBulk AS (
						SELECT
							ObjectName
							,InstanceName
							,CounterName
							,CASE WHEN (CHARINDEX(''('', CounterName) = 0) THEN CounterName ELSE LEFT(CounterName, CHARINDEX(''('', CounterName) - 1) END AS CounterJoin
							,CounterDelta
							,TimestampUTC
							,Timestamp
						FROM PerfmonDeltas
						WHERE (CounterType IN (1073874176))
							AND (CounterDelta > 0)
					)
					,PerfLargeRawBase AS (
						SELECT
							ObjectName
							,InstanceName
							,LEFT(CounterName, CHARINDEX(''BASE'', UPPER(CounterName)) - 1) AS CounterJoin
							,CounterDelta
							,TimestampUTC
							,Timestamp
						FROM PerfmonDeltas
						WHERE (CounterType IN (1073939712))
							AND (CounterDelta > 0)
					)
					,PerfAverageFraction AS (
						SELECT
							ObjectName
							,InstanceName
							,CounterName
							,CounterName AS CounterJoin
							,CounterDelta
							,TimestampUTC
							,Timestamp
						FROM PerfmonDeltas
						WHERE (CounterType IN (537003264))
							AND (CounterDelta > 0)
					)
					,PerfCounterBulkCount AS (
						SELECT
							ObjectName
							,InstanceName
							,CounterName
							,CounterDelta / ElapsedSeconds AS CounterValue
							,TimestampUTC
							,Timestamp
						FROM PerfmonDeltas
						WHERE (CounterType IN (272696576, 272696320))
							AND (CounterDelta > 0)
					)
					,PerfCounterRawCount AS (
						SELECT
							ObjectName
							,InstanceName
							,CounterName
							,CounterValue
							,TimestampUTC
							,Timestamp
						FROM PerfmonDeltas
						WHERE (CounterType IN (65792, 65536))
							AND (CounterDelta > 0)
					)
					,AllData AS (
						SELECT
							num.ObjectName
							,num.CounterName
							,num.InstanceName
							,num.CounterDelta / den.CounterDelta AS CounterValue
							,num.TimestampUTC
							,num.Timestamp
						FROM PerfAverageBulk AS num
						INNER JOIN PerfLargeRawBase AS den
							ON (den.CounterJoin = num.CounterJoin)
							AND (den.TimestampUTC = num.TimestampUTC)
							AND (den.ObjectName = num.ObjectName)
							AND (den.InstanceName = num.InstanceName)
							AND (den.CounterDelta <> 0)

						UNION ALL

						SELECT
							num.ObjectName
							,num.CounterName
							,num.InstanceName
							,CAST((CAST(num.CounterDelta AS decimal(19)) / den.CounterDelta) AS decimal(23,3)) AS CounterValue
							,num.TimestampUTC
							,num.Timestamp
						FROM PerfAverageFraction AS num
						INNER JOIN PerfLargeRawBase AS den
							ON (1=1)
							AND (den.CounterJoin = num.CounterJoin)
							AND (den.TimestampUTC = num.TimestampUTC)
							AND (den.ObjectName = num.ObjectName)
							AND (den.InstanceName = num.InstanceName)
							AND (den.CounterDelta <> 0)

						UNION ALL

						SELECT
							ObjectName
							,CounterName
							,InstanceName
							,CounterValue
							,TimestampUTC
							,Timestamp
						FROM PerfCounterBulkCount

						UNION ALL

						SELECT
							ObjectName
							,CounterName
							,InstanceName
							,CounterValue
							,TimestampUTC
							,Timestamp
						FROM PerfCounterRawCount
					)
					SELECT
						a.ObjectName
						,a.CounterName
						,a.InstanceName
						,a.CounterValue
						,a.TimestampUTC
						,a.Timestamp
					FROM AllData AS a
					WHERE (a.CounterValue <> 0);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view dbo.fhsmPerformStatisticsActual
		--
		BEGIN
			SET @objectName = 'dbo.fhsmPerformStatisticsActual';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Performance statistics]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Performance statistics') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Performance statistics') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Performance statistics') + '
				AS
				SELECT
					psa.CounterValue
					,psa.Timestamp
					,CAST(psa.Timestamp AS date) AS Date
					,(DATEPART(HOUR, psa.Timestamp) * 60 * 60) + (DATEPART(MINUTE, psa.Timestamp) * 60) + (DATEPART(SECOND, psa.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(psa.ObjectName, psa.CounterName, psa.InstanceName, DEFAULT, DEFAULT, DEFAULT) AS k) AS PerfmonKey
				FROM dbo.fhsmPerformStatisticsActual AS psa
				WHERE (psa.CounterValue <> 0);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Performance statistics]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Performance statistics');
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
		-- Create stored procedure dbo.fhsmSPPerfmonStatistics
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPPerfmonStatistics'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPPerfmonStatistics AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPPerfmonStatistics (
					@name nvarchar(128)
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameters nvarchar(max);
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);

					--
					-- Get the parametrs for the command
					--
					BEGIN
						SET @parameters = dbo.fhsmFNGetTaskParameter(@thisTask, @name);
					END;

					--
					-- Collect data
					--
					BEGIN
						SET @now = SYSDATETIME();
						SET @nowUTC = SYSUTCDATETIME();

						SET @stmt = ''
							SELECT
								RTRIM(dopc.object_name) AS ObjectName
								,RTRIM(dopc.counter_name) AS CounterName
								,RTRIM(dopc.instance_name) AS InstanceName
								,dopc.cntr_value AS CounterValue
								,dopc.cntr_type AS CounterType
								,(SELECT d.create_date FROM sys.databases AS d WITH (NOLOCK) WHERE (d.name = ''''tempdb'''')) AS LastSQLServiceRestart
								,@nowUTC, @now
							FROM dbo.fhsmPerfmonCounters AS pc
							INNER JOIN sys.dm_os_performance_counters AS dopc WITH (NOLOCK)
								ON (RTRIM(dopc.counter_name) = pc.CounterName)
								AND (RTRIM(dopc.[object_name]) = pc.ObjectName)
								AND (
									(pc.InstanceName IS NULL)
									OR (RTRIM(dopc.[instance_name]) = pc.InstanceName)
								);
						'';
						INSERT INTO dbo.fhsmPerfmonStatistics(
							ObjectName, CounterName, InstanceName
							,CounterValue, CounterType
							,LastSQLServiceRestart
							,TimestampUTC, Timestamp
						)
						EXEC sp_executesql
							@stmt
							,N''@now datetime, @nowUTC datetime''
							,@now = @now, @nowUTC = @nowUTC;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPPerfmonStatistics
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPPerfmonStatistics';
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
				,'dbo.fhsmPerfmonStatistics'
				,'TimestampUTC'
				,1
				,30
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
				,'Performance statistics'
				,PARSENAME('dbo.fhsmSPPerfmonStatistics', 1)
				,15 * 60
				,TIMEFROMPARTS(0, 0, 0, 0, 0)
				,TIMEFROMPARTS(23, 59, 59, 0, 0)
				,1, 1, 1, 1, 1, 1, 1
				,NULL
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
			,SrcColumn1, SrcColumn2, SrcColumn3
			,OutputColumn1, OutputColumn2, OutputColumn3
		) AS (
			SELECT
				'Performance counter' AS DimensionName
				,'PerfmonKey' AS DimensionKey
				,'dbo.fhsmPerfmonStatistics' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[ObjectName]', 'src.[CounterName]', 'src.[InstanceName]'
				,'Object', 'Counter', 'Instance'
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
				,tgt.OutputColumn1 = src.OutputColumn1
				,tgt.OutputColumn2 = src.OutputColumn2
				,tgt.OutputColumn3 = src.OutputColumn3
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(
				DimensionName, DimensionKey
				,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
				,SrcColumn1, SrcColumn2, SrcColumn3
				,OutputColumn1, OutputColumn2, OutputColumn3
			)
			VALUES(
				src.DimensionName, src.DimensionKey
				,src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn
				,src.SrcColumn1, src.SrcColumn2, src.SrcColumn3
				,src.OutputColumn1, src.OutputColumn2, src.OutputColumn3
			);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmPerfmonStatistics';
	END;
END;
