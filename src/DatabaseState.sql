SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableDatabaseState bit;

	SET @enableDatabaseState = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing DatabaseState', 0, 1) WITH NOWAIT;
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
		SET @version = '2.9.1';

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
		-- Create table dbo.fhsmAlwaysOnState and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmAlwaysOnState', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmAlwaysOnState', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmAlwaysOnState(
						Id int identity(1,1) NOT NULL
						,Query int NOT NULL
						,GroupA nvarchar(128) NOT NULL
						,GroupB nvarchar(128) NOT NULL
						,GroupC nvarchar(128) NOT NULL
						,[Key] nvarchar(128) NOT NULL
						,Value nvarchar(max) NOT NULL
						,ValidFrom datetime NOT NULL
						,ValidTo datetime NOT NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmAlwaysOnState PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAlwaysOnState')) AND (i.name = 'NC_fhsmAlwaysOnState_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAlwaysOnState_TimestampUTC] to table dbo.fhsmAlwaysOnState', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAlwaysOnState_TimestampUTC ON dbo.fhsmAlwaysOnState(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAlwaysOnState')) AND (i.name = 'NC_fhsmAlwaysOnState_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmAlwaysOnState_Timestamp] to table dbo.fhsmAlwaysOnState', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmAlwaysOnState_Timestamp ON dbo.fhsmAlwaysOnState(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmAlwaysOnState
			--
			BEGIN
				SET @objectName = 'dbo.fhsmAlwaysOnState';
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
		-- Create table dbo.fhsmDatabaseState and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmDatabaseState', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmDatabaseState', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmDatabaseState(
						Id int identity(1,1) NOT NULL
						,Query int NOT NULL
						,DatabaseName nvarchar(128) NOT NULL
						,[Key] nvarchar(128) NOT NULL
						,Value nvarchar(max) NOT NULL
						,ValidFrom datetime NOT NULL
						,ValidTo datetime NOT NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmDatabaseState PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmDatabaseState')) AND (i.name = 'NC_fhsmDatabaseState_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmDatabaseState_TimestampUTC] to table dbo.fhsmDatabaseState', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmDatabaseState_TimestampUTC ON dbo.fhsmDatabaseState(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmDatabaseState')) AND (i.name = 'NC_fhsmDatabaseState_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmDatabaseState_Timestamp] to table dbo.fhsmDatabaseState', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmDatabaseState_Timestamp ON dbo.fhsmDatabaseState(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmDatabaseState')) AND (i.name = 'NC_fhsmDatabaseState_Query_DatabaseName_Key_ValidTo'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmDatabaseState_Query_DatabaseName_Key_ValidTo] to table dbo.fhsmDatabaseState', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmDatabaseState_Query_DatabaseName_Key_ValidTo ON dbo.fhsmDatabaseState(Query, DatabaseName, [Key], ValidTo) INCLUDE(Value)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmDatabaseState')) AND (i.name = 'NC_fhsmDatabaseState_ValidTo_Query_DatabaseName_key'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmDatabaseState_ValidTo_Query_DatabaseName_key] to table dbo.fhsmDatabaseState', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmDatabaseState_ValidTo_Query_DatabaseName_key ON dbo.fhsmDatabaseState(ValidTo, Query, DatabaseName, [Key]) INCLUDE(Value)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmDatabaseState
			--
			BEGIN
				SET @objectName = 'dbo.fhsmDatabaseState';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
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
		-- Always On database states
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On database states') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On database states') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On database states') + '
				AS
					SELECT
						pvt.GroupA														AS AGGroupName
						,pvt.GroupB														AS AGReplicaName
						,pvt.GroupC														AS AGDatabaseName
						,CASE pvt.is_local
							WHEN ''0'' THEN ''No''
							WHEN ''1'' THEN ''Yes''
						END																AS IsLocal
						,CASE pvt.is_primary_replica
							WHEN ''0'' THEN ''No''
							WHEN ''1'' THEN ''Yes''
						END																AS IsPrimaryReplica
						,dbo.fhsmFNConvertToDisplayTxt(pvt.synchronization_state_desc)	AS SynchronizationState
						,CASE pvt.is_commit_participant
							WHEN ''0'' THEN ''No''
							WHEN ''1'' THEN ''Yes''
						END																AS IsCommitParticipant
						,dbo.fhsmFNConvertToDisplayTxt(pvt.synchronization_health_desc)	AS SynchronizationHealth
						,dbo.fhsmFNConvertToDisplayTxt(pvt.database_state_desc)			AS DatabaseState
						,CASE pvt.is_suspended
							WHEN ''0'' THEN ''No''
							WHEN ''1'' THEN ''Yes''
						END																AS IsSuspended
						,dbo.fhsmFNConvertToDisplayTxt(pvt.suspend_reason_desc)			AS SuspendReason
						,(SELECT MIN(aoState.Timestamp) FROM dbo.fhsmAlwaysOnState AS aoState WHERE (aoState.GroupA = pvt.GroupA) AND (aoState.GroupB = pvt.GroupB) AND (aoState.GroupC = pvt.GroupC) AND (aoState.Query = 6) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MinTimestamp
						,(SELECT MAX(aoState.Timestamp) FROM dbo.fhsmAlwaysOnState AS aoState WHERE (aoState.GroupA = pvt.GroupA) AND (aoState.GroupB = pvt.GroupB) AND (aoState.GroupC = pvt.GroupC) AND (aoState.Query = 6) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MaxTimestamp
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.GroupA, DEFAULT,    DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS AlwaysOnGroupKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.GroupA, pvt.GroupB, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS AlwaysOnGroupReplicaKey
					FROM (
						SELECT aoState.GroupA, aoState.GroupB, aoState.GroupC, aoState.[Key], aoState.Value AS _Value_
						FROM dbo.fhsmAlwaysOnState AS aoState
						WHERE (aoState.Query = 6) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN (
							[database_state_desc], [is_commit_participant], [is_local], [is_primary_replica],
							[is_suspended], [suspend_reason_desc], [synchronization_health_desc], [synchronization_state_desc]
						)
					) AS pvt;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Always On database states]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On database states');
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
		-- Always On group states
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On group states') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On group states') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On group states') + '
				AS
					SELECT
						pvt.GroupA															AS AGGroupName
						,pvt.GroupB															AS AGReplicaName
						,dbo.fhsmFNConvertToDisplayTxt(pvt.primary_recovery_health_desc)	AS PrimaryRecoveryHealth
						,dbo.fhsmFNConvertToDisplayTxt(pvt.secondary_recovery_health_desc)	AS SecondaryRecoveryHealth
						,dbo.fhsmFNConvertToDisplayTxt(pvt.synchronization_health_desc)		AS SynchronizationHealth
						,(SELECT MIN(aoState.Timestamp) FROM dbo.fhsmAlwaysOnState AS aoState WHERE (aoState.GroupA = pvt.GroupA) AND (aoState.GroupB = pvt.GroupB) AND (aoState.Query = 3) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MinTimestamp
						,(SELECT MAX(aoState.Timestamp) FROM dbo.fhsmAlwaysOnState AS aoState WHERE (aoState.GroupA = pvt.GroupA) AND (aoState.GroupB = pvt.GroupB) AND (aoState.Query = 3) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MaxTimestamp
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.GroupA, DEFAULT,    DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS AlwaysOnGroupKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.GroupA, pvt.GroupB, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS AlwaysOnGroupReplicaKey
					FROM (
						SELECT aoState.GroupA, aoState.GroupB, aoState.[Key], aoState.Value AS _Value_
						FROM dbo.fhsmAlwaysOnState AS aoState
						WHERE (aoState.Query = 3) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN (
							[primary_recovery_health_desc], [secondary_recovery_health_desc],
							[synchronization_health_desc]
						)
					) AS pvt;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Always On group states]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On group states');
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
		-- Always On read only routing
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On read only routing') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On read only routing') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On read only routing') + '
				AS
					SELECT
						pvt.GroupA																	AS AGGroupName
						,pvt.GroupB																	AS AGSrcReplicaName
						,pvt.GroupC																	AS AGReplReplicaName
						,pvt.read_only_routing_url													AS ReadOnlyRoutingURL
						,CAST(pvt.routing_priority AS int)											AS RoutingPriority
						,dbo.fhsmFNConvertToDisplayTxt(pvt.secondary_role_allow_connections_desc)	AS SecondaryRoleAllowConnections
						,(SELECT MIN(aoState.Timestamp) FROM dbo.fhsmAlwaysOnState AS aoState WHERE (aoState.GroupA = pvt.GroupA) AND (aoState.GroupB = pvt.GroupB) AND (aoState.GroupC = pvt.GroupC) AND (aoState.Query = 4) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MinTimestamp
						,(SELECT MAX(aoState.Timestamp) FROM dbo.fhsmAlwaysOnState AS aoState WHERE (aoState.GroupA = pvt.GroupA) AND (aoState.GroupB = pvt.GroupB) AND (aoState.GroupC = pvt.GroupC) AND (aoState.Query = 4) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MaxTimestamp
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.GroupA, DEFAULT,    DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS AlwaysOnGroupKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.GroupA, pvt.GroupB, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS AlwaysOnGroupReplicaKey
					FROM (
						SELECT aoState.GroupA, aoState.GroupB, aoState.GroupC, aoState.[Key], aoState.Value AS _Value_
						FROM dbo.fhsmAlwaysOnState AS aoState
						WHERE (aoState.Query = 4) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN (
							[read_only_routing_url], [routing_priority],
							[secondary_role_allow_connections_desc]
						)
					) AS pvt;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Always On read only routing]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On read only routing');
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
		-- Always On replicas
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On replicas') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On replicas') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On replicas') + '
				AS
					SELECT
						pvt.GroupA																	AS AGGroupName
						,pvt.GroupB																	AS AGReplicaName
						,pvt.endpoint_url															AS EndpointURL
						,dbo.fhsmFNConvertToDisplayTxt(pvt.availability_mode_desc)					AS AvailabilityMode
						,dbo.fhsmFNConvertToDisplayTxt(pvt.failover_mode_desc)						AS FailoverMode
						,dbo.fhsmFNConvertToDisplayTxt(pvt.primary_role_allow_connections_desc)		AS PrimaryRoleAllowConnections
						,dbo.fhsmFNConvertToDisplayTxt(pvt.secondary_role_allow_connections_desc)	AS SecondaryRoleAllowConnections
						,CAST(pvt.backup_priority AS int)											AS BackupPriority
						,pvt.read_only_routing_url													AS ReadOnlyRoutingURL
						,pvt.read_write_routing_url													AS ReadWriteRoutingURL
						,(SELECT MIN(aoState.Timestamp) FROM dbo.fhsmAlwaysOnState AS aoState WHERE (aoState.GroupA = pvt.GroupA) AND (aoState.GroupB = pvt.GroupB) AND (aoState.Query = 5) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MinTimestamp
						,(SELECT MAX(aoState.Timestamp) FROM dbo.fhsmAlwaysOnState AS aoState WHERE (aoState.GroupA = pvt.GroupA) AND (aoState.GroupB = pvt.GroupB) AND (aoState.Query = 5) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MaxTimestamp
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.GroupA, DEFAULT,    DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS AlwaysOnGroupKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.GroupA, pvt.GroupB, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS AlwaysOnGroupReplicaKey
					FROM (
						SELECT aoState.GroupA, aoState.GroupB, aoState.[Key], aoState.Value AS _Value_
						FROM dbo.fhsmAlwaysOnState AS aoState
						WHERE (aoState.Query = 5) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN (
							[availability_mode_desc], [backup_priority], [endpoint_url], [failover_mode_desc],
							[primary_role_allow_connections_desc], [read_only_routing_url], [read_write_routing_url],
							[secondary_role_allow_connections_desc]
						)
					) AS pvt;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Always On replicas]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Always On replicas');
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
		-- Create fact view @pbiSchema.[Database state]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database state') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database state') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database state') + '
				AS
					SELECT
						pvt.DatabaseName
						,pvt.collation_name AS CollationName
						,CAST(pvt.compatibility_level AS int) AS CompatibilityLevel
						,CASE pvt.delayed_durability
							WHEN 0 THEN ''DISABLED''
							WHEN 1 THEN ''ALLOWED''
							WHEN 2 THEN ''FORCED''
							ELSE ''?:'' + pvt.delayed_durability
						END AS DelayedDurability
						,CAST(pvt.is_auto_close_on AS bit) AS IsAutoCloseOn
						,CAST(pvt.is_auto_shrink_on AS bit) AS IsAutoShrinkOn
						,CAST(pvt.is_auto_update_stats_async_on AS bit) AS IsAutoUpdateStatsAsyncOn
						,CAST(pvt.is_encrypted AS bit) AS IsEncrypted
						,CAST(pvt.is_mixed_page_allocation_on AS bit) AS IsMixedPageAllocationOn
						,CASE pvt.page_verify_option
							WHEN 0 THEN ''NONE''
							WHEN 1 THEN ''TORN_PAGE_DETECTION''
							WHEN 2 THEN ''CHECKSUM''
							ELSE ''?:'' + pvt.page_verify_option
						END AS PageVerifyOption
						,CAST(pvt.is_read_committed_snapshot_on AS bit) AS IsReadCommittedSnapshotOn
						,CASE pvt.recovery_model
							WHEN 1 THEN ''FULL''
							WHEN 2 THEN ''BULK_LOGGED''
							WHEN 3 THEN ''SIMPLE''
							ELSE ''?:'' + pvt.recovery_model
						END AS RecoveryModel
						,CAST(pvt.target_recovery_time_in_seconds AS int) AS TargetRecoveryTimeInSeconds
						,pvt.replica_id AS ReplicaId
						,pvt.AlwaysOnGroupName
						,CAST(pvt.IsOnAlwaysOnPrimary AS int) AS IsOnAlwaysOnPrimary
						,(SELECT MIN(dbState.Timestamp) FROM dbo.fhsmDatabaseState AS dbState WHERE (dbState.DatabaseName = pvt.DatabaseName) AND (dbState.Query = 31) AND (dbState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MinTimestamp
						,(SELECT MAX(dbState.Timestamp) FROM dbo.fhsmDatabaseState AS dbState WHERE (dbState.DatabaseName = pvt.DatabaseName) AND (dbState.Query = 31) AND (dbState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MaxTimestamp
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pvt.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					FROM (
						SELECT dbState.DatabaseName, dbState.[Key], dbState.Value AS _Value_
						FROM (
							SELECT DISTINCT dbState.DatabaseName
							FROM dbo.fhsmDatabaseState AS dbState
							WHERE
								(dbState.Query = 31)
								AND (dbState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS toCheck
						INNER JOIN dbo.fhsmDatabaseState AS dbState ON (dbState.DatabaseName = toCheck.DatabaseName)
						WHERE (dbState.Query = 31) AND (dbState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN (
							[collation_name], [compatibility_level], [delayed_durability]
							,[is_auto_close_on], [is_auto_shrink_on], [is_auto_update_stats_async_on], [is_encrypted], [is_mixed_page_allocation_on]
							,[is_read_committed_snapshot_on], [page_verify_option], [recovery_model], [target_recovery_time_in_seconds]
							,[replica_id], [AlwaysOnGroupName], [IsOnAlwaysOnPrimary])
					) AS pvt;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Database state]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database state');
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
		-- Create fact view @pbiSchema.[Database state history]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database state history') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database state history') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database state history') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				WITH databaseState AS (
					SELECT
						dbState.DatabaseName, dbState.[Key], dbState.Value, dbState.TimestampUTC, dbState.ValidFrom, dbState.ValidTo
						,ROW_NUMBER() OVER(PARTITION BY dbState.DatabaseName, dbState.[Key] ORDER BY dbState.ValidTo DESC) AS Idx
					FROM (
						SELECT DISTINCT dbState.DatabaseName
						FROM dbo.fhsmDatabaseState AS dbState
						WHERE
							(dbState.Query = 31)
							AND (dbState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS toCheck
					INNER JOIN dbo.fhsmDatabaseState AS dbState ON (dbState.DatabaseName = toCheck.DatabaseName)
					WHERE (dbState.Query = 31)
						AND (dbState.[Key] IN (
							''collation_name'', ''compatibility_level'', ''delayed_durability''
							,''is_auto_close_on'', ''is_auto_shrink_on'', ''is_auto_update_stats_async_on'', ''is_encrypted'', ''is_mixed_page_allocation_on''
							,''is_read_committed_snapshot_on'', ''page_verify_option'', ''recovery_model'', ''target_recovery_time_in_seconds''
							,''AlwaysOnGroupName'', ''IsOnAlwaysOnPrimary''
						))
				)
				';
			END;
			SET @stmt += '
					SELECT
						''Standard'' AS Type
						,a.DatabaseName
						,CASE a.[Key]
							WHEN ''collation_name'' THEN ''Collation''
							WHEN ''compatibility_level'' THEN ''Comp. level''
							WHEN ''delayed_durability'' THEN ''Delayed durability''
							WHEN ''is_auto_close_on'' THEN ''Auto close''
							WHEN ''is_auto_shrink_on'' THEN ''Auto shrink''
							WHEN ''is_auto_update_stats_async_on'' THEN ''Auto update stats. async.''
							WHEN ''is_encrypted'' THEN ''Encrypted''
							WHEN ''is_mixed_page_allocation_on'' THEN ''Mixed page allocation''
							WHEN ''is_read_committed_snapshot_on'' THEN ''Is read committed snapshot on''
							WHEN ''page_verify_option'' THEN ''Page verify''
							WHEN ''recovery_model'' THEN ''Recovery model''
							WHEN ''target_recovery_time_in_seconds'' THEN ''Target recovery time in sec.''
							WHEN ''AlwaysOnGroupName'' THEN ''AlwaysOn group''
							WHEN ''IsOnAlwaysOnPrimary'' THEN ''Is on AlwaysOn primary''
							ELSE a.[Key]
						END AS [Key]
						,a.ValidFrom
						,NULLIF(a.ValidTo, ''9999-12-31 23:59:59.000'') AS ValidTo
						,CASE a.[Key]
							WHEN ''delayed_durability''
								THEN CASE a.Value
									WHEN 0 THEN ''DISABLED''
									WHEN 1 THEN ''ALLOWED''
									WHEN 2 THEN ''FORCED''
									ELSE ''?:'' + a.Value
								END
							WHEN ''is_auto_close_on''
								THEN CASE a.Value
									WHEN 0 THEN ''False''
									WHEN 1 THEN ''True''
									ELSE ''?:'' + a.Value
								END
							WHEN ''is_auto_shrink_on''
								THEN CASE a.Value
									WHEN 0 THEN ''False''
									WHEN 1 THEN ''True''
									ELSE ''?:'' + a.Value
								END
							WHEN ''is_auto_update_stats_async_on''
								THEN CASE a.Value
									WHEN 0 THEN ''False''
									WHEN 1 THEN ''True''
									ELSE ''?:'' + a.Value
								END
							WHEN ''is_encrypted''
								THEN CASE a.Value
									WHEN 0 THEN ''False''
									WHEN 1 THEN ''True''
									ELSE ''?:'' + a.Value
								END
							WHEN ''is_mixed_page_allocation_on''
								THEN CASE a.Value
									WHEN 0 THEN ''False''
									WHEN 1 THEN ''True''
									ELSE ''?:'' + a.Value
								END
							WHEN ''page_verify_option''
								THEN CASE a.Value
									WHEN 0 THEN ''NONE''
									WHEN 1 THEN ''TORN_PAGE_DETECTION''
									WHEN 2 THEN ''CHECKSUM''
									ELSE ''?:'' + a.Value
								END
							WHEN ''is_read_committed_snapshot_on''
								THEN CASE a.Value
									WHEN 0 THEN ''False''
									WHEN 1 THEN ''True''
									ELSE ''?:'' + a.Value
								END
							WHEN ''recovery_model''
								THEN CASE a.Value
									WHEN 1 THEN ''FULL''
									WHEN 2 THEN ''BULK_LOGGED''
									WHEN 3 THEN ''SIMPLE''
									ELSE ''?:'' + a.Value
								END
							WHEN ''IsOnAlwaysOnPrimary''
								THEN CASE a.Value
									WHEN 1 THEN ''Yes''
									WHEN 2 THEN ''No''
									WHEN 3 THEN ''N.A.''
									ELSE ''?:'' + a.Value
								END
							ELSE a.Value
						END AS Value
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					FROM (
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
						SELECT
							dbState.DatabaseName, dbState.[Key], dbState.Value, dbState.TimestampUTC, dbState.ValidFrom, dbState.ValidTo
							,prevDBState.Value AS PreviousValue
						FROM databaseState AS dbState
						LEFT OUTER JOIN databaseState AS prevDBState ON
							(prevDBState.DatabaseName = dbState.DatabaseName)
							AND (prevDBState.[Key] = dbState.[Key])
							AND (prevDBState.Idx = dbState.Idx - 1)
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
						SELECT
							dbState.DatabaseName, dbState.[Key], dbState.Value, dbState.TimestampUTC, dbState.ValidFrom, dbState.ValidTo
							,LAG(dbState.Value) OVER(PARTITION BY dbState.DatabaseName, dbState.[Key] ORDER BY dbState.ValidTo DESC) AS PreviousValue
						FROM (
							SELECT DISTINCT dbState.DatabaseName
							FROM dbo.fhsmDatabaseState AS dbState
							WHERE
								(dbState.Query = 31)
								AND (dbState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS toCheck
						INNER JOIN dbo.fhsmDatabaseState AS dbState ON (dbState.DatabaseName = toCheck.DatabaseName)
						WHERE (dbState.Query = 31)
							AND (dbState.[Key] IN (
								''collation_name'', ''compatibility_level'', ''delayed_durability''
								,''is_auto_close_on'', ''is_auto_shrink_on'', ''is_auto_update_stats_async_on'', ''is_encrypted'', ''is_mixed_page_allocation_on''
								,''is_read_committed_snapshot_on'', ''page_verify_option'', ''recovery_model'', ''target_recovery_time_in_seconds''
								,''AlwaysOnGroupName'', ''IsOnAlwaysOnPrimary''
							))
				';
			END;
			SET @stmt += '
					) AS a
					WHERE ((a.Value <> a.PreviousValue) OR (a.PreviousValue IS NULL))
			';
			IF (@productVersion1 >= 13)
			BEGIN
				-- SQL Versions SQL2016 or higher

				SET @stmt += '
					UNION ALL

					SELECT
						''Scoped'' AS Type
						,a.DatabaseName
						,a.[Key]
						,a.ValidFrom
						,NULLIF(a.ValidTo, ''9999-12-31 23:59:59.000'') AS ValidTo
						,a.Value
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					FROM (
						SELECT
							dbState.DatabaseName, dbState.[Key], dbState.Value, dbState.TimestampUTC, dbState.ValidFrom, dbState.ValidTo
							,LAG(dbState.Value) OVER(PARTITION BY dbState.DatabaseName, dbState.[Key] ORDER BY dbState.ValidTo DESC) AS PreviousValue
						FROM (
							SELECT DISTINCT dbState.DatabaseName
							FROM dbo.fhsmDatabaseState AS dbState
							WHERE
								(dbState.Query = 60)
								AND (dbState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS toCheck
						INNER JOIN dbo.fhsmDatabaseState AS dbState ON (dbState.DatabaseName = toCheck.DatabaseName)
						WHERE (dbState.Query = 60)
							AND EXISTS (
								SELECT *
								FROM dbo.fhsmDatabaseState AS dbDefault
								WHERE
									(dbDefault.Query = 2060)
									AND (dbDefault.DatabaseName = dbState.DatabaseName)
									AND (dbDefault.[Key] = dbState.[Key])
									AND (dbDefault.Value <> 1)
							)
					) AS a
					WHERE ((a.Value <> a.PreviousValue) OR (a.PreviousValue IS NULL))
				';

				SET @stmt += '
					UNION ALL

					SELECT
						''Scoped secondary'' AS Type
						,a.DatabaseName
						,a.[Key]
						,a.ValidFrom
						,NULLIF(a.ValidTo, ''9999-12-31 23:59:59.000'') AS ValidTo
						,a.Value
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					FROM (
						SELECT
							dbState.DatabaseName, dbState.[Key], dbState.Value, dbState.TimestampUTC, dbState.ValidFrom, dbState.ValidTo
							,LAG(dbState.Value) OVER(PARTITION BY dbState.DatabaseName, dbState.[Key] ORDER BY dbState.ValidTo DESC) AS PreviousValue
						FROM (
							SELECT DISTINCT dbState.DatabaseName
							FROM dbo.fhsmDatabaseState AS dbState
							WHERE
								(dbState.Query = 1060)
								AND (dbState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS toCheck
						INNER JOIN dbo.fhsmDatabaseState AS dbState ON (dbState.DatabaseName = toCheck.DatabaseName)
						WHERE (dbState.Query = 1060)
							AND EXISTS (
								SELECT *
								FROM dbo.fhsmDatabaseState AS dbDefault
								WHERE
									(dbDefault.Query = 2060)
									AND (dbDefault.DatabaseName = dbState.DatabaseName)
									AND (dbDefault.[Key] = dbState.[Key])
									AND (dbDefault.Value <> 1)
							)
					) AS a
					WHERE ((a.Value <> a.PreviousValue) OR (a.PreviousValue IS NULL));
				';
			END;
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Database state history]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database state history');
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
		-- Create fact view @pbiSchema.[Database scoped configuration]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database scoped configuration') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database scoped configuration') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database scoped configuration') + '
				AS
					SELECT
						ds.[Key]
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ds.[Key], DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseScopedConfigurationKey
					FROM (
						SELECT DISTINCT ds.[Key]
						FROM dbo.fhsmDatabaseState AS ds
						WHERE
							(ds.Query IN (60, 1060, 2060))
					) AS ds;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Database scoped configuration]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database scoped configuration');
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
		-- Create fact view @pbiSchema.[Database scoped configurations]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database scoped configurations') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database scoped configurations') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database scoped configurations') + '
				AS
					SELECT
						ds.DatabaseName
						,ds.[Key]
						,ds.Value
						,dsSecondary.Value AS ValueForSecondary
						,CAST(dsDefault.Value AS int) AS DefaultState
						,ROW_NUMBER() OVER(
							ORDER BY
								CASE
									WHEN (dsDefault.Value = 0) THEN 1
									ELSE 2
								END
								,ds.DatabaseName
								,ds.[Key]
						) AS ConfigurationSortOrder
						,ds.Timestamp
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ds.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ds.[Key],        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseScopedConfigurationKey
					FROM (
						SELECT ds.DatabaseName, ds.[Key], ds.Value, ds.Timestamp
						FROM dbo.fhsmDatabaseState AS ds
						WHERE
							(ds.Query = 60)
							AND (ds.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS ds
					LEFT OUTER JOIN (
						SELECT ds.DatabaseName, ds.[Key], ds.Value
						FROM dbo.fhsmDatabaseState AS ds
						WHERE
							(ds.Query = 1060)
							AND (ds.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS dsSecondary ON (dsSecondary.DatabaseName = ds.DatabaseName) AND (dsSecondary.[Key] = ds.[Key])
					LEFT OUTER JOIN (
						SELECT ds.DatabaseName, ds.[Key], ds.Value
						FROM dbo.fhsmDatabaseState AS ds
						WHERE
							(ds.Query = 2060)
							AND (ds.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS dsDefault ON (dsDefault.DatabaseName = ds.DatabaseName) AND (dsDefault.[Key] = ds.[Key]);
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Database scoped configurations]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database scoped configurations');
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
		-- WSFC quorum members
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('WSFC quorum members') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('WSFC quorum members') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('WSFC quorum members') + '
				AS
					SELECT
						pvt.GroupA												AS WSFCQuorumMember
						,dbo.fhsmFNConvertToDisplayTxt(pvt.member_type_desc)	AS MemberType
						,dbo.fhsmFNConvertToDisplayTxt(pvt.member_state_desc)	AS MemberState
						,CAST(pvt.number_of_quorum_votes AS int)				AS NumberOfQuorumVotes
						,CAST(pvt.number_of_current_votes AS int)				AS NumberOfCurrentVotes
						,(SELECT MIN(aoState.Timestamp) FROM dbo.fhsmAlwaysOnState AS aoState WHERE (aoState.GroupA = pvt.GroupA) AND (aoState.Query = 2) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MinTimestamp
						,(SELECT MAX(aoState.Timestamp) FROM dbo.fhsmAlwaysOnState AS aoState WHERE (aoState.GroupA = pvt.GroupA) AND (aoState.Query = 2) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MaxTimestamp
					FROM (
						SELECT aoState.GroupA, aoState.[Key], aoState.Value AS _Value_
						FROM dbo.fhsmAlwaysOnState AS aoState
						WHERE (aoState.Query = 2) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN (
							[member_state_desc], [member_type_desc],
							[number_of_current_votes], [number_of_quorum_votes]
						)
					) AS pvt;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[WSFC quorum members]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('WSFC quorum members');
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
		-- WSFC quorum state
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('WSFC quorum state') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('WSFC quorum state') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('WSFC quorum state') + '
				AS
					SELECT
						pvt.cluster_name										AS WSFCClusterName
						,dbo.fhsmFNConvertToDisplayTxt(pvt.quorum_type_desc)	AS QuorumType
						,dbo.fhsmFNConvertToDisplayTxt(pvt.quorum_state_desc)	AS QuorumState
						,(SELECT MIN(aoState.Timestamp) FROM dbo.fhsmAlwaysOnState AS aoState WHERE (aoState.Query = 1) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MinTimestamp
						,(SELECT MAX(aoState.Timestamp) FROM dbo.fhsmAlwaysOnState AS aoState WHERE (aoState.Query = 1) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')) AS MaxTimestamp
					FROM (
						SELECT aoState.[Key], aoState.Value AS _Value_
						FROM dbo.fhsmAlwaysOnState AS aoState
						WHERE (aoState.Query = 1) AND (aoState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN (
							[cluster_name], [quorum_state_desc], [quorum_type_desc])
					) AS pvt;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[WSFC quorum state]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('WSFC quorum state');
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;
	END;

	--
	-- Create stored procedures
	--
	BEGIN
		--
		-- Create stored procedure dbo.fhsmSPAlwaysOnState
		--
		IF (@productVersion1 < 11)
		BEGIN
			-- SQL Versions SQL2008R2 or lower
			RAISERROR('!!!', 0, 1) WITH NOWAIT;
			RAISERROR('!!! Can not install Always On state on SQL versions lower than SQL2012', 0, 1) WITH NOWAIT;
			RAISERROR('!!!', 0, 1) WITH NOWAIT;
		END
		ELSE BEGIN
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''dbo.fhsmSPAlwaysOnState'', ''P'') IS NULL
					BEGIN
						EXEC(''CREATE PROC dbo.fhsmSPAlwaysOnState AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER PROC dbo.fhsmSPAlwaysOnState (
						@name nvarchar(128),
						@parameter nvarchar(max)
					)
					AS
					BEGIN
						SET NOCOUNT ON;

						DECLARE @now datetime;
						DECLARE @nowUTC datetime;
						DECLARE @stmt nvarchar(max);
						DECLARE @thisTask nvarchar(128);
						DECLARE @version nvarchar(128);

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

							IF (OBJECT_ID(''tempdb..#alwaysOn'') IS NOT NULL) DROP TABLE #alwaysOn;

							CREATE TABLE #alwaysOn(
								Query int NOT NULL
								,GroupA nvarchar(128) NOT NULL
								,GroupB nvarchar(128) NOT NULL
								,GroupC nvarchar(128) NOT NULL
								,[Key] nvarchar(128) NOT NULL
								,Value nvarchar(max) NULL
								,PRIMARY KEY(Query, GroupA, GroupB, GroupC, [Key])
							);

							BEGIN
								--
								-- Test if read_write_routing_url exists on availability_replicas
								--
								BEGIN
									DECLARE @readWriteRoutingURLStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''availability_replicas'') AND (sc.name = ''read_write_routing_url'')
									)
									BEGIN
										SET @readWriteRoutingURLStmt = ''ar.read_write_routing_url COLLATE DATABASE_DEFAULT'';
									END
									ELSE BEGIN
										SET @readWriteRoutingURLStmt = ''NULL'';
									END;
								END;

								--
								-- Test if number_of_current_votes exists on dm_hadr_cluster_members
								--
								BEGIN
									DECLARE @numberOfCurrentVotesStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''dm_hadr_cluster_members'') AND (sc.name = ''number_of_current_votes'')
									)
									BEGIN
										SET @numberOfCurrentVotesStmt = ''dhcm.number_of_current_votes'';
									END
									ELSE BEGIN
										SET @numberOfCurrentVotesStmt = ''NULL'';
									END;
								END;

								--
								-- Test if is_primary_replica exists on dm_hadr_database_replica_states
								--
								BEGIN
									DECLARE @isPrimaryReplicaStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''dm_hadr_database_replica_states'') AND (sc.name = ''is_primary_replica'')
									)
									BEGIN
										SET @isPrimaryReplicaStmt = ''dhdrs.is_primary_replica'';
									END
									ELSE BEGIN
										SET @isPrimaryReplicaStmt = ''NULL'';
									END;
								END;

								SET @stmt = '''';
				';
				SET @stmt += '
								SET @stmt += ''
									INSERT INTO #alwaysOn(Query, GroupA, GroupB, GroupC, [Key], Value)
									SELECT
										1 AS Query, '''''''' AS GroupA, '''''''' AS GroupB, '''''''' AS GroupC, unpvt.K, unpvt.V
									FROM (
										SELECT
											CAST(dhc.cluster_name AS nvarchar(max)) AS cluster_name
											,CAST(dhc.quorum_type_desc AS nvarchar(max)) AS quorum_type_desc
											,CAST(dhc.quorum_state_desc AS nvarchar(max)) AS quorum_state_desc
										FROM sys.dm_hadr_cluster AS dhc WITH (NOLOCK)
									) AS p
									UNPIVOT (
										V FOR K IN (
											p.cluster_name
											,p.quorum_type_desc
											,p.quorum_state_desc
										)
									) AS unpvt
									OPTION (RECOMPILE);
								'';
				';
				SET @stmt += '
								SET @stmt += ''
									INSERT INTO #alwaysOn(Query, GroupA, GroupB, GroupC, [Key], Value)
									SELECT
										2 AS Query, unpvt.GroupA, '''''''' AS GroupB, '''''''' AS GroupC, unpvt.K, unpvt.V
									FROM (
										SELECT
											CAST(dhcm.member_name AS nvarchar(max)) AS GroupA
											,CAST(dhcm.member_type_desc COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS member_type_desc
											,CAST(dhcm.member_state_desc COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS member_state_desc
											,CAST(dhcm.number_of_quorum_votes AS nvarchar(max)) AS number_of_quorum_votes
											,CAST('' + @numberOfCurrentVotesStmt + '' AS nvarchar(max)) AS number_of_current_votes
										FROM sys.dm_hadr_cluster_members AS dhcm WITH (NOLOCK)
									) AS p
									UNPIVOT (
										V FOR K IN (
											p.member_type_desc
											,p.member_state_desc
											,p.number_of_quorum_votes
											,p.number_of_current_votes
										)
									) AS unpvt
									OPTION (RECOMPILE);
								'';
				';
				SET @stmt += '
								SET @stmt += ''
									INSERT INTO #alwaysOn(Query, GroupA, GroupB, GroupC, [Key], Value)
									SELECT
										3 AS Query, unpvt.GroupA, unpvt.GroupB, '''''''' AS GroupC, unpvt.K, unpvt.V
									FROM (
										SELECT
											CAST(ag.name AS nvarchar(max)) AS GroupA
											,CAST(dhags.primary_replica AS nvarchar(max)) AS GroupB
											,CAST(dhags.primary_recovery_health_desc AS nvarchar(max)) AS primary_recovery_health_desc
											,CAST(dhags.secondary_recovery_health_desc AS nvarchar(max)) AS secondary_recovery_health_desc
											,CAST(dhags.synchronization_health_desc AS nvarchar(max)) AS synchronization_health_desc
										FROM sys.dm_hadr_availability_group_states AS dhags WITH (NOLOCK)
										INNER JOIN sys.availability_groups AS ag WITH (NOLOCK) ON (ag.group_id = dhags.group_id)
									) AS p
									UNPIVOT (
										V FOR K IN (
											p.primary_recovery_health_desc
											,p.secondary_recovery_health_desc
											,p.synchronization_health_desc
										)
									) AS unpvt
									OPTION (RECOMPILE);
								'';
				';
				SET @stmt += '
								SET @stmt += ''
									INSERT INTO #alwaysOn(Query, GroupA, GroupB, GroupC, [Key], Value)
									SELECT
										4 AS Query, unpvt.GroupA, unpvt.GroupB, unpvt.GroupC, unpvt.K, unpvt.V
									FROM (
										SELECT
											CAST(ag.name AS nvarchar(max)) AS GroupA
											,CAST(arSrc.replica_server_name AS nvarchar(max)) AS GroupB
											,CAST(arRepl.replica_server_name AS nvarchar(max)) AS GroupC
											,CAST(arRepl.read_only_routing_url COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS read_only_routing_url
											,CAST(arorl.routing_priority AS nvarchar(max)) AS routing_priority
											,CAST(arRepl.secondary_role_allow_connections_desc COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS secondary_role_allow_connections_desc
										FROM sys.availability_read_only_routing_lists AS arorl WITH (NOLOCK)
										INNER JOIN sys.availability_replicas AS arSrc WITH (NOLOCK) ON (arSrc.replica_id = arorl.replica_id)
										INNER JOIN sys.availability_replicas AS arRepl WITH (NOLOCK) ON (arRepl.replica_id = arorl.read_only_replica_id)
										INNER JOIN sys.availability_groups AS ag WITH (NOLOCK) ON (ag.group_id = arSrc.group_id)
									) AS p
									UNPIVOT (
										V FOR K IN (
											p.read_only_routing_url
											,p.routing_priority
											,p.secondary_role_allow_connections_desc
										)
									) AS unpvt
									OPTION (RECOMPILE);
								'';
				';
				SET @stmt += '
								SET @stmt += ''
									INSERT INTO #alwaysOn(Query, GroupA, GroupB, GroupC, [Key], Value)
									SELECT
										5 AS Query, unpvt.GroupA, unpvt.GroupB, '''''''' AS GroupC, unpvt.K, unpvt.V
									FROM (
										SELECT
											CAST(ag.name AS nvarchar(max)) AS GroupA
											,CAST(ar.replica_server_name AS nvarchar(max)) AS GroupB
											,CAST(ar.endpoint_url COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS endpoint_url
											,CAST(ar.availability_mode_desc COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS availability_mode_desc
											,CAST(ar.failover_mode_desc AS nvarchar(max)) AS failover_mode_desc
											,CAST(ar.primary_role_allow_connections_desc COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS primary_role_allow_connections_desc
											,CAST(ar.secondary_role_allow_connections_desc COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS secondary_role_allow_connections_desc
											,CAST(ar.backup_priority AS nvarchar(max)) AS backup_priority
											,CAST(ar.read_only_routing_url COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS read_only_routing_url
											,CAST('' + @readWriteRoutingURLStmt + '' AS nvarchar(max)) AS read_write_routing_url
										FROM sys.availability_replicas AS ar WITH (NOLOCK)
										INNER JOIN sys.availability_groups AS ag WITH (NOLOCK) ON (ag.group_id = ar.group_id)
									) AS p
									UNPIVOT (
										V FOR K IN (
											p.endpoint_url
											,p.availability_mode_desc
											,p.failover_mode_desc
											,p.primary_role_allow_connections_desc
											,p.secondary_role_allow_connections_desc
											,p.backup_priority
											,p.read_only_routing_url
											,p.read_write_routing_url
										)
									) AS unpvt
									OPTION (RECOMPILE);
								'';
				';
				SET @stmt += '
								SET @stmt += ''
									INSERT INTO #alwaysOn(Query, GroupA, GroupB, GroupC, [Key], Value)
									SELECT
										6 AS Query, unpvt.GroupA, unpvt.GroupB, unpvt.GroupC, unpvt.K, unpvt.V
									FROM (
										SELECT
											CAST(ag.name AS nvarchar(max)) AS GroupA
											,CAST(ar.replica_server_name AS nvarchar(max)) AS GroupB
											,CAST(d.name AS nvarchar(max)) AS GroupC
											,CAST(dhdrs.is_local AS nvarchar(max)) AS is_local
											,CAST('' + @isPrimaryReplicaStmt + '' AS nvarchar(max)) AS is_primary_replica
											,CAST(dhdrs.synchronization_state_desc COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS synchronization_state_desc
											,CAST(dhdrs.is_commit_participant AS nvarchar(max)) AS is_commit_participant
											,CAST(dhdrs.synchronization_health_desc COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS synchronization_health_desc
											,CAST(dhdrs.database_state_desc COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS database_state_desc
											,CAST(dhdrs.is_suspended AS nvarchar(max)) AS is_suspended
											,CAST(dhdrs.suspend_reason_desc COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS suspend_reason_desc
										FROM sys.dm_hadr_database_replica_states AS dhdrs WITH (NOLOCK)
										INNER JOIN sys.availability_replicas AS ar WITH (NOLOCK) ON (ar.group_id = dhdrs.group_id) AND (ar.replica_id = dhdrs.replica_id)
										INNER JOIN sys.availability_groups AS ag WITH (NOLOCK) ON (ag.group_id = ar.group_id)
										INNER JOIN sys.databases AS d WITH (NOLOCK) ON (d.database_id = dhdrs.database_id)
									) AS p
									UNPIVOT (
										V FOR K IN (
											p.is_local
											,p.is_primary_replica
											,p.synchronization_state_desc
											,p.is_commit_participant
											,p.synchronization_health_desc
											,p.database_state_desc
											,p.is_suspended
											,p.suspend_reason_desc
										)
									) AS unpvt
									OPTION (RECOMPILE);
								'';
				';
				SET @stmt += '
								EXEC(@stmt);
							END;
				';
				SET @stmt += '
							--
							-- Remove records where Value is NULL
							--
							BEGIN
								DELETE tgt
								FROM #alwaysOn AS tgt
								WHERE (tgt.Value IS NULL);
							END;

							--
							-- Update current record ValidTo as it is no longer valid
							--
							BEGIN
								UPDATE tgt
								SET tgt.ValidTo = @nowUTC
								FROM dbo.fhsmAlwaysOnState AS tgt
								LEFT OUTER JOIN #alwaysOn AS src ON (src.Query = tgt.Query)
									AND (src.GroupA COLLATE DATABASE_DEFAULT = tgt.GroupA)
									AND (src.GroupB COLLATE DATABASE_DEFAULT = tgt.GroupB)
									AND (src.GroupC COLLATE DATABASE_DEFAULT = tgt.GroupC)
									AND (src.[Key] COLLATE DATABASE_DEFAULT = tgt.[Key])
								WHERE
									(
										(src.Query IS NULL)
										OR ((src.Value COLLATE DATABASE_DEFAULT <> tgt.Value) OR (src.Value IS NULL AND tgt.Value IS NOT NULL) OR (src.Value IS NOT NULL AND tgt.Value IS NULL))
									) AND (tgt.ValidTo = ''9999-dec-31 23:59:59'');
							END;

							--
							-- Insert new records
							--
							BEGIN
								INSERT INTO dbo.fhsmAlwaysOnState(Query, GroupA, GroupB, GroupC, [Key], Value, ValidFrom, ValidTo, TimestampUTC, Timestamp)
								SELECT src.Query, src.GroupA, src.GroupB, src.GroupC, src.[Key], src.Value, @nowUTC AS ValidFrom, ''9999-dec-31 23:59:59'' AS ValidTo, @nowUTC, @now
								FROM #alwaysOn AS src
								WHERE NOT EXISTS (
									SELECT *
									FROM dbo.fhsmAlwaysOnState AS tgt
									WHERE
										(tgt.Query = src.Query)
										AND (tgt.GroupA COLLATE DATABASE_DEFAULT = src.GroupA)
										AND (tgt.GroupB COLLATE DATABASE_DEFAULT = src.GroupB)
										AND (tgt.GroupC COLLATE DATABASE_DEFAULT = src.GroupC)
										AND (tgt.[Key] COLLATE DATABASE_DEFAULT = src.[Key])
										AND ((tgt.Value COLLATE DATABASE_DEFAULT = src.Value) OR (tgt.Value IS NULL AND src.Value IS NULL)) AND (tgt.ValidTo = ''9999-dec-31 23:59:59'')
								);
							END;
						END;

						RETURN 0;
					END;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPAlwaysOnState
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPAlwaysOnState';
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
		-- Create stored procedure dbo.fhsmSPDatabaseState
		--
		BEGIN
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''dbo.fhsmSPDatabaseState'', ''P'') IS NULL
					BEGIN
						EXEC(''CREATE PROC dbo.fhsmSPDatabaseState AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER PROC dbo.fhsmSPDatabaseState (
						@name nvarchar(128)
						,@version nvarchar(128) OUTPUT
					)
					AS
					BEGIN
						SET NOCOUNT ON;

						DECLARE @database nvarchar(128);
						DECLARE @errorMsg nvarchar(max);
						DECLARE @message nvarchar(max);
						DECLARE @now datetime;
						DECLARE @nowUTC datetime;
						DECLARE @parameter nvarchar(max);
						DECLARE @replicaId uniqueidentifier;
						DECLARE @stmt nvarchar(max);
						DECLARE @thisTask nvarchar(128);

						SET @thisTask = OBJECT_NAME(@@PROCID);
						SET @version = ''' + @version + ''';

						--******************************************************************************
						--*   Copyright (C) 2020 Glenn Berry
						--*   All rights reserved. 
						--*
						--*
						--*   You may alter this code for your own *non-commercial* purposes. You may
						--*   republish altered code as long as you include this copyright and give due credit. 
						--*
						--*
						--*   THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
						--*   ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
						--*   TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
						--*   PARTICULAR PURPOSE. 
						--*
						--******************************************************************************

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
			';
			IF (@productVersion1 >= 11)
			BEGIN
				SET @stmt += '
							--
							-- Calling dbo.fhsmSPAlwaysOnState
							--
							BEGIN
								SET @message = ''Before calling dbo.fhsmSPAlwaysOnState'';
								EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;

								EXEC dbo.fhsmSPAlwaysOnState @name = @name, @parameter = @parameter;

								SET @message = ''After calling dbo.fhsmSPAlwaysOnState'';
								EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
							END;
				';
			END;
			SET @stmt += '
							SELECT
								@now = SYSDATETIME()
								,@nowUTC = SYSUTCDATETIME();

							IF (OBJECT_ID(''tempdb..#inventory'') IS NOT NULL) DROP TABLE #inventory;

							CREATE TABLE #inventory(
								Query int NOT NULL
								,DatabaseName nvarchar(128) NOT NULL
								,[Key] nvarchar(128) NOT NULL
								,Value nvarchar(max) NULL
								,PRIMARY KEY(Query, DatabaseName, [Key])
							);

							DECLARE @xpReadErrorLog TABLE(LogDate datetime, ProcessorInfo nvarchar(128), Text nvarchar(max));
							DECLARE @xpReadReg TABLE(Value nvarchar(128), Data nvarchar(max));

							--
							-- Recovery model, log reuse wait description, log file size, log usage size  (Query 31) (Database Properties)
							--
							BEGIN
								--
								-- Test if is_auto_create_stats_incremental_on exists on databases
								--
								BEGIN
									DECLARE @isAutoCreateStatsIncrementalOnStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''is_auto_create_stats_incremental_on'')
									)
									BEGIN
										SET @isAutoCreateStatsIncrementalOnStmt = ''d.is_auto_create_stats_incremental_on'';
									END
									ELSE BEGIN
										SET @isAutoCreateStatsIncrementalOnStmt = ''NULL'';
									END;
								END;

								--
								-- Test if is_query_store_on exists on databases
								--
								BEGIN
									DECLARE @isQueryStoreOnStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''is_query_store_on'')
									)
									BEGIN
										SET @isQueryStoreOnStmt = ''d.is_query_store_on'';
									END
									ELSE BEGIN
										SET @isQueryStoreOnStmt = ''NULL'';
									END;
								END;
			';
			SET @stmt += '
								--
								-- Test if delayed_durability exists on databases
								--
								BEGIN
									DECLARE @delayedDurabilityStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''delayed_durability'')
									)
									BEGIN
										SET @delayedDurabilityStmt = ''d.delayed_durability'';
									END
									ELSE BEGIN
										SET @delayedDurabilityStmt = ''NULL'';
									END;
								END;

								--
								-- Test if is_memory_optimized_elevate_to_snapshot_on exists on databases
								--
								BEGIN
									DECLARE @isMemoryOptimizedElevateToSnapshotOnStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''is_memory_optimized_elevate_to_snapshot_on'')
									)
									BEGIN
										SET @isMemoryOptimizedElevateToSnapshotOnStmt = ''d.is_memory_optimized_elevate_to_snapshot_on'';
									END
									ELSE BEGIN
										SET @isMemoryOptimizedElevateToSnapshotOnStmt = ''NULL'';
									END;
								END;

								--
								-- Test if is_federation_member exists on databases
								--
								BEGIN
									DECLARE @isFederationMemberStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''is_federation_member'')
									)
									BEGIN
										SET @isFederationMemberStmt = ''d.is_federation_member'';
									END
									ELSE BEGIN
										SET @isFederationMemberStmt = ''NULL'';
									END;
								END;
			';
			SET @stmt += '
								--
								-- Test if is_remote_data_archive_enabled exists on databases
								--
								BEGIN
									DECLARE @isRemoteDataArchiveEnabledStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''is_remote_data_archive_enabled'')
									)
									BEGIN
										SET @isRemoteDataArchiveEnabledStmt = ''d.is_remote_data_archive_enabled'';
									END
									ELSE BEGIN
										SET @isRemoteDataArchiveEnabledStmt = ''NULL'';
									END;
								END;

								--
								-- Test if is_mixed_page_allocation_on exists on databases
								--
								BEGIN
									DECLARE @isMixedPageAllocationOnStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''is_mixed_page_allocation_on'')
									)
									BEGIN
										SET @isMixedPageAllocationOnStmt = ''d.is_mixed_page_allocation_on'';
									END
									ELSE BEGIN
										SET @isMixedPageAllocationOnStmt = ''NULL'';
									END;
								END;
			';
			SET @stmt += '
								--
								-- Test if is_temporal_history_retention_enabled exists on databases
								--
								BEGIN
									DECLARE @isTemporalHistoryRetentionEnabledStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''is_temporal_history_retention_enabled'')
									)
									BEGIN
										SET @isTemporalHistoryRetentionEnabledStmt = ''d.is_temporal_history_retention_enabled'';
									END
									ELSE BEGIN
										SET @isTemporalHistoryRetentionEnabledStmt = ''NULL'';
									END;
								END;

								--
								-- Test if catalog_collation_type exists on databases
								--
								BEGIN
									DECLARE @catalogCollationTypeStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''catalog_collation_type'')
									)
									BEGIN
										SET @catalogCollationTypeStmt = ''d.catalog_collation_type'';
									END
									ELSE BEGIN
										SET @catalogCollationTypeStmt = ''NULL'';
									END;
								END;

								--
								-- Test if physical_database_name exists on databases
								--
								BEGIN
									DECLARE @physicalDatabaseNameStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''physical_database_name'')
									)
									BEGIN
										SET @physicalDatabaseNameStmt = ''d.physical_database_name COLLATE DATABASE_DEFAULT'';
									END
									ELSE BEGIN
										SET @physicalDatabaseNameStmt = ''NULL'';
									END;
								END;
			';
			SET @stmt += '
								--
								-- Test if is_result_set_caching_on exists on databases
								--
								BEGIN
									DECLARE @isResultSetCachingOnStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''is_result_set_caching_on'')
									)
									BEGIN
										SET @isResultSetCachingOnStmt = ''d.is_result_set_caching_on'';
									END
									ELSE BEGIN
										SET @isResultSetCachingOnStmt = ''NULL'';
									END;
								END;

								--
								-- Test if is_accelerated_database_recovery_on exists on databases
								--
								BEGIN
									DECLARE @isAcceleratedDatabaseRecoveryOnStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''is_accelerated_database_recovery_on'')
									)
									BEGIN
										SET @isAcceleratedDatabaseRecoveryOnStmt = ''d.is_accelerated_database_recovery_on'';
									END
									ELSE BEGIN
										SET @isAcceleratedDatabaseRecoveryOnStmt = ''NULL'';
									END;
								END;

								--
								-- Test if is_tempdb_spill_to_remote_store exists on databases
								--
								BEGIN
									DECLARE @isTempdbSpillToRemoteStoreStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''is_tempdb_spill_to_remote_store'')
									)
									BEGIN
										SET @isTempdbSpillToRemoteStoreStmt = ''d.is_tempdb_spill_to_remote_store'';
									END
									ELSE BEGIN
										SET @isTempdbSpillToRemoteStoreStmt = ''NULL'';
									END;
								END;
			';
			SET @stmt += '
								--
								-- Test if is_stale_page_detection_on exists on databases
								--
								BEGIN
									DECLARE @isStalePageDetectionOnStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''is_stale_page_detection_on'')
									)
									BEGIN
										SET @isStalePageDetectionOnStmt = ''d.is_stale_page_detection_on'';
									END
									ELSE BEGIN
										SET @isStalePageDetectionOnStmt = ''NULL'';
									END;
								END;

								--
								-- Test if is_memory_optimized_enabled exists on databases
								--
								BEGIN
									DECLARE @isMemoryOptimizedEnabledStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''is_memory_optimized_enabled'')
									)
									BEGIN
										SET @isMemoryOptimizedEnabledStmt = ''d.is_memory_optimized_enabled'';
									END
									ELSE BEGIN
										SET @isMemoryOptimizedEnabledStmt = ''NULL'';
									END;
								END;
			';
			SET @stmt += '
								--
								-- Test if containment exists on databases
								--
								BEGIN
									DECLARE @containmentStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''containment'')
									)
									BEGIN
										SET @containmentStmt = ''d.containment'';
									END
									ELSE BEGIN
										SET @containmentStmt = ''NULL'';
									END;
								END;
			';
			SET @stmt += '
								--
								-- Test if replica_id exists on databases
								--
								BEGIN
									DECLARE @replicaIdStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''replica_id'')
									)
									BEGIN
										SET @replicaIdStmt = ''d.replica_id'';
									END
									ELSE BEGIN
										SET @replicaIdStmt = ''NULL'';
									END;
								END;

								--
								-- Test if target_recovery_time_in_seconds exists on databases
								--
								BEGIN
									DECLARE @targetRecoveryTimeInSecondsStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''databases'') AND (sc.name = ''target_recovery_time_in_seconds'')
									)
									BEGIN
										SET @targetRecoveryTimeInSecondsStmt = ''d.target_recovery_time_in_seconds'';
									END
									ELSE BEGIN
										SET @targetRecoveryTimeInSecondsStmt = ''NULL'';
									END;
								END;
			';
			SET @stmt += '
								--
								-- Test if encryption_scan_state exists on dm_database_encryption_keys
								--
								BEGIN
									DECLARE @encryptionScanStateStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''dm_database_encryption_keys'') AND (sc.name = ''encryption_scan_state'')
									)
									BEGIN
										SET @encryptionScanStateStmt = ''ddek.encryption_scan_state'';
									END
									ELSE BEGIN
										SET @encryptionScanStateStmt = ''NULL'';
									END;
								END;

								--
								-- Test if encryption_scan_modify_date exists on dm_database_encryption_keys
								--
								BEGIN
									DECLARE @encryptionScanModifyDateStmt nvarchar(max);

									IF EXISTS(
										SELECT *
										FROM master.sys.system_columns AS sc
										INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
										WHERE (so.name = ''dm_database_encryption_keys'') AND (sc.name = ''encryption_scan_modify_date'')
									)
									BEGIN
										SET @encryptionScanModifyDateStmt = ''ddek.encryption_scan_modify_date'';
									END
									ELSE BEGIN
										SET @encryptionScanModifyDateStmt = ''NULL'';
									END;
								END;
			';
			SET @stmt += '
								SET @stmt = ''
									INSERT INTO #inventory(Query, DatabaseName, [Key], Value)
									SELECT 31 AS Query, unpvt.database_name AS DatabaseName, unpvt.K, unpvt.V
									FROM (
										SELECT
											CAST(d.name                                        AS nvarchar(max)) AS database_name 
											,CAST(SUSER_SNAME(d.owner_sid)                     AS nvarchar(max)) AS database_owner
											,CONVERT(nvarchar(max), d.create_date, 126)                          AS database_create_date
											,CAST(d.compatibility_level                        AS nvarchar(max)) AS compatibility_level
											,CAST(d.collation_name COLLATE DATABASE_DEFAULT    AS nvarchar(max)) AS collation_name
											,CAST(d.user_access                                AS nvarchar(max)) AS user_access
											,CAST(d.is_read_only                               AS nvarchar(max)) AS is_read_only
											,CAST(d.is_auto_close_on                           AS nvarchar(max)) AS is_auto_close_on
											,CAST(d.is_auto_shrink_on                          AS nvarchar(max)) AS is_auto_shrink_on
											,CAST(d.state                                      AS nvarchar(max)) AS state
											,CAST(d.is_in_standby                              AS nvarchar(max)) AS is_in_standby
											,CAST(d.is_cleanly_shutdown                        AS nvarchar(max)) AS is_cleanly_shutdown
											,CAST(d.is_supplemental_logging_enabled            AS nvarchar(max)) AS is_supplemental_logging_enabled
											,CAST(d.snapshot_isolation_state                   AS nvarchar(max)) AS snapshot_isolation_state
											,CAST(d.is_read_committed_snapshot_on              AS nvarchar(max)) AS is_read_committed_snapshot_on
											,CAST(d.recovery_model                             AS nvarchar(max)) AS recovery_model
								'';
			';
			SET @stmt += '
								SET @stmt += ''
											,CAST(d.page_verify_option                         AS nvarchar(max)) AS page_verify_option
											,CAST(d.is_auto_create_stats_on                    AS nvarchar(max)) AS is_auto_create_stats_on
											,CAST('' + @isAutoCreateStatsIncrementalOnStmt + ''        AS nvarchar(max)) AS is_auto_create_stats_incremental_on
											,CAST(d.is_auto_update_stats_on                    AS nvarchar(max)) AS is_auto_update_stats_on
											,CAST(d.is_auto_update_stats_async_on              AS nvarchar(max)) AS is_auto_update_stats_async_on
											,CAST(d.is_ansi_null_default_on                    AS nvarchar(max)) AS is_ansi_null_default_on
											,CAST(d.is_ansi_nulls_on                           AS nvarchar(max)) AS is_ansi_nulls_on
											,CAST(d.is_ansi_padding_on                         AS nvarchar(max)) AS is_ansi_padding_on
											,CAST(d.is_ansi_warnings_on                        AS nvarchar(max)) AS is_ansi_warnings_on
											,CAST(d.is_arithabort_on                           AS nvarchar(max)) AS is_arithabort_on
											,CAST(d.is_concat_null_yields_null_on              AS nvarchar(max)) AS is_concat_null_yields_null_on
											,CAST(d.is_numeric_roundabort_on                   AS nvarchar(max)) AS is_numeric_roundabort_on
											,CAST(d.is_quoted_identifier_on                    AS nvarchar(max)) AS is_quoted_identifier_on
											,CAST(d.is_recursive_triggers_on                   AS nvarchar(max)) AS is_recursive_triggers_on
											,CAST(d.is_cursor_close_on_commit_on               AS nvarchar(max)) AS is_cursor_close_on_commit_on
											,CAST(d.is_local_cursor_default                    AS nvarchar(max)) AS is_local_cursor_default
								'';
			';
			SET @stmt += '
								SET @stmt += ''
											,CAST(d.is_fulltext_enabled                        AS nvarchar(max)) AS is_fulltext_enabled
											,CAST(d.is_trustworthy_on                          AS nvarchar(max)) AS is_trustworthy_on
											,CAST(d.is_db_chaining_on                          AS nvarchar(max)) AS is_db_chaining_on
											,CAST(d.is_parameterization_forced                 AS nvarchar(max)) AS is_parameterization_forced
											,CAST(d.is_master_key_encrypted_by_server          AS nvarchar(max)) AS is_master_key_encrypted_by_server
											,CAST('' + @isQueryStoreOnStmt + ''                          AS nvarchar(max)) AS is_query_store_on
											,CAST(d.is_published                               AS nvarchar(max)) AS is_published
											,CAST(d.is_subscribed                              AS nvarchar(max)) AS is_subscribed
											,CAST(d.is_merge_published                         AS nvarchar(max)) AS is_merge_published
											,CAST(d.is_distributor                             AS nvarchar(max)) AS is_distributor
											,CAST(d.is_sync_with_backup                        AS nvarchar(max)) AS is_sync_with_backup
											,CAST(d.is_broker_enabled                          AS nvarchar(max)) AS is_broker_enabled
											,CAST(d.is_date_correlation_on                     AS nvarchar(max)) AS is_date_correlation_on
											,CAST(d.is_cdc_enabled                             AS nvarchar(max)) AS is_cdc_enabled
											,CAST(d.is_encrypted                               AS nvarchar(max)) AS is_encrypted
											,CAST(d.is_honor_broker_priority_on                AS nvarchar(max)) AS is_honor_broker_priority_on
											,CAST('' + @replicaIdStmt + ''                               AS nvarchar(max)) AS replica_id
			';
			IF (@productVersion1 >= 11)
			BEGIN
				SET @stmt += '
											,CAST((
												SELECT ag.name COLLATE DATABASE_DEFAULT
												FROM master.sys.availability_groups AS ag
												INNER JOIN master.sys.availability_replicas AS ar ON ag.group_id = ar.group_id
												WHERE (ar.replica_server_name = @@SERVERNAME) AND (ar.replica_id = d.replica_id)
											) AS nvarchar(max)) AS AlwaysOnGroupName
											,COALESCE(CAST((
												SELECT
												CASE
													WHEN (dhags.primary_replica = ar.replica_server_name) THEN 1
													ELSE                                                  2
												END AS IsPrimaryServer
												FROM master.sys.availability_groups AS ag
												INNER JOIN master.sys.availability_replicas AS ar ON ag.group_id = ar.group_id
												INNER JOIN master.sys.dm_hadr_availability_group_states AS dhags ON ag.group_id = dhags.group_id
												WHERE (ar.replica_server_name = @@SERVERNAME) AND (ar.replica_id = d.replica_id)
											) AS nvarchar(max)), ''''3'''') AS IsOnAlwaysOnPrimary
				';
			END
			ELSE BEGIN
				SET @stmt += '
											,CAST(NULL AS nvarchar(max))		AS AlwaysOnGroupName
											,CAST(''''3'''' AS nvarchar(max))	AS IsOnAlwaysOnPrimary
				';
			END
				SET @stmt += '
											,CAST('' + @containmentStmt + ''                                AS nvarchar(max)) AS containment
											,CAST('' + @targetRecoveryTimeInSecondsStmt + ''            AS nvarchar(max)) AS target_recovery_time_in_seconds
								'';
								SET @stmt += ''
											,CAST('' + @delayedDurabilityStmt + ''                         AS nvarchar(max)) AS delayed_durability
											,CAST('' + @isMemoryOptimizedElevateToSnapshotOnStmt + '' AS nvarchar(max)) AS is_memory_optimized_elevate_to_snapshot_on
											,CAST('' + @isFederationMemberStmt + ''                       AS nvarchar(max)) AS is_federation_member
											,CAST('' + @isRemoteDataArchiveEnabledStmt + ''             AS nvarchar(max)) AS is_remote_data_archive_enabled
											,CAST('' + @isMixedPageAllocationOnStmt + ''                AS nvarchar(max)) AS is_mixed_page_allocation_on
											,CAST('' + @isTemporalHistoryRetentionEnabledStmt + ''      AS nvarchar(max)) AS is_temporal_history_retention_enabled
											,CAST('' + @catalogCollationTypeStmt + ''                     AS nvarchar(max)) AS catalog_collation_type
											,CAST('' + @physicalDatabaseNameStmt + ''                     AS nvarchar(max)) AS physical_database_name
											,CAST('' + @isResultSetCachingOnStmt + ''                   AS nvarchar(max)) AS is_result_set_caching_on
											,CAST('' + @isAcceleratedDatabaseRecoveryOnStmt + ''        AS nvarchar(max)) AS is_accelerated_database_recovery_on
											,CAST('' + @isTempdbSpillToRemoteStoreStmt + ''            AS nvarchar(max)) AS is_tempdb_spill_to_remote_store
											,CAST('' + @isStalePageDetectionOnStmt + ''                 AS nvarchar(max)) AS is_stale_page_detection_on
											,CAST('' + @isMemoryOptimizedEnabledStmt + ''                AS nvarchar(max)) AS is_memory_optimized_enabled
											,CAST(ddek.encryption_state                        AS nvarchar(max)) AS encryption_state
											,CONVERT(nvarchar(max), ddek.create_date, 126)                       AS key_create_date
											,CONVERT(nvarchar(max), ddek.regenerate_date, 126)                   AS key_regenerate_date
											,CONVERT(nvarchar(max), ddek.set_date, 126)                          AS key_set_date
											,CONVERT(nvarchar(max), ddek.opened_date, 126)                       AS key_opened_date
											,CAST(ddek.key_algorithm COLLATE DATABASE_DEFAULT  AS nvarchar(max)) AS key_algorithm
											,CAST(ddek.key_length                              AS nvarchar(max)) AS key_length
											,CAST(ddek.percent_complete                        AS nvarchar(max)) AS percent_complete
											,CAST('' + @encryptionScanStateStmt + ''                   AS nvarchar(max)) AS encryption_scan_state
											,CAST('' + @encryptionScanModifyDateStmt + ''             AS nvarchar(max)) AS encryption_scan_modify_date
										FROM sys.databases AS d WITH (NOLOCK)
										LEFT OUTER JOIN sys.dm_database_encryption_keys AS ddek WITH (NOLOCK) ON (d.database_id = ddek.database_id)
									) AS p
								'';
			';
			SET @stmt += '
								SET @stmt += ''
									UNPIVOT(
										V FOR K IN (
											p.database_owner
											,p.database_create_date
											,p.compatibility_level
											,p.collation_name
											,p.user_access
											,p.is_read_only
											,p.is_auto_close_on
											,p.is_auto_shrink_on
											,p.state
											,p.is_in_standby
											,p.is_cleanly_shutdown
											,p.is_supplemental_logging_enabled
											,p.snapshot_isolation_state
											,p.is_read_committed_snapshot_on
											,p.recovery_model
								'';
								SET @stmt += ''
											,p.page_verify_option
											,p.is_auto_create_stats_on
											,p.is_auto_create_stats_incremental_on
											,p.is_auto_update_stats_on
											,p.is_auto_update_stats_async_on
											,p.is_ansi_null_default_on
											,p.is_ansi_nulls_on
											,p.is_ansi_padding_on
											,p.is_ansi_warnings_on
											,p.is_arithabort_on
											,p.is_concat_null_yields_null_on
											,p.is_numeric_roundabort_on
											,p.is_quoted_identifier_on
											,p.is_recursive_triggers_on
											,p.is_cursor_close_on_commit_on
											,p.is_local_cursor_default
								'';
			';
			SET @stmt += '
								SET @stmt += ''
											,p.is_fulltext_enabled
											,p.is_trustworthy_on
											,p.is_db_chaining_on
											,p.is_parameterization_forced
											,p.is_master_key_encrypted_by_server
											,p.is_query_store_on
											,p.is_published
											,p.is_subscribed
											,p.is_merge_published
											,p.is_distributor
											,p.is_sync_with_backup
											,p.is_broker_enabled
											,p.is_date_correlation_on
											,p.is_cdc_enabled
											,p.is_encrypted
											,p.is_honor_broker_priority_on
											,p.replica_id
											,p.AlwaysOnGroupName
											,p.IsOnAlwaysOnPrimary
											,p.containment
											,p.target_recovery_time_in_seconds
								'';
								SET @stmt += ''
											,p.delayed_durability
											,p.is_memory_optimized_elevate_to_snapshot_on
											,p.is_federation_member
											,p.is_remote_data_archive_enabled
											,p.is_mixed_page_allocation_on
											,p.is_temporal_history_retention_enabled
											,p.catalog_collation_type
											,p.physical_database_name
											,p.is_result_set_caching_on
											,p.is_accelerated_database_recovery_on
											,p.is_tempdb_spill_to_remote_store
											,p.is_stale_page_detection_on
											,p.is_memory_optimized_enabled
											,p.encryption_state
											,p.key_create_date
											,p.key_regenerate_date
											,p.key_set_date
											,p.key_opened_date
											,p.key_algorithm
											,p.key_length
											,p.percent_complete
											,p.encryption_scan_state
											,p.encryption_scan_modify_date
										)
									) AS unpvt OPTION (RECOMPILE);
								'';
								EXEC(@stmt);
							END;
				';
				IF (@productVersion1 < 13)
				BEGIN
					-- SQL Versions SQL2014 or lower
					RAISERROR('!!!', 0, 1) WITH NOWAIT;
					RAISERROR('!!! Can not install Database scoped configurations on SQL versions lower than SQL2016', 0, 1) WITH NOWAIT;
					RAISERROR('!!!', 0, 1) WITH NOWAIT;
				END
				ELSE BEGIN
					SET @stmt += '
							--
							-- Get Database scoped configurations Query:60/1060/2060
							--
							BEGIN
								DECLARE dCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
								SELECT d.name AS DatabaseName, d.replica_id
								FROM sys.databases AS d
								ORDER BY d.name;

								OPEN dCur;

								WHILE (1 = 1)
								BEGIN
									FETCH NEXT FROM dCur
									INTO @database, @replicaId;

									IF (@@FETCH_STATUS <> 0)
									BEGIN
										BREAK;
									END;

									--
									-- If is a member of a replica, we will only execute when running on the primary
									--
									IF (@replicaId IS NULL)
										OR (
											(
												SELECT
												CASE
													WHEN (dhags.primary_replica = ar.replica_server_name) THEN 1
													ELSE 0
												END AS IsPrimaryServer
												FROM master.sys.availability_groups AS ag
												INNER JOIN master.sys.availability_replicas AS ar ON ag.group_id = ar.group_id
												INNER JOIN master.sys.dm_hadr_availability_group_states AS dhags ON ag.group_id = dhags.group_id
												WHERE (ar.replica_server_name = @@SERVERNAME) AND (ar.replica_id = @replicaId)
											) = 1
										)
									BEGIN
										SET @stmt = ''
											USE '' + QUOTENAME(@database) + '';
											INSERT INTO #inventory(Query, DatabaseName, [Key], Value)
											SELECT
												a.Query
												,DB_NAME() AS DatabaseName
												,CAST(a.name AS nvarchar(max)) AS [Key]
												,CAST(a.value AS nvarchar(max)) AS Value
											FROM (
												SELECT
													60 AS Query	-- Value for primary
													,dsc.name
													,dsc.value
												FROM sys.database_scoped_configurations AS dsc WITH (NOLOCK)

												UNION ALL

												SELECT
													1060 AS Query	-- Value for secondary
													,dsc.name
													,dsc.value_for_secondary AS value
												FROM sys.database_scoped_configurations AS dsc WITH (NOLOCK)

												UNION ALL
					';
					IF (@productVersion1 >= 14)
					BEGIN
						-- SQL Versions SQL2017 or higher
						SET @stmt += '
												SELECT
													2060 AS Query	-- Is default value
													,dsc.name
													,dsc.is_value_default AS value
												FROM sys.database_scoped_configurations AS dsc WITH (NOLOCK)
						';
					END
					ELSE BEGIN
						SET @stmt += '
												SELECT
													2060 AS Query	-- Is default value
													,dscDefaultValues.name
													,CASE WHEN (dscDefaultValues.value <> dsc.value) OR (dsc.value_for_secondary IS NOT NULL) THEN 0 ELSE 1 END AS value
												FROM (
													VALUES
														(''''LEGACY_CARDINALITY_ESTIMATION'''',	0),
														(''''MAXDOP'''',						0),
														(''''PARAMETER_SNIFFING'''',			1),
														(''''QUERY_OPTIMIZER_HOTFIXES'''',		0)
												) AS dscDefaultValues(name, value)
												INNER JOIN sys.database_scoped_configurations AS dsc WITH (NOLOCK) ON (dsc.name = dscDefaultValues.name)
						';
					END;
					SET @stmt += '
											) AS a
											WHERE (a.value IS NOT NULL)
											OPTION (RECOMPILE);
										'';

										BEGIN TRY
											EXEC(@stmt);
										END TRY
										BEGIN CATCH
											SET @errorMsg = ERROR_MESSAGE();

											SET @message = ''Database '''''' + @database + '''''' failed due to - '' + @errorMsg;
											EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Warning'', @message = @message;
										END CATCH;
									END
									ELSE BEGIN
										SET @message = ''Database '''''' + @database + '''''' is member of a replica but this server is not the primary node'';
										EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
									END;
								END;

								CLOSE dCur;
								DEALLOCATE dCur;
							END;
					';
				END;
				SET @stmt += '
							--
							-- Remove records where Value is NULL
							--
							BEGIN
								DELETE tgt
								FROM #inventory AS tgt
								WHERE (tgt.Value IS NULL);
							END;

							--
							-- Update current record ValidTo as it is no longer valid
							--
							BEGIN
								UPDATE tgt
								SET tgt.ValidTo = @nowUTC
								FROM dbo.fhsmDatabaseState AS tgt
								LEFT OUTER JOIN #inventory AS src ON (src.Query = tgt.Query) AND (src.DatabaseName COLLATE DATABASE_DEFAULT = tgt.DatabaseName) AND (src.[Key] COLLATE DATABASE_DEFAULT = tgt.[Key])
								WHERE
									(
										(src.Query IS NULL)
										OR ((src.Value COLLATE DATABASE_DEFAULT <> tgt.Value) OR (src.Value IS NULL AND tgt.Value IS NOT NULL) OR (src.Value IS NOT NULL AND tgt.Value IS NULL))
									) AND (tgt.ValidTo = ''9999-dec-31 23:59:59'');
							END;

							--
							-- Insert new records
							--
							BEGIN
								INSERT INTO dbo.fhsmDatabaseState(Query, DatabaseName, [Key], Value, ValidFrom, ValidTo, TimestampUTC, Timestamp)
								SELECT src.Query, src.DatabaseName, src.[Key], src.Value, @nowUTC AS ValidFrom, ''9999-dec-31 23:59:59'' AS ValidTo, @nowUTC, @now
								FROM #inventory AS src
								WHERE NOT EXISTS (
									SELECT *
									FROM dbo.fhsmDatabaseState AS tgt
									WHERE
										(tgt.Query = src.Query)
										AND (tgt.DatabaseName COLLATE DATABASE_DEFAULT = src.DatabaseName)
										AND (tgt.[Key] COLLATE DATABASE_DEFAULT = src.[Key])
										AND ((tgt.Value COLLATE DATABASE_DEFAULT = src.Value) OR (tgt.Value IS NULL AND src.Value IS NULL)) AND (tgt.ValidTo = ''9999-dec-31 23:59:59'')
								);
							END;
				';
				SET @stmt += '
						END;

						RETURN 0;
					END;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPDatabaseState
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPDatabaseState';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'Procedure', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
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
				,'dbo.fhsmAlwaysOnState'
				,1
				,'TimestampUTC'
				,1
				,1825	-- 5 years
				,NULL

			UNION ALL

			SELECT
				1
				,'dbo.fhsmDatabaseState'
				,1
				,'TimestampUTC'
				,1
				,1825	-- 5 years
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
				@enableDatabaseState							AS Enabled
				,0												AS DeploymentStatus
				,'Database state'								AS Name
				,PARSENAME('dbo.fhsmSPDatabaseState', 1)		AS Task
				,1 * 60 * 60									AS ExecutionDelaySec
				,CAST('1900-1-1T00:00:00.0000' AS datetime2(0))	AS FromTime
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))	AS ToTime
				,1, 1, 1, 1, 1, 1, 1							-- Monday..Sunday
				,NULL											AS Parameter
		)
		MERGE dbo.fhsmSchedules AS tgt
		USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
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
			,SrcColumn1, SrcColumn2
			,OutputColumn1, OutputColumn2
		) AS (
			SELECT
				'Always On group' AS DimensionName
				,'AlwaysOnGroupKey' AS DimensionKey
				,'dbo.fhsmAlwaysOnState' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[GroupA]', NULL
				,'Group', NULL

			UNION ALL

			SELECT
				'Always On group-replica' AS DimensionName
				,'AlwaysOnGroupReplicaKey' AS DimensionKey
				,'dbo.fhsmAlwaysOnState' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[GroupA]', 'src.[GroupB]'
				,'Group', 'Replica'

			UNION ALL

			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmDatabaseState' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL
				,'Database', NULL
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
				,tgt.OutputColumn1 = src.OutputColumn1
				,tgt.OutputColumn2 = src.OutputColumn2
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(
				DimensionName, DimensionKey
				,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
				,SrcColumn1, SrcColumn2
				,OutputColumn1, OutputColumn2
			)
			VALUES(
				src.DimensionName, src.DimensionKey
				,src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn
				,src.SrcColumn1, src.SrcColumn2
				,src.OutputColumn1, src.OutputColumn2
			);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmAlwaysOnState';
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmDatabaseState';
	END;
END;
