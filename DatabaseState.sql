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
	DECLARE @productEndPos int;
	DECLARE @productStartPos int;
	DECLARE @productVersion nvarchar(128);
	DECLARE @productVersion1 int;
	DECLARE @productVersion2 int;
	DECLARE @productVersion3 int;
	DECLARE @returnValue int;
	DECLARE @schName nvarchar(128);
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
		SET @version = '1.3';

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
	-- Create tables
	--
	BEGIN
		--
		-- Create table dbo.fhsmDatabaseState if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmDatabaseState', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmDatabaseState', 0, 1) WITH NOWAIT;

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
				,CONSTRAINT PK_fhsmDatabaseState PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmDatabaseState_TimestampUTC ON dbo.fhsmDatabaseState(TimestampUTC);
			CREATE NONCLUSTERED INDEX NC_fhsmDatabaseState_Timestamp ON dbo.fhsmDatabaseState(Timestamp);
			CREATE NONCLUSTERED INDEX NC_fhsmDatabaseState_Query_DatabaseName_Key_ValidTo ON dbo.fhsmDatabaseState(Query, DatabaseName, [Key], ValidTo) INCLUDE(Value);
			CREATE NONCLUSTERED INDEX NC_fhsmDatabaseState_ValidTo_Query_DatabaseName_key ON dbo.fhsmDatabaseState(ValidTo, Query, DatabaseName, [Key]) INCLUDE(Value);
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

	--
	-- Create functions
	--

	--
	-- Create views
	--
	BEGIN
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
							,[is_auto_close_on], [is_auto_shrink_on], [is_auto_update_stats_async_on], [is_mixed_page_allocation_on]
							,[is_read_committed_snapshot_on], [page_verify_option], [recovery_model], [target_recovery_time_in_seconds])
					) AS pvt;
			';
			EXEC(@stmt);
		END;

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
							,''is_auto_close_on'', ''is_auto_shrink_on'', ''is_auto_update_stats_async_on'', ''is_mixed_page_allocation_on''
							,''is_read_committed_snapshot_on'', ''page_verify_option'', ''recovery_model'', ''target_recovery_time_in_seconds''
						))
				)
				';
			END;
			SET @stmt += '
					SELECT
						a.DatabaseName
						,CASE a.[Key]
							WHEN ''collation_name'' THEN ''Collation''
							WHEN ''compatibility_level'' THEN ''Comp. level''
							WHEN ''delayed_durability'' THEN ''Delayed durability''
							WHEN ''is_auto_close_on'' THEN ''Auto close''
							WHEN ''is_auto_shrink_on'' THEN ''Auto shrink''
							WHEN ''is_auto_update_stats_async_on'' THEN ''Auto update stats. async.''
							WHEN ''is_mixed_page_allocation_on'' THEN ''Mixed page allocation''
							WHEN ''is_read_committed_snapshot_on'' THEN ''IsReadCommittedSnapshotOn''
							WHEN ''page_verify_option'' THEN ''Page verify''
							WHEN ''recovery_model'' THEN ''Recovery model''
							WHEN ''target_recovery_time_in_seconds'' THEN ''Target recovery time in sec.''
							ELSE a.[Key]
						END AS [Key]
						,a.ValidFrom
						,a.ValidTo
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
								,''is_auto_close_on'', ''is_auto_shrink_on'', ''is_auto_update_stats_async_on'', ''is_mixed_page_allocation_on''
								,''is_read_committed_snapshot_on'', ''page_verify_option'', ''recovery_model'', ''target_recovery_time_in_seconds''
							))
				';
			END;
			SET @stmt += '
					) AS a
					WHERE (a.Value <> a.PreviousValue);
			';
			EXEC(@stmt);
		END;

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
	-- Create stored procedures
	--
	BEGIN
		--
		-- Create stored procedure dbo.fhsmSPDatabaseState
		--
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

	--
	-- Register retention
	--
	BEGIN
		WITH
		retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter) AS(
			SELECT
				1
				,'dbo.fhsmDatabaseState'
				,1
				,'TimestampUTC'
				,1
				,180
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
		schedules(Enabled, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters) AS(
			SELECT
				1
				,'Database State'
				,PARSENAME('dbo.fhsmSPDatabaseState', 1)
				,1 * 60 * 60
				,CAST('1900-1-1T00:00:00.0000' AS datetime2(0))
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))
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
			,SrcColumn1
			,OutputColumn1
		) AS (
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmDatabaseState' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]'
				,'Database'
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
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmDatabaseState';
	END;
END;
