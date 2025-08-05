SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableBackupStatus bit;

	SET @enableBackupStatus = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing BackupStatus', 0, 1) WITH NOWAIT;
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
		-- Create table dbo.fhsmBackupStatus and indexes if they not already exists
		--
		IF OBJECT_ID('dbo.fhsmBackupStatus', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmBackupStatus', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmBackupStatus(
					Id int identity(1,1) NOT NULL
					,DatabaseName nvarchar(128) NOT NULL
					,BackupStartDate datetime NULL
					,BackupFinishDate datetime NULL
					,ExpirationDate datetime NULL
					,Type char(1) NULL
					,BackupSize numeric(20,0) NULL
					,CompressedBackupSize numeric(20,0) NULL
					,IsCopyOnly bit NOT NULL
					,IsDamaged bit NOT NULL
					,LogicalDeviceName nvarchar(128) NULL
					,PhysicalDeviceName nvarchar(260) NULL
					,BackupsetName nvarchar(128) NULL
					,BackupsetDescription nvarchar(128) NULL
					,TimestampUTC datetime NOT NULL
					,Timestamp datetime NOT NULL
					,CONSTRAINT PK_BackupStatus PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmBackupStatus')) AND (i.name = 'NC_fhsmBackupStatus_TimestampUTC'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmBackupStatus_TimestampUTC] to table dbo.fhsmBackupStatus', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmBackupStatus_TimestampUTC ON dbo.fhsmBackupStatus(TimestampUTC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmBackupStatus')) AND (i.name = 'NC_fhsmBackupStatus_Timestamp'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmBackupStatus_Timestamp] to table dbo.fhsmBackupStatus', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmBackupStatus_Timestamp ON dbo.fhsmBackupStatus(Timestamp)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmBackupStatus')) AND (i.name = 'NC_fhsmBackupStatus_DatabaseName_BackupStartDate'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmBackupStatus_DatabaseName_BackupStartDate] to table dbo.fhsmBackupStatus', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmBackupStatus_DatabaseName_BackupStartDate ON dbo.fhsmBackupStatus(DatabaseName, BackupStartDate)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmBackupStatus')) AND (i.name = 'NC_fhsmBackupStatus_IsCopyOnly_IsDamaged'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmBackupStatus_IsCopyOnly_IsDamaged] to table dbo.fhsmBackupStatus', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmBackupStatus_IsCopyOnly_IsDamaged ON dbo.fhsmBackupStatus(IsCopyOnly ASC, IsDamaged ASC) INCLUDE(DatabaseName, BackupStartDate, Type)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmBackupStatus
		--
		BEGIN
			SET @objectName = 'dbo.fhsmBackupStatus';
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
		-- Create fact view @pbiSchema.[Backup age]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Backup age') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Backup age') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Backup age') + '
				AS
				SELECT
					b.DatabaseName
					,b.RecoveryModeChangeTimestampUTC
					,b.RecoveryModel
					,CASE WHEN (b.LatestFullBackupStartDate = 0) THEN NULL ELSE b.LatestFullBackupStartDate END AS LatestFullBackupStartDate
					,DATEDIFF(MINUTE, b.LatestFullBackupStartDate, GETDATE()) / 60 AS LatestFullBackupAgeHours
					,CASE WHEN (b.LatestDiffBackupStartDate = 0) THEN NULL ELSE b.LatestDiffBackupStartDate END AS LatestDiffBackupStartDate
					,DATEDIFF(MINUTE, b.LatestDiffBackupStartDate, GETDATE()) / 60 AS LatestDiffBackupAgeHours
					,CASE WHEN (b.LatestLogBackupStartDate = 0) THEN NULL ELSE b.LatestLogBackupStartDate END AS LatestLogBackupStartDate
					,DATEDIFF(MINUTE, b.LatestLogBackupStartDate, GETDATE()) / 60 AS LatestLogBackupAgeHours
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(b.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
				FROM (
					SELECT
						a.DatabaseName
						,a.RecoveryModeChangeTimestampUTC
						,a.RecoveryModel
						,CASE
							WHEN (a.LatestFullBackupStartDate > a.RecoveryModeChangeTimestamp) THEN a.LatestFullBackupStartDate
							ELSE 0
						END AS LatestFullBackupStartDate
						,CASE
							WHEN (a.LatestDiffBackupStartDate > a.RecoveryModeChangeTimestamp) THEN a.LatestDiffBackupStartDate
							WHEN (a.LatestDiffBackupStartDate IS NOT NULL) THEN 0
						END AS LatestDiffBackupStartDate
						,CASE
							WHEN (a.RecoveryModel IN (''FULL'', ''BULK_LOGGED'')) THEN CASE
								WHEN (a.LatestLogBackupStartDate > a.RecoveryModeChangeTimestamp) THEN a.LatestLogBackupStartDate
								ELSE 0
							END
						END AS LatestLogBackupStartDate
					FROM (
						SELECT
							d.DatabaseName
							,d.TimestampUTC AS RecoveryModeChangeTimestampUTC
							,d.Timestamp AS RecoveryModeChangeTimestamp
							,CASE d.recovery_model
								WHEN ''1'' THEN ''FULL''		-- Check for Database and Log
								WHEN ''2'' THEN ''BULK_LOGGED''	-- Check for Database and Log
								WHEN ''3'' THEN ''SIMPLE''		-- Check for Database
								ELSE ''?:'' + d.recovery_model
							END AS RecoveryModel
							,latest.LatestFullBackupStartDate
							,latest.LatestDiffBackupStartDate
							,latest.LatestLogBackupStartDate
						FROM (
							SELECT dbState.DatabaseName, dbState.TimestampUTC, dbState.Timestamp, dbState.Value AS [recovery_model]
							FROM dbo.fhsmDatabaseState AS dbState
							WHERE
								(dbState.Query = 31)
								AND (dbState.ValidTo = ''9999-12-31 23:59:59.000'')
								AND (dbState.[Key] = ''recovery_model'')
								AND (dbState.DatabaseName <> ''tempdb'')
						) AS d
				';
			SET @stmt += '
						LEFT OUTER JOIN (
							SELECT
								bsRanked.DatabaseName
								,MAX(CASE WHEN (bsRanked.Type = ''D'') THEN bsRanked.BackupStartDate END) AS LatestFullBackupStartDate
								,MAX(CASE WHEN (bsRanked.Type = ''I'') THEN bsRanked.BackupStartDate END) AS LatestDiffBackupStartDate
								,MAX(CASE WHEN (bsRanked.Type = ''L'') THEN bsRanked.BackupStartDate END) AS LatestLogBackupStartDate
							FROM (
								SELECT
									bs.DatabaseName
									,bs.Type
									,bs.BackupStartDate
									,ROW_NUMBER() OVER(PARTITION BY bs.DatabaseName, bs.Type ORDER BY bs.BackupStartDate DESC) AS _Rnk
								FROM dbo.fhsmBackupStatus AS bs
								WHERE (bs.IsCopyOnly = 0) AND (bs.IsDamaged = 0)
							) AS bsRanked
							WHERE (bsRanked._Rnk = 1)
							GROUP BY bsRanked.DatabaseName
						) AS latest ON (d.DatabaseName = latest.DatabaseName)
					) AS a
				) AS b;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Backup age]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Backup age');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Backup status]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Backup status') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Backup status') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Backup status') + '
				AS
				SELECT
					bs.DatabaseName
					,bs.BackupStartDate
					,bs.BackupFinishDate
					,COALESCE(NULLIF(DATEDIFF(SECOND, bs.BackupStartDate, bs.BackupFinishDate), 0), 1) AS Duration		-- Duration of 0 sec. will always be 1 sec.
					,bs.ExpirationDate
					,CASE bs.Type
						WHEN ''D'' THEN ''Database''
						WHEN ''I'' THEN ''Differential database''
						WHEN ''L'' THEN ''Log''
						WHEN ''F'' THEN ''File/filegroup''
						WHEN ''G'' THEN ''Differential file''
						WHEN ''P'' THEN ''Partial''
						WHEN ''Q'' THEN ''Differential partial''
						ELSE ''?:'' + COALESCE(bs.Type, ''<NULL>'')
					END AS Type
					,bs.BackupSize
					,bs.CompressedBackupSize
					,bs.IsCopyOnly
					,bs.IsDamaged
					,bs.LogicalDeviceName
					,bs.PhysicalDeviceName
					,bs.BackupsetName
					,bs.BackupsetDescription
					,bs.Timestamp
					,CAST(bs.Timestamp AS date) AS Date
					,(DATEPART(HOUR, bs.Timestamp) * 60 * 60) + (DATEPART(MINUTE, bs.Timestamp) * 60) + (DATEPART(SECOND, bs.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(bs.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(1, bs.Type, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS BackupTypeJunkDimensionKey
				FROM dbo.fhsmBackupStatus AS bs;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Backup status]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Backup status');
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
		-- Create stored procedure dbo.fhsmSPBackupStatus
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPBackupStatus'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPBackupStatus AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPBackupStatus (
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameter nvarchar(max);
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

						INSERT INTO dbo.fhsmBackupStatus(
							DatabaseName
							,BackupStartDate, BackupFinishDate, ExpirationDate
							,Type
							,BackupSize, CompressedBackupSize
							,IsCopyOnly, IsDamaged
							,LogicalDeviceName, PhysicalDeviceName
							,BackupsetName, BackupsetDescription
							,TimestampUTC, Timestamp
						)
						SELECT
							bs.database_name
							,bs.backup_start_date, bs.backup_finish_date, bs.expiration_date
							,bs.type
							,bs.backup_size, bs.compressed_backup_size
							,bs.is_copy_only, bs.is_damaged
							,bmf.logical_device_name, bmf.physical_device_name
							,bs.name AS backupset_name, bs.description AS backupset_description
							,@nowUTC, @now
						FROM msdb.dbo.backupmediafamily AS bmf
						INNER JOIN msdb.dbo.backupset AS bs ON (bmf.media_set_id = bs.media_set_id)
						WHERE NOT EXISTS (
							SELECT *
							FROM dbo.fhsmBackupStatus AS existingBS
							WHERE (existingBS.DatabaseName COLLATE DATABASE_DEFAULT = bs.database_name) AND (existingBS.BackupStartDate = bs.backup_start_date)
						)
						ORDER BY
							bs.database_name, 
							bs.backup_finish_date;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPBackupStatus
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPBackupStatus';
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
				,'dbo.fhsmBackupStatus'
				,1
				,'TimestampUTC'
				,1
				,90
				,NULL

			UNION ALL

			SELECT
				1
				,'dbo.fhsmBackupStatus'
				,2
				,'TimestampUTC'
				,1
				,7
				,'Type = ''L'''
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
				@enableBackupStatus								AS Enabled
				,0												AS DeploymentStatus
				,'Backup status'								AS Name
				,PARSENAME('dbo.fhsmSPBackupStatus', 1)			AS Task
				,60 * 60										AS ExecutionDelaySec
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
			,SrcColumn1, SrcColumn2, SrcColumn3
			,OutputColumn1, OutputColumn2, OutputColumn3
		) AS (
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmBackupStatus' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL
				,'Database', NULL, NULL
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
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmBackupStatus';
	END;
END;
