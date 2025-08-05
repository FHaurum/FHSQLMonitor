SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableWaitStatistics bit;

	SET @enableWaitStatistics = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing WaitStatistics', 0, 1) WITH NOWAIT;
END;

--
-- Declare variables
--
BEGIN
	DECLARE @edition nvarchar(128);
	DECLARE @myUserName nvarchar(128);
	DECLARE @nowUTC datetime;
	DECLARE @nowUTCStr nvarchar(128);
	DECLARE @objectName nvarchar(128);
	DECLARE @objName nvarchar(128);
	DECLARE @pbiSchema nvarchar(128);
	DECLARE @productEndPos int;
	DECLARE @productStartPos int;
	DECLARE @productVersion nvarchar(128);
	DECLARE @productVersion1 int;
	DECLARE @productVersion2 int;
	DECLARE @productVersion3 int;
	DECLARE @returnValue int;
	DECLARE @schName nvarchar(128);
	DECLARE @stmt nvarchar(max);
	DECLARE @tableCompressionStmt nvarchar(max);
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
		SET @version = '2.9';

		SET @productVersion = CAST(SERVERPROPERTY('ProductVersion') AS nvarchar);
		SET @productStartPos = 1;
		SET @productEndPos = CHARINDEX('.', @productVersion, @productStartPos);
		SET @productVersion1 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
		SET @productStartPos = @productEndPos + 1;
		SET @productEndPos = CHARINDEX('.', @productVersion, @productStartPos);
		SET @productVersion2 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
		SET @productStartPos = @productEndPos + 1;
		SET @productEndPos = CHARINDEX('.', @productVersion, @productStartPos);
		SET @productVersion3 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
	END;

	--
	-- Check if SQL version allows to use data compression
	--
	BEGIN
		SET @tableCompressionStmt = '';

		SET @edition = CAST(SERVERPROPERTY('Edition') AS nvarchar);

		IF (@edition = 'SQL Azure')
			OR (SUBSTRING(@edition, 1, CHARINDEX(' ', @edition)) = 'Developer')
			OR (SUBSTRING(@edition, 1, CHARINDEX(' ', @edition)) = 'Enterprise')
			OR (@productVersion1 > 13)
			OR ((@productVersion1 = 13) AND (@productVersion2 >= 1))
			OR ((@productVersion1 = 13) AND (@productVersion2 = 0) AND (@productVersion3 >= 4001))
		BEGIN
			SET @tableCompressionStmt = ' WITH (DATA_COMPRESSION = PAGE)';
		END;
	END;

	--
	-- Create tables
	--
	BEGIN
		--
		-- Create table dbo.fhsmWaitCategories if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmWaitCategories', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmWaitCategories', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmWaitCategories(
					WaitType nvarchar(60) NOT NULL
					,WaitCategory nvarchar(128) NOT NULL
					,Ignorable bit NOT NULL
					,CONSTRAINT PK_fhsmWaitCategories PRIMARY KEY(WaitType)' + @tableCompressionStmt + '
				);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmWaitCategories
		--
		BEGIN
			SET @objectName = 'dbo.fhsmWaitCategories';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create table dbo.fhsmWaitStatistics and indexes if they not already exists
		--
		IF OBJECT_ID('dbo.fhsmWaitStatistics', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmWaitStatistics', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmWaitStatistics(
					Id int identity(1,1) NOT NULL
					,WaitType nvarchar(60) NOT NULL
					,SumWaitTimeMS bigint NOT NULL
					,SumSignalWaitTimeMS bigint NOT NULL
					,SumWaitingTasks bigint NOT NULL
					,LastSQLServiceRestart datetime NOT NULL
					,TimestampUTC datetime NOT NULL
					,Timestamp datetime NOT NULL
					,CONSTRAINT PK_WaitStatistics PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmWaitStatistics')) AND (i.name = 'NC_fhsmWaitStatistics_TimestampUTC'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmWaitStatistics_TimestampUTC] to table dbo.fhsmWaitStatistics', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmWaitStatistics_TimestampUTC ON dbo.fhsmWaitStatistics(TimestampUTC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmWaitStatistics')) AND (i.name = 'NC_fhsmWaitStatistics_Timestamp'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmWaitStatistics_Timestamp] to table dbo.fhsmWaitStatistics', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmWaitStatistics_Timestamp ON dbo.fhsmWaitStatistics(Timestamp)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmWaitStatistics')) AND (i.name = 'NC_fhsmWaitStatistics_WaitType'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmWaitStatistics_WaitType] to table dbo.fhsmWaitStatistics', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmWaitStatistics_WaitType ON dbo.fhsmWaitStatistics(WaitType)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmWaitStatistics
		--
		BEGIN
			SET @objectName = 'dbo.fhsmWaitStatistics';
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
	-- Create default wait categories
	--
	BEGIN
		IF ((SELECT COUNT(*) FROM dbo.fhsmWaitCategories) = 0)
		BEGIN
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('ASYNC_IO_COMPLETION','Other Disk IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('ASYNC_NETWORK_IO','Network IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BACKUPIO','Other Disk IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_CONNECTION_RECEIVE_TASK','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_DISPATCHER','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_ENDPOINT_STATE_MUTEX','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_EVENTHANDLER','Service Broker',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_FORWARDER','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_INIT','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_MASTERSTART','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_RECEIVE_WAITFOR','User Wait',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_REGISTERALLENDPOINTS','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_SERVICE','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_SHUTDOWN','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_START','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TASK_SHUTDOWN','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TASK_STOP','Service Broker',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TASK_SUBMIT','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TO_FLUSH','Service Broker',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TRANSMISSION_OBJECT','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TRANSMISSION_TABLE','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TRANSMISSION_WORK','Service Broker',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('BROKER_TRANSMITTER','Service Broker',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CHECKPOINT_QUEUE','Idle',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CHKPT','Tran Log IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CLR_AUTO_EVENT','SQL CLR',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CLR_CRST','SQL CLR',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CLR_JOIN','SQL CLR',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CLR_MANUAL_EVENT','SQL CLR',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CLR_MEMORY_SPY','SQL CLR',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CLR_MONITOR','SQL CLR',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CLR_RWLOCK_READER','SQL CLR',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CLR_RWLOCK_WRITER','SQL CLR',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CLR_SEMAPHORE','SQL CLR',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CLR_TASK_START','SQL CLR',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CLRHOST_STATE_ACCESS','SQL CLR',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CMEMPARTITIONED','Memory',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CMEMTHREAD','Memory',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CXPACKET','Parallelism',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('CXCONSUMER','Parallelism',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DBMIRROR_DBM_EVENT','Mirroring',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DBMIRROR_DBM_MUTEX','Mirroring',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DBMIRROR_EVENTS_QUEUE','Mirroring',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DBMIRROR_SEND','Mirroring',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DBMIRROR_WORKER_QUEUE','Mirroring',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DBMIRRORING_CMD','Mirroring',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DIRTY_PAGE_POLL','Other',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DIRTY_PAGE_TABLE_LOCK','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DISPATCHER_QUEUE_SEMAPHORE','Other',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DPT_ENTRY_LOCK','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DTC','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DTC_ABORT_REQUEST','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DTC_RESOLVE','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DTC_STATE','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DTC_TMDOWN_REQUEST','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DTC_WAITFOR_OUTCOME','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DTCNEW_ENLIST','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DTCNEW_PREPARE','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DTCNEW_RECOVERY','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DTCNEW_TM','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DTCNEW_TRANSACTION_ENLISTMENT','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('DTCPNTSYNC','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('EE_PMOLOCK','Memory',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('EXCHANGE','Parallelism',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('EXTERNAL_SCRIPT_NETWORK_IOF','Network IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('FCB_REPLICA_READ','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('FCB_REPLICA_WRITE','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('FT_COMPROWSET_RWLOCK','Full Text Search',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('FT_IFTS_RWLOCK','Full Text Search',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('FT_IFTS_SCHEDULER_IDLE_WAIT','Idle',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('FT_IFTSHC_MUTEX','Full Text Search',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('FT_IFTSISM_MUTEX','Full Text Search',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('FT_MASTER_MERGE','Full Text Search',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('FT_MASTER_MERGE_COORDINATOR','Full Text Search',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('FT_METADATA_MUTEX','Full Text Search',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('FT_PROPERTYLIST_CACHE','Full Text Search',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('FT_RESTART_CRAWL','Full Text Search',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('FULLTEXT GATHERER','Full Text Search',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_AG_MUTEX','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_AR_CRITICAL_SECTION_ENTRY','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_AR_MANAGER_MUTEX','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_AR_UNLOAD_COMPLETED','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_ARCONTROLLER_NOTIFICATIONS_SUBSCRIBER_LIST','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_BACKUP_BULK_LOCK','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_BACKUP_QUEUE','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_CLUSAPI_CALL','Replication',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_COMPRESSED_CACHE_SYNC','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_CONNECTIVITY_INFO','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_DATABASE_FLOW_CONTROL','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_DATABASE_VERSIONING_STATE','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_DATABASE_WAIT_FOR_RECOVERY','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_DATABASE_WAIT_FOR_RESTART','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_DATABASE_WAIT_FOR_TRANSITION_TO_VERSIONING','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_DB_COMMAND','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_DB_OP_COMPLETION_SYNC','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_DB_OP_START_SYNC','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_DBR_SUBSCRIBER','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_DBR_SUBSCRIBER_FILTER_LIST','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_DBSEEDING','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_DBSEEDING_LIST','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_DBSTATECHANGE_SYNC','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_FABRIC_CALLBACK','Replication',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_BLOCK_FLUSH','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_FILE_CLOSE','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_FILE_REQUEST','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_IOMGR','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_IOMGR_IOCOMPLETION','Replication',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_MANAGER','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_FILESTREAM_PREPROC','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_GROUP_COMMIT','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_LOGCAPTURE_SYNC','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_LOGCAPTURE_WAIT','Replication',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_LOGPROGRESS_SYNC','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_NOTIFICATION_DEQUEUE','Replication',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_NOTIFICATION_WORKER_EXCLUSIVE_ACCESS','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_NOTIFICATION_WORKER_STARTUP_SYNC','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_NOTIFICATION_WORKER_TERMINATION_SYNC','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_PARTNER_SYNC','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_READ_ALL_NETWORKS','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_RECOVERY_WAIT_FOR_CONNECTION','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_RECOVERY_WAIT_FOR_UNDO','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_REPLICAINFO_SYNC','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_SEEDING_CANCELLATION','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_SEEDING_FILE_LIST','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_SEEDING_LIMIT_BACKUPS','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_SEEDING_SYNC_COMPLETION','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_SEEDING_TIMEOUT_TASK','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_SEEDING_WAIT_FOR_COMPLETION','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_SYNC_COMMIT','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_SYNCHRONIZING_THROTTLE','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_TDS_LISTENER_SYNC','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_TDS_LISTENER_SYNC_PROCESSING','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_THROTTLE_LOG_RATE_GOVERNOR','Log Rate Governor',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_TIMER_TASK','Replication',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_TRANSPORT_DBRLIST','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_TRANSPORT_FLOW_CONTROL','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_TRANSPORT_SESSION','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_WORK_POOL','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_WORK_QUEUE','Replication',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('HADR_XRF_STACK_ACCESS','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('INSTANCE_LOG_RATE_GOVERNOR','Log Rate Governor',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('IO_COMPLETION','Other Disk IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('IO_QUEUE_LIMIT','Other Disk IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('IO_RETRY','Other Disk IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LATCH_DT','Latch',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LATCH_EX','Latch',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LATCH_KP','Latch',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LATCH_NL','Latch',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LATCH_SH','Latch',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LATCH_UP','Latch',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LAZYWRITER_SLEEP','Idle',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_BU','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_BU_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_BU_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IS_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IS_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IU','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IU_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IU_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IX','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IX_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_IX_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_NL','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_NL_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_NL_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_S','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_S_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_S_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_U','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_U_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_U_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_X','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_X_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RIn_X_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RS_S','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RS_S_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RS_S_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RS_U','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RS_U_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RS_U_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_S','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_S_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_S_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_U','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_U_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_U_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_X','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_X_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_RX_X_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_S','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_S_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_S_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SCH_M','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SCH_M_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SCH_M_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SCH_S','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SCH_S_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SCH_S_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SIU','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SIU_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SIU_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SIX','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SIX_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_SIX_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_U','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_U_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_U_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_UIX','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_UIX_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_UIX_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_X','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_X_ABORT_BLOCKERS','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LCK_M_X_LOW_PRIORITY','Lock',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LOG_RATE_GOVERNOR','Tran Log IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LOGBUFFER','Tran Log IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LOGMGR','Tran Log IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LOGMGR_FLUSH','Tran Log IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LOGMGR_PMM_LOG','Tran Log IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LOGMGR_QUEUE','Idle',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('LOGMGR_RESERVE_APPEND','Tran Log IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('MEMORY_ALLOCATION_EXT','Memory',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('MEMORY_GRANT_UPDATE','Memory',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('MSQL_XACT_MGR_MUTEX','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('MSQL_XACT_MUTEX','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('MSSEARCH','Full Text Search',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('NET_WAITFOR_PACKET','Network IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('ONDEMAND_TASK_QUEUE','Idle',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PAGEIOLATCH_DT','Buffer IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PAGEIOLATCH_EX','Buffer IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PAGEIOLATCH_KP','Buffer IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PAGEIOLATCH_NL','Buffer IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PAGEIOLATCH_SH','Buffer IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PAGEIOLATCH_UP','Buffer IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PAGELATCH_DT','Buffer Latch',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PAGELATCH_EX','Buffer Latch',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PAGELATCH_KP','Buffer Latch',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PAGELATCH_NL','Buffer Latch',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PAGELATCH_SH','Buffer Latch',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PAGELATCH_UP','Buffer Latch',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_DRAIN_WORKER','Replication',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_FLOW_CONTROL','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_LOG_CACHE','Replication',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_TRAN_LIST','Replication',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_TRAN_TURN','Replication',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_WORKER_SYNC','Replication',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PARALLEL_REDO_WORKER_WAIT_WORK','Replication',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('POOL_LOG_RATE_GOVERNOR','Log Rate Governor',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_ABR','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_CLOSEBACKUPMEDIA','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_CLOSEBACKUPTAPE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_CLOSEBACKUPVDIDEVICE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_CLUSAPI_CLUSTERRESOURCECONTROL','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_COCREATEINSTANCE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_COGETCLASSOBJECT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_CREATEACCESSOR','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_DELETEROWS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_GETCOMMANDTEXT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_GETDATA','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_GETNEXTROWS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_GETRESULT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_GETROWSBYBOOKMARK','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBFLUSH','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBLOCKREGION','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBREADAT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBSETSIZE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBSTAT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBUNLOCKREGION','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_LBWRITEAT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_QUERYINTERFACE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_RELEASE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_RELEASEACCESSOR','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_RELEASEROWS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_RELEASESESSION','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_RESTARTPOSITION','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_SEQSTRMREAD','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_SEQSTRMREADANDWRITE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_SETDATAFAILURE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_SETPARAMETERINFO','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_SETPARAMETERPROPERTIES','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_STRMLOCKREGION','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_STRMSEEKANDREAD','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_STRMSEEKANDWRITE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_STRMSETSIZE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_STRMSTAT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_COM_STRMUNLOCKREGION','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_CONSOLEWRITE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_CREATEPARAM','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DEBUG','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSADDLINK','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSLINKEXISTCHECK','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSLINKHEALTHCHECK','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSREMOVELINK','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSREMOVEROOT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSROOTFOLDERCHECK','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSROOTINIT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DFSROOTSHARECHECK','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DTC_ABORT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DTC_ABORTREQUESTDONE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DTC_BEGINTRANSACTION','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DTC_COMMITREQUESTDONE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DTC_ENLIST','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_DTC_PREPAREREQUESTDONE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_FILESIZEGET','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_FSAOLEDB_ABORTTRANSACTION','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_FSAOLEDB_COMMITTRANSACTION','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_FSAOLEDB_STARTTRANSACTION','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_FSRECOVER_UNCONDITIONALUNDO','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_GETRMINFO','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_HADR_LEASE_MECHANISM','Preemptive',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_HTTP_EVENT_WAIT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_HTTP_REQUEST','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_LOCKMONITOR','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_MSS_RELEASE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_ODBCOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLE_UNINIT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_ABORTORCOMMITTRAN','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_ABORTTRAN','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_GETDATASOURCE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_GETLITERALINFO','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_GETPROPERTIES','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_GETPROPERTYINFO','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_GETSCHEMALOCK','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_JOINTRANSACTION','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_RELEASE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDB_SETPROPERTIES','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OLEDBOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_ACCEPTSECURITYCONTEXT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_ACQUIRECREDENTIALSHANDLE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_AUTHENTICATIONOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_AUTHORIZATIONOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_AUTHZGETINFORMATIONFROMCONTEXT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_AUTHZINITIALIZECONTEXTFROMSID','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_AUTHZINITIALIZERESOURCEMANAGER','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_BACKUPREAD','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CLOSEHANDLE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CLUSTEROPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_COMOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_COMPLETEAUTHTOKEN','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_COPYFILE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CREATEDIRECTORY','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CREATEFILE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CRYPTACQUIRECONTEXT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CRYPTIMPORTKEY','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_CRYPTOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DECRYPTMESSAGE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DELETEFILE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DELETESECURITYCONTEXT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DEVICEIOCONTROL','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DEVICEOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DIRSVC_NETWORKOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DISCONNECTNAMEDPIPE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DOMAINSERVICESOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DSGETDCNAME','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_DTCOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_ENCRYPTMESSAGE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_FILEOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_FINDFILE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_FLUSHFILEBUFFERS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_FORMATMESSAGE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_FREECREDENTIALSHANDLE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_FREELIBRARY','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GENERICOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETADDRINFO','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETCOMPRESSEDFILESIZE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETDISKFREESPACE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETFILEATTRIBUTES','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETFILESIZE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETFINALFILEPATHBYHANDLE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETLONGPATHNAME','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETPROCADDRESS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETVOLUMENAMEFORVOLUMEMOUNTPOINT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_GETVOLUMEPATHNAME','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_INITIALIZESECURITYCONTEXT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_LIBRARYOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_LOADLIBRARY','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_LOGONUSER','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_LOOKUPACCOUNTSID','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_MESSAGEQUEUEOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_MOVEFILE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETGROUPGETUSERS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETLOCALGROUPGETMEMBERS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETUSERGETGROUPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETUSERGETLOCALGROUPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETUSERMODALSGET','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETVALIDATEPASSWORDPOLICY','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_NETVALIDATEPASSWORDPOLICYFREE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_OPENDIRECTORY','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_PDH_WMI_INIT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_PIPEOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_PROCESSOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_QUERYCONTEXTATTRIBUTES','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_QUERYREGISTRY','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_QUERYSECURITYCONTEXTTOKEN','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_REMOVEDIRECTORY','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_REPORTEVENT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_REVERTTOSELF','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_RSFXDEVICEOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SECURITYOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SERVICEOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SETENDOFFILE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SETFILEPOINTER','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SETFILEVALIDDATA','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SETNAMEDSECURITYINFO','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SQLCLROPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_SQMLAUNCH','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_VERIFYSIGNATURE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_VERIFYTRUST','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_VSSOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_WAITFORSINGLEOBJECT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_WINSOCKOPS','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_WRITEFILE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_WRITEFILEGATHER','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_OS_WSASETLASTERROR','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_REENLIST','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_RESIZELOG','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_ROLLFORWARDREDO','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_ROLLFORWARDUNDO','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SB_STOPENDPOINT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SERVER_STARTUP','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SETRMINFO','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SHAREDMEM_GETDATA','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SNIOPEN','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SOSHOST','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SOSTESTING','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_SP_SERVER_DIAGNOSTICS','Preemptive',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_STARTRM','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_STREAMFCB_CHECKPOINT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_STREAMFCB_RECOVER','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_STRESSDRIVER','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_TESTING','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_TRANSIMPORT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_UNMARSHALPROPAGATIONTOKEN','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_VSS_CREATESNAPSHOT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_VSS_CREATEVOLUMESNAPSHOT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_CALLBACKEXECUTE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_CX_FILE_OPEN','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_CX_HTTP_CALL','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_DISPATCHER','Preemptive',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_ENGINEINIT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_GETTARGETSTATE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_SESSIONCOMMIT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_TARGETFINALIZE','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_TARGETINIT','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XE_TIMERRUN','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PREEMPTIVE_XETESTING','Preemptive',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_ACTION_COMPLETED','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_CHANGE_NOTIFIER_TERMINATION_SYNC','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_CLUSTER_INTEGRATION','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_FAILOVER_COMPLETED','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_JOIN','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_OFFLINE_COMPLETED','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_ONLINE_COMPLETED','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_POST_ONLINE_COMPLETED','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_SERVER_READY_CONNECTIONS','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADR_WORKITEM_COMPLETED','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_HADRSIM','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('PWAIT_RESOURCE_SEMAPHORE_FT_PARALLEL_QUERY_SYNC','Full Text Search',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('QDS_ASYNC_QUEUE','Other',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP','Other',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('QDS_PERSIST_TASK_MAIN_LOOP_SLEEP','Other',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('QDS_SHUTDOWN_QUEUE','Other',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('QUERY_TRACEOUT','Tracing',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('REDO_THREAD_PENDING_WORK','Other',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('REPL_CACHE_ACCESS','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('REPL_HISTORYCACHE_ACCESS','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('REPL_SCHEMA_ACCESS','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('REPL_TRANFSINFO_ACCESS','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('REPL_TRANHASHTABLE_ACCESS','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('REPL_TRANTEXTINFO_ACCESS','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('REPLICA_WRITES','Replication',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('REQUEST_FOR_DEADLOCK_SEARCH','Idle',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('RESERVED_MEMORY_ALLOCATION_EXT','Memory',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('RESOURCE_SEMAPHORE','Memory',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('RESOURCE_SEMAPHORE_QUERY_COMPILE','Compilation',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_BPOOL_FLUSH','Idle',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_BUFFERPOOL_HELPLW','Idle',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_DBSTARTUP','Idle',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_DCOMSTARTUP','Idle',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_MASTERDBREADY','Idle',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_MASTERMDREADY','Idle',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_MASTERUPGRADED','Idle',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_MEMORYPOOL_ALLOCATEPAGES','Idle',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_MSDBSTARTUP','Idle',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_RETRY_VIRTUALALLOC','Idle',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_SYSTEMTASK','Idle',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_TASK','Idle',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_TEMPDBSTARTUP','Idle',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SLEEP_WORKSPACE_ALLOCATEPAGE','Idle',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SOS_SCHEDULER_YIELD','CPU',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SOS_WORK_DISPATCHER','Idle',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SP_SERVER_DIAGNOSTICS_SLEEP','Other',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SQLCLR_APPDOMAIN','SQL CLR',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SQLCLR_ASSEMBLY','SQL CLR',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SQLCLR_DEADLOCK_DETECTION','SQL CLR',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SQLCLR_QUANTUM_PUNISHMENT','SQL CLR',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_BUFFER_FLUSH','Idle',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_FILE_BUFFER','Tracing',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_FILE_READ_IO_COMPLETION','Tracing',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_FILE_WRITE_IO_COMPLETION','Tracing',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_INCREMENTAL_FLUSH_SLEEP','Idle',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_PENDING_BUFFER_WRITERS','Tracing',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_SHUTDOWN','Tracing',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('SQLTRACE_WAIT_ENTRIES','Idle',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('THREADPOOL','Worker Thread',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('TRACE_EVTNOTIF','Tracing',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('TRACEWRITE','Tracing',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('TRAN_MARKLATCH_DT','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('TRAN_MARKLATCH_EX','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('TRAN_MARKLATCH_KP','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('TRAN_MARKLATCH_NL','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('TRAN_MARKLATCH_SH','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('TRAN_MARKLATCH_UP','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('TRANSACTION_MUTEX','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('UCS_SESSION_REGISTRATION','Other',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('WAIT_FOR_RESULTS','User Wait',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('WAIT_XTP_OFFLINE_CKPT_NEW_LOG','Other',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('WAITFOR','User Wait',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('WRITE_COMPLETION','Other Disk IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('WRITELOG','Tran Log IO',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('XACT_OWN_TRANSACTION','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('XACT_RECLAIM_SESSION','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('XACTLOCKINFO','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('XACTWORKSPACE_MUTEX','Transaction',0);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('XE_DISPATCHER_WAIT','Idle',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('XE_LIVE_TARGET_TVF','Other',1);
			INSERT INTO dbo.fhsmWaitCategories(WaitType, WaitCategory, Ignorable) VALUES ('XE_TIMER_EVENT','Idle',1);
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
		-- Create fact view @pbiSchema.[Wait statistics]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Wait statistics') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Wait statistics') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Wait statistics') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				WITH waitStatistics AS (
					SELECT
						ws.WaitType
						,ws.SumWaitTimeMS
						,ws.SumSignalWaitTimeMS
						,ws.SumWaitingTasks
						,ws.LastSQLServiceRestart
						,ws.TimestampUTC
						,ws.Timestamp
						,ROW_NUMBER() OVER(PARTITION BY ws.WaitType ORDER BY ws.TimestampUTC) AS Idx
					FROM dbo.fhsmWaitStatistics AS ws
				)
				';
			END;
			SET @stmt += '
				SELECT
					b.DeltaSumWaitTimeMS AS WaitTimeMS
					,b.DeltaSumSignalWaitTimeMS AS SignalWaitTimeMS
					,b.DeltaSumWaitingTasks AS WaitingTasks

					,b.Timestamp
					,CAST(b.Timestamp AS date) AS Date
					,(DATEPART(HOUR, b.Timestamp) * 60 * 60) + (DATEPART(MINUTE, b.Timestamp) * 60) + (DATEPART(SECOND, b.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(b.WaitType, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS WaitKey
				FROM (
					SELECT
						CASE
							WHEN (DATEDIFF(HOUR, a.PreviousTimestampUTC, a.TimestampUTC) > 12) OR (a.PreviousSumWaitTimeMS IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL	-- Ignore 1. data set - Yes we loose one data set but better than having visuals showing very high data
							WHEN (a.PreviousSumWaitTimeMS > a.SumWaitTimeMS) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.SumWaitTimeMS							-- Either has the counters had an overflow or the server har been restarted
							ELSE a.SumWaitTimeMS - a.PreviousSumWaitTimeMS																													-- Difference
						END AS DeltaSumWaitTimeMS
						,CASE
							WHEN (DATEDIFF(HOUR, a.PreviousTimestampUTC, a.TimestampUTC) > 12) OR (a.PreviousSumSignalWaitTimeMS IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousSumSignalWaitTimeMS > a.SumSignalWaitTimeMS) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.SumSignalWaitTimeMS
							ELSE a.SumSignalWaitTimeMS - a.PreviousSumSignalWaitTimeMS
						END AS DeltaSumSignalWaitTimeMS
						,CASE
							WHEN (DATEDIFF(HOUR, a.PreviousTimestampUTC, a.TimestampUTC) > 12) OR (a.PreviousSumWaitingTasks IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousSumWaitingTasks > a.SumWaitingTasks) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.SumWaitingTasks
							ELSE a.SumWaitingTasks - a.PreviousSumWaitingTasks
						END AS DeltaSumWaitingTasks

						,a.Timestamp
						,a.WaitType
					FROM (
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
						SELECT
							ws.SumWaitTimeMS
							,prevWs.SumWaitTimeMS AS PreviousSumWaitTimeMS
							,ws.SumSignalWaitTimeMS
							,prevWs.SumSignalWaitTimeMS AS PreviousSumSignalWaitTimeMS
							,ws.SumWaitingTasks
							,prevWs.SumWaitingTasks AS PreviousSumWaitingTasks
							,ws.LastSQLServiceRestart
							,prevWs.LastSQLServiceRestart AS PreviousLastSQLServiceRestart
							,ws.TimestampUTC
							,prevWs.TimestampUTC AS PreviousTimestampUTC

							,ws.Timestamp
							,ws.WaitType
						FROM waitStatistics AS ws
						LEFT OUTER JOIN waitStatistics AS prevWs ON
							(prevWs.WaitType = ws.WaitType)
							AND (prevWs.Idx = ws.Idx - 1)
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
						SELECT
							ws.SumWaitTimeMS
							,LAG(ws.SumWaitTimeMS) OVER(PARTITION BY ws.WaitType ORDER BY ws.TimestampUTC) AS PreviousSumWaitTimeMS
							,ws.SumSignalWaitTimeMS
							,LAG(ws.SumSignalWaitTimeMS) OVER(PARTITION BY ws.WaitType ORDER BY ws.TimestampUTC) AS PreviousSumSignalWaitTimeMS
							,ws.SumWaitingTasks
							,LAG(ws.SumWaitingTasks) OVER(PARTITION BY ws.WaitType ORDER BY ws.TimestampUTC) AS PreviousSumWaitingTasks
							,ws.LastSQLServiceRestart
							,LAG(ws.LastSQLServiceRestart) OVER(PARTITION BY ws.WaitType ORDER BY ws.TimestampUTC) AS PreviousLastSQLServiceRestart
							,ws.TimestampUTC
							,LAG(ws.TimestampUTC) OVER(PARTITION BY ws.WaitType ORDER BY ws.TimestampUTC) AS PreviousTimestampUTC

							,ws.Timestamp
							,ws.WaitType
						FROM dbo.fhsmWaitStatistics AS ws
				';
			END;
			SET @stmt += '
					) AS a
				) AS b
				WHERE
					(b.DeltaSumWaitTimeMS <> 0)
					OR (b.DeltaSumSignalWaitTimeMS <> 0)
					OR (b.DeltaSumWaitingTasks <> 0);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Wait statistics]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Wait statistics');
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
		-- Create stored procedure dbo.fhsmSPWaitStatistics
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPWaitStatistics'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPWaitStatistics AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPWaitStatistics (
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameter nvarchar(max);
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);
					SET @version = ''' + @version + ''';

					--
					-- Get the parameter for the command
					--
					BEGIN
						SET @parameter = dbo.fhsmFNGetTaskParameter(@thisTask, @name);
					END;

					--
					-- Collect data
					--
					BEGIN
						SELECT
							@now = SYSDATETIME()
							,@nowUTC = SYSUTCDATETIME();

						SET @stmt = ''
							SELECT
								a.wait_type AS WaitType
								,SUM(a.sum_wait_time_ms) AS SumWaitTimeMS
								,SUM(a.sum_signal_wait_time_ms) AS SumSignalWaitTimeMS
								,SUM(a.sum_waiting_tasks) AS SumWaitingTasks
								,(SELECT d.create_date FROM sys.databases AS d WITH (NOLOCK) WHERE (d.name = ''''tempdb'''')) AS LastSQLServiceRestart
								,@nowUTC, @now
							FROM (
								SELECT
									owt.wait_type
									,SUM(owt.wait_duration_ms) AS sum_wait_time_ms
									,0 AS sum_signal_wait_time_ms
									,0 AS sum_waiting_tasks
								FROM sys.dm_os_waiting_tasks AS owt WITH (NOLOCK)
								WHERE (owt.session_id > 50)
								GROUP BY owt.wait_type

								UNION ALL

								SELECT
									os.wait_type
									,SUM(os.wait_time_ms) AS sum_wait_time_ms
									,SUM(os.signal_wait_time_ms) AS sum_signal_wait_time_ms
									,SUM(os.waiting_tasks_count) AS sum_waiting_tasks
								FROM sys.dm_os_wait_stats AS os WITH (NOLOCK)
								GROUP BY os.wait_type
							) a
							WHERE EXISTS (
								SELECT *
								FROM dbo.fhsmWaitCategories AS wc
								WHERE (wc.WaitType COLLATE DATABASE_DEFAULT = a.wait_type)
									AND (wc.Ignorable = 0)
							)
							GROUP BY a.wait_type;
						'';
						INSERT INTO dbo.fhsmWaitStatistics(
							WaitType
							,SumWaitTimeMS, SumSignalWaitTimeMS, SumWaitingTasks
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
		-- Register extended properties on the stored procedure dbo.fhsmSPWaitStatistics
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPWaitStatistics';
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
		retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter) AS(
			SELECT
				1
				,'dbo.fhsmWaitStatistics'
				,1
				,'TimestampUTC'
				,1
				,30
				,NULL
		)
		MERGE dbo.fhsmRetentions AS tgt
		USING retention AS src ON (src.TableName = tgt.TableName) AND (src.Sequence = tgt.Sequence)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter)
			VALUES(src.Enabled, src.TableName, src.Sequence, src.TimeColumn, src.IsUtc, src.Days, src.Filter);
	END;

	--
	-- Register schedules
	--
	BEGIN
		WITH
		schedules(Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameter) AS(
			SELECT
				@enableWaitStatistics							AS Enabled
				,0												AS DeploymentStatus
				,'Wait statistics'								AS Name
				,PARSENAME('dbo.fhsmSPWaitStatistics', 1)		AS Task
				,1 * 60 * 60									AS ExecutionDelaySec
				,CAST('1900-1-1T00:00:00.0000' AS datetime2(0))	AS FromTime
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))	AS ToTime
				,1, 1, 1, 1, 1, 1, 1							-- Monday..Sunday
				,NULL											AS Parameter
		)
		MERGE dbo.fhsmSchedules AS tgt
		USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
		WHEN MATCHED AND (tgt.Enabled = 0) AND (src.Enabled = 1)
			THEN UPDATE
				SET tgt.Enabled = src.Enabled
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameter)
			VALUES(src.Enabled, src.DeploymentStatus, src.Name, src.Task, src.ExecutionDelaySec, src.FromTime, src.ToTime, src.Monday, src.Tuesday, src.Wednesday, src.Thursday, src.Friday, src.Saturday, src.Sunday, src.Parameter);
	END;

	--
	-- Register dimensions
	--
	BEGIN
		WITH
		dimensions(
			DimensionName, DimensionKey
			,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
			,SrcColumn1
			,OutputColumn1
		) AS (
			SELECT
				'Wait type' AS DimensionName
				,'WaitKey' AS DimensionKey
				,'dbo.fhsmWaitStatistics' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[WaitType]'
				,'Wait type'
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
				,tgt.OutputColumn1 = src.OutputColumn1
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(
				DimensionName, DimensionKey
				,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
				,SrcColumn1
				,OutputColumn1
			)
			VALUES(
				src.DimensionName, src.DimensionKey
				,src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn
				,src.SrcColumn1
				,src.OutputColumn1
			);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmWaitStatistics';
	END;
END;
