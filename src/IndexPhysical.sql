SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableIndexPhysical bit;

	SET @enableIndexPhysical = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing IndexPhysical', 0, 1) WITH NOWAIT;
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
		SET @version = '2.0';

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
		-- Create table dbo.fhsmIndexPhysical if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmIndexPhysical', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmIndexPhysical', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmIndexPhysical(
					Id int identity(1,1) NOT NULL
					,DatabaseName nvarchar(128) NOT NULL
					,SchemaName nvarchar(128) NOT NULL
					,ObjectName nvarchar(128) NOT NULL
					,IndexName nvarchar(128) NULL
					,Mode nvarchar(8) NOT NULL
					,PartitionNumber int NOT NULL
					,IndexTypeDesc nvarchar(60) NOT NULL
					,AllocUnitTypeDesc nvarchar(60) NOT NULL
					,IndexDepth tinyint NOT NULL
					,IndexLevel tinyint NOT NULL
					,ColumnstoreDeleteBufferStateDesc nvarchar(60) NULL
					,AvgFragmentationInPercent float NOT NULL
					,FragmentCount bigint NULL
					,AvgFragmentSizeInPages float NULL
					,PageCount bigint NOT NULL
					,AvgPageSpaceUsedInPercent float NULL
					,RecordCount bigint NULL
					,GhostRecordCount bigint NULL
					,VersionGhostRecordCount bigint NULL
					,MinRecordSizeInBytes int NULL
					,MaxRecordSizeInBytes int NULL
					,AvgRecordSizeInBytes float NULL
					,ForwardedRecordCount bigint NULL
					,CompressedPageCount bigint NULL
					,VersionRecordCount bigint NULL
					,InrowVersionRecordCount bigint NULL
					,InrowDiffVersionRecordCount bigint NULL
					,TotalInrowVersionPayloadSizeInBytes bigint NULL
					,OffrowRegularVersionRecordCount bigint NULL
					,OffrowLongTermVersionRecordCount bigint NULL
					,LastSQLServiceRestart datetime NOT NULL
					,TimestampUTC datetime NOT NULL
					,Timestamp datetime NOT NULL
					,TimestampUTCDate date NOT NULL
					,TimestampDate date NOT NULL
					,TimeKey int NOT NULL
					,DatabaseKey bigint NOT NULL
					,SchemaKey bigint NOT NULL
					,ObjectKey bigint NOT NULL
					,IndexKey bigint NOT NULL
					,IndexTypeKey bigint NOT NULL
					,IndexAllocTypeKey bigint NOT NULL
					,CONSTRAINT NCPK_fhsmIndexPhysical PRIMARY KEY NONCLUSTERED(Id)' + @tableCompressionStmt + '
				);

				CREATE CLUSTERED INDEX CL_fhsmIndexPhysical_TimestampUTC ON dbo.fhsmIndexPhysical(TimestampUTC)' + @tableCompressionStmt + ';
				CREATE NONCLUSTERED INDEX NC_fhsmIndexPhysical_Timestamp ON dbo.fhsmIndexPhysical(Timestamp)' + @tableCompressionStmt + ';
				CREATE NONCLUSTERED INDEX NC_fhsmIndexPhysical_DatabaseKey_SchemaKey_ObjectKey_TimestampUTCDate_Mode ON dbo.fhsmIndexPhysical(DatabaseKey, SchemaKey, ObjectKey, TimestampUTCDate, Mode)' + @tableCompressionStmt + ';
				CREATE NONCLUSTERED INDEX NC_fhsmIndexPhysical_Mode ON dbo.fhsmIndexPhysical(Mode)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmIndexPhysical
		--
		BEGIN
			SET @objectName = 'dbo.fhsmIndexPhysical';
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
		-- Create fact view @pbiSchema.[Index physical]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index physical') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index physical') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index physical') + '
				AS
				SELECT
					rankedData.Mode
					,rankedData.PartitionNumber
					,rankedData.IndexTypeDesc
					,rankedData.AllocUnitTypeDesc
					,rankedData.IndexDepth
					,rankedData.IndexLevel
					,rankedData.ColumnstoreDeleteBufferStateDesc
					,rankedData.AvgFragmentationInPercent
					,rankedData.FragmentCount
					,rankedData.AvgFragmentSizeInPages
					,rankedData.PageCount
					,rankedData.AvgPageSpaceUsedInPercent
					,rankedData.RecordCount
					,rankedData.GhostRecordCount
					,rankedData.VersionGhostRecordCount
					,rankedData.MinRecordSizeInBytes
					,rankedData.MaxRecordSizeInBytes
					,rankedData.AvgRecordSizeInBytes
					,rankedData.ForwardedRecordCount
					,rankedData.CompressedPageCount
					,rankedData.VersionRecordCount
					,rankedData.InrowVersionRecordCount
					,rankedData.InrowDiffVersionRecordCount
					,rankedData.TotalInrowVersionPayloadSizeInBytes
					,rankedData.OffrowRegularVersionRecordCount
					,rankedData.OffrowLongTermVersionRecordCount
					,rankedData.TimestampDate Date
					,rankedData.TimeKey
					,rankedData.DatabaseKey
					,rankedData.SchemaKey
					,rankedData.ObjectKey
					,rankedData.IndexKey
					,rankedData.IndexTypeKey
					,rankedData.IndexAllocTypeKey
				FROM (
					SELECT
						ip.*
						,DENSE_RANK() OVER(PARTITION BY ip.DatabaseKey, ip.SchemaKey, ip.ObjectKey ORDER BY CASE ip.Mode WHEN ''DETAILED'' THEN 1 WHEN ''SAMPLED'' THEN 2 ELSE 3 END, ip.TimestampUTC DESC) AS _Rnk_
					FROM dbo.fhsmIndexPhysical AS ip
					WHERE (ip.TimestampUTC >= (
						SELECT DATEADD(HOUR, -24, MAX(ip2.TimestampUTC))
						FROM dbo.fhsmIndexPhysical AS ip2
					))
				) AS rankedData
				WHERE (rankedData._Rnk_ = 1);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Index physical]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index physical');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Index physical detailed]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index physical detailed') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index physical detailed') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index physical detailed') + '
				AS
				SELECT
					ip.Mode
					,ip.PartitionNumber
					,ip.IndexTypeDesc
					,ip.AllocUnitTypeDesc
					,ip.IndexDepth
					,ip.IndexLevel
					,ip.ColumnstoreDeleteBufferStateDesc
					,ip.AvgFragmentationInPercent
					,ip.FragmentCount
					,ip.AvgFragmentSizeInPages
					,ip.PageCount
					,ip.AvgPageSpaceUsedInPercent
					,ip.RecordCount
					,ip.GhostRecordCount
					,ip.VersionGhostRecordCount
					,ip.MinRecordSizeInBytes
					,ip.MaxRecordSizeInBytes
					,ip.AvgRecordSizeInBytes
					,ip.ForwardedRecordCount
					,ip.CompressedPageCount
					,ip.VersionRecordCount
					,ip.InrowVersionRecordCount
					,ip.InrowDiffVersionRecordCount
					,ip.TotalInrowVersionPayloadSizeInBytes
					,ip.OffrowRegularVersionRecordCount
					,ip.OffrowLongTermVersionRecordCount
					,ip.Timestamp
					,ip.TimestampDate AS Date
					,ip.TimeKey
					,ip.DatabaseKey
					,ip.SchemaKey
					,ip.ObjectKey
					,ip.IndexKey
					,ip.IndexTypeKey
					,ip.IndexAllocTypeKey
				FROM dbo.fhsmIndexPhysical AS ip
				WHERE (ip.Mode = ''DETAILED'')
			';
			SET @stmt += '
				UNION ALL

				SELECT
					ip.Mode
					,ip.PartitionNumber
					,ip.IndexTypeDesc
					,ip.AllocUnitTypeDesc
					,ip.IndexDepth
					,ip.IndexLevel
					,ip.ColumnstoreDeleteBufferStateDesc
					,ip.AvgFragmentationInPercent
					,ip.FragmentCount
					,ip.AvgFragmentSizeInPages
					,ip.PageCount
					,ip.AvgPageSpaceUsedInPercent
					,ip.RecordCount
					,ip.GhostRecordCount
					,ip.VersionGhostRecordCount
					,ip.MinRecordSizeInBytes
					,ip.MaxRecordSizeInBytes
					,ip.AvgRecordSizeInBytes
					,ip.ForwardedRecordCount
					,ip.CompressedPageCount
					,ip.VersionRecordCount
					,ip.InrowVersionRecordCount
					,ip.InrowDiffVersionRecordCount
					,ip.TotalInrowVersionPayloadSizeInBytes
					,ip.OffrowRegularVersionRecordCount
					,ip.OffrowLongTermVersionRecordCount
					,ip.Timestamp
					,ip.TimestampDate AS Date
					,ip.TimeKey
					,ip.DatabaseKey
					,ip.SchemaKey
					,ip.ObjectKey
					,ip.IndexKey
					,ip.IndexTypeKey
					,ip.IndexAllocTypeKey
				FROM dbo.fhsmIndexPhysical AS ip
				WHERE (ip.Mode = ''SAMPLED'')
					AND NOT EXISTS (
						SELECT *
						FROM dbo.fhsmIndexPhysical AS ip2
						WHERE (ip2.DatabaseKey = ip.DatabaseKey)
							AND (ip2.SchemaKey = ip.SchemaKey)
							AND (ip2.ObjectKey = ip.ObjectKey)
							AND (ip2.TimestampUTCDate = ip.TimestampUTCDate)
							AND (ip2.Mode = ''DETAILED'')
					)
			';
			SET @stmt += '
				UNION ALL

				SELECT
					ip.Mode
					,ip.PartitionNumber
					,ip.IndexTypeDesc
					,ip.AllocUnitTypeDesc
					,ip.IndexDepth
					,ip.IndexLevel
					,ip.ColumnstoreDeleteBufferStateDesc
					,ip.AvgFragmentationInPercent
					,ip.FragmentCount
					,ip.AvgFragmentSizeInPages
					,ip.PageCount
					,ip.AvgPageSpaceUsedInPercent
					,ip.RecordCount
					,ip.GhostRecordCount
					,ip.VersionGhostRecordCount
					,ip.MinRecordSizeInBytes
					,ip.MaxRecordSizeInBytes
					,ip.AvgRecordSizeInBytes
					,ip.ForwardedRecordCount
					,ip.CompressedPageCount
					,ip.VersionRecordCount
					,ip.InrowVersionRecordCount
					,ip.InrowDiffVersionRecordCount
					,ip.TotalInrowVersionPayloadSizeInBytes
					,ip.OffrowRegularVersionRecordCount
					,ip.OffrowLongTermVersionRecordCount
					,ip.Timestamp
					,ip.TimestampDate AS Date
					,ip.TimeKey
					,ip.DatabaseKey
					,ip.SchemaKey
					,ip.ObjectKey
					,ip.IndexKey
					,ip.IndexTypeKey
					,ip.IndexAllocTypeKey
				FROM dbo.fhsmIndexPhysical AS ip
				WHERE NOT EXISTS (
						SELECT *
						FROM dbo.fhsmIndexPhysical AS ip2
						WHERE (ip2.DatabaseKey = ip.DatabaseKey)
							AND (ip2.SchemaKey = ip.SchemaKey)
							AND (ip2.ObjectKey = ip.ObjectKey)
							AND (ip2.TimestampUTCDate = ip.TimestampUTCDate)
							AND (ip2.Mode IN (''DETAILED'', ''SAMPLED''))
					);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Index physical detailed]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index physical detailed');
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
		-- Create stored procedure dbo.fhsmSPIndexPhysical
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPIndexPhysical'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPIndexPhysical AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPIndexPhysical (
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @columnstoreDeleteBufferStateDescGroupByStmt nvarchar(max);
					DECLARE @columnstoreDeleteBufferStateDescStmt nvarchar(max);
					DECLARE @database nvarchar(128);
					DECLARE @databases nvarchar(max);
					DECLARE @fhsmDatabaseName nvarchar(128);
					DECLARE @inrowDiffVersionRecordCountStmt nvarchar(max);
					DECLARE @inrowVersionRecordCountStmt nvarchar(max);
					DECLARE @message nvarchar(max);
					DECLARE @mode nvarchar(128);
					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @object nvarchar(128);
					DECLARE @offrowLongTermVersionRecordCountStmt nvarchar(max);
					DECLARE @offrowRegularVersionRecordCountStmt nvarchar(max);
					DECLARE @parameters nvarchar(max);
					DECLARE @parametersTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
					DECLARE @replicaId uniqueidentifier;
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);
					DECLARE @totalInrowVersionPayloadSizeInBytesStmt nvarchar(max);
					DECLARE @versionRecordCountStmt nvarchar(max);

					SET @fhsmDatabaseName = DB_NAME();
					SET @thisTask = OBJECT_NAME(@@PROCID);
					SET @version = ''' + @version + ''';

					--
					-- Get the parameters for the command
					--
					BEGIN
						SET @parameters = dbo.fhsmFNGetTaskParameter(@thisTask, @name);

						INSERT INTO @parametersTable([Key], Value)
						SELECT
							(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 1)) AS [Key]
							,(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 2)) AS Value
						FROM dbo.fhsmFNSplitString(@parameters, '';'') AS p;

						SET @databases = (SELECT pt.Value FROM @parametersTable AS pt WHERE (pt.[Key] = ''@Databases''));
						SET @object = (SELECT pt.Value FROM @parametersTable AS pt WHERE (pt.[Key] = ''@Object''));
						SET @mode = (SELECT pt.Value FROM @parametersTable AS pt WHERE (pt.[Key] = ''@Mode''));
		
						--
						-- Trim @databases if Ola Hallengren style has been chosen
						--
						BEGIN
							SET @databases = LTRIM(RTRIM(@databases));
							WHILE (LEFT(@databases, 1) = '''''''') AND (LEFT(@databases, 1) = '''''''')
							BEGIN
								SET @databases = SUBSTRING(@databases, 2, LEN(@databases) - 2);
							END;
						END;

						--
						-- Trim @object if Ola Hallengren style has been chosen
						--
						BEGIN
							SET @object = LTRIM(RTRIM(@object));
							WHILE (LEFT(@object, 1) = '''''''') AND (LEFT(@object, 1) = '''''''')
							BEGIN
								SET @object = SUBSTRING(@object, 2, LEN(@object) - 2);
							END;
						END;

						--
						-- Trim @mode if Ola Hallengren style has been chosen
						--
						BEGIN
							SET @mode = LTRIM(RTRIM(@mode));
							WHILE (LEFT(@mode, 1) = '''''''') AND (LEFT(@mode, 1) = '''''''')
							BEGIN
								SET @mode = SUBSTRING(@mode, 2, LEN(@mode) - 2);
							END;
						END;
					END;
			';
			SET @stmt += '
					--
					-- Verify the @mode parameter
					--
					BEGIN
						IF (@mode IS NULL) OR (@mode NOT IN (''LIMITED'', ''SAMPLED'', ''DETAILED''))
						BEGIN
							SET @message = ''Mode is invalied - '' + COALESCE(@mode, ''<NULL>'');
							EXEC dbo.fhsmSPLog @name = @name, @task = @thisTask, @type = ''Error'', @message = @message;

							RETURN -1;
						END;
					END;

					--
					-- Get the list of databases to process
					--
					BEGIN
						SELECT d.DatabaseName, d.[Order]
						INTO #dbList
						FROM dbo.fhsmFNParseDatabasesStr(@databases) AS d;
					END;

					--
					-- Collect data
					--
					BEGIN
						SELECT
							@now = SYSDATETIME()
							,@nowUTC = SYSUTCDATETIME();

						--
						-- Test if columnstore_delete_buffer_state_desc exists on dm_db_index_physical_stats
						--
						BEGIN
							IF EXISTS(
								SELECT *
								FROM master.sys.system_columns AS sc
								INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
								WHERE (so.name = ''dm_db_index_physical_stats'') AND (sc.name = ''columnstore_delete_buffer_state_desc'')
							)
							BEGIN
								SET @columnstoreDeleteBufferStateDescStmt = ''ddips.columnstore_delete_buffer_state_desc'';
								SET @columnstoreDeleteBufferStateDescGroupByStmt = '',ddips.columnstore_delete_buffer_state_desc'';
							END
							ELSE BEGIN
								SET @columnstoreDeleteBufferStateDescStmt = ''NULL'';
								SET @columnstoreDeleteBufferStateDescGroupByStmt = '''';
							END;
						END;

						--
						-- Test if version_record_count (and thereby all other *version*) exists on dm_db_index_physical_stats
						--
						BEGIN
							IF EXISTS(
								SELECT *
								FROM master.sys.system_columns AS sc
								INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
								WHERE (so.name = ''dm_db_index_physical_stats'') AND (sc.name = ''version_record_count'')
							)
							BEGIN
								SET @versionRecordCountStmt = ''SUM(ddips.version_record_count)'';
								SET @inrowVersionRecordCountStmt = ''SUM(ddips.inrow_version_record_count)'';
								SET @inrowDiffVersionRecordCountStmt = ''SUM(ddips.inrow_diff_version_record_count)'';
								SET @totalInrowVersionPayloadSizeInBytesStmt = ''SUM(ddips.total_inrow_version_payload_size_in_bytes)'';
								SET @offrowRegularVersionRecordCountStmt = ''SUM(ddips.offrow_regular_version_record_count)'';
								SET @offrowLongTermVersionRecordCountStmt = ''SUM(ddips.offrow_long_term_version_record_count)'';
							END
							ELSE BEGIN
								SET @versionRecordCountStmt = ''NULL'';
								SET @inrowVersionRecordCountStmt = ''NULL'';
								SET @inrowDiffVersionRecordCountStmt = ''NULL'';
								SET @totalInrowVersionPayloadSizeInBytesStmt = ''NULL'';
								SET @offrowRegularVersionRecordCountStmt = ''NULL'';
								SET @offrowLongTermVersionRecordCountStmt = ''NULL'';
							END;
						END;

						DECLARE dCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
						SELECT dl.DatabaseName, ' + CASE WHEN (@productVersion1 <= 10) THEN 'NULL' ELSE 'd.replica_id' END + ' AS replica_id
						FROM #dbList AS dl
						INNER JOIN sys.databases AS d ON (d.name COLLATE DATABASE_DEFAULT = dl.DatabaseName)
						ORDER BY dl.[Order];

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
			';
			IF (@productVersion1 >= 11)
			BEGIN
				-- SQL Versions SQL2012 or higher
				SET @stmt += '
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
				';
			END;
			SET @stmt += '
							BEGIN
			';
			SET @stmt += '
								SET @stmt = ''
									USE '' + QUOTENAME(@database) + '';

									IF
										(@object COLLATE DATABASE_DEFAULT IS NULL)
										OR ((@object COLLATE DATABASE_DEFAULT IS NOT NULL) AND (OBJECT_ID(@object) IS NOT NULL))
									BEGIN
										SELECT
											DB_NAME() AS DatabaseName
											,sch.name AS SchemaName
											,o.name AS ObjectName
											,i.name AS IndexName
											,@mode AS Mode
											,ddips.partition_number AS PartitionNumber
											,ddips.index_type_desc AS IndexTypeDesc
											,ddips.alloc_unit_type_desc AS AllocUnitTypeDesc
											,ddips.index_depth AS IndexDepth
											,ddips.index_level AS IndexLevel
											,'' + @columnstoreDeleteBufferStateDescStmt + '' AS ColumnstoreDeleteBufferStateDesc
											,AVG(ddips.avg_fragmentation_in_percent) AS AvgFragmentationInPercent
											,SUM(ddips.fragment_count) AS FragmentCount
											,AVG(ddips.avg_fragment_size_in_pages) AS AvgFragmentSizeInPages
											,SUM(ddips.page_count) AS PageCount
											,AVG(ddips.avg_page_space_used_in_percent) AS AvgPageSpaceUsedInPercent
											,SUM(ddips.record_count) AS RecordCount
											,SUM(ddips.ghost_record_count) AS GhostRecordCount
											,SUM(ddips.version_ghost_record_count) AS VersionGhostRecordCount
											,AVG(ddips.min_record_size_in_bytes) AS MinRecordSizeInBytes
											,AVG(ddips.max_record_size_in_bytes) AS MaxRecordSizeInBytes
											,AVG(ddips.avg_record_size_in_bytes) AS AvgRecordSizeInBytes
											,SUM(ddips.forwarded_record_count) AS ForwardedRecordCount
											,SUM(ddips.compressed_page_count) AS CompressedPageCount
			';
			SET @stmt += '
											,'' + @versionRecordCountStmt + '' AS VersionRecordCount
											,'' + @inrowVersionRecordCountStmt + '' AS InrowVersionRecordCount
											,'' + @inrowDiffVersionRecordCountStmt + '' AS InrowDiffVersionRecordCount
											,'' + @totalInrowVersionPayloadSizeInBytesStmt + '' AS TotalInrowVersionPayloadSizeInBytes
											,'' + @offrowRegularVersionRecordCountStmt + '' AS OffrowRegularVersionRecordCount
											,'' + @offrowLongTermVersionRecordCountStmt + '' AS OffrowLongTermVersionRecordCount
											,(SELECT d.create_date FROM sys.databases AS d WITH (NOLOCK) WHERE (d.name = ''''tempdb'''')) AS LastSQLServiceRestart
											,@nowUTC, @now
											,CAST(@nowUTC AS date) AS TimestampUTCDate, CAST(@now AS date) AS TimestampDate
											,(DATEPART(HOUR, @now) * 60 * 60) + (DATEPART(MINUTE, @now) * 60) + (DATEPART(SECOND, @now)) AS TimeKey
											,(SELECT k.[Key] FROM '' + QUOTENAME(@fhsmDatabaseName) + ''.dbo.fhsmFNGenerateKey(DB_NAME(), DEFAULT,  DEFAULT, DEFAULT,                    DEFAULT,               DEFAULT)                    AS k) AS DatabaseKey
											,(SELECT k.[Key] FROM '' + QUOTENAME(@fhsmDatabaseName) + ''.dbo.fhsmFNGenerateKey(DB_NAME(), sch.name, DEFAULT, DEFAULT,                    DEFAULT,               DEFAULT)                    AS k) AS SchemaKey
											,(SELECT k.[Key] FROM '' + QUOTENAME(@fhsmDatabaseName) + ''.dbo.fhsmFNGenerateKey(DB_NAME(), sch.name, o.name,  DEFAULT,                    DEFAULT,               DEFAULT)                    AS k) AS ObjectKey
											,(SELECT k.[Key] FROM '' + QUOTENAME(@fhsmDatabaseName) + ''.dbo.fhsmFNGenerateKey(DB_NAME(), sch.name, o.name,  COALESCE(i.name, ''''N.A.''''), DEFAULT,               DEFAULT)                    AS k) AS IndexKey
											,(SELECT k.[Key] FROM '' + QUOTENAME(@fhsmDatabaseName) + ''.dbo.fhsmFNGenerateKey(DB_NAME(), sch.name, o.name,  COALESCE(i.name, ''''N.A.''''), ddips.index_type_desc, DEFAULT)                    AS k) AS IndexTypeKey
											,(SELECT k.[Key] FROM '' + QUOTENAME(@fhsmDatabaseName) + ''.dbo.fhsmFNGenerateKey(DB_NAME(), sch.name, o.name,  COALESCE(i.name, ''''N.A.''''), ddips.index_type_desc, ddips.alloc_unit_type_desc) AS k) AS IndexAllocTypeKey
										FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID(@object), NULL, NULL, @mode) AS ddips
										INNER JOIN sys.objects AS o ON (o.object_id = ddips.object_id)
										INNER JOIN sys.schemas AS sch ON (sch.schema_id = o.schema_id)
										LEFT OUTER JOIN sys.indexes AS i ON (ddips.object_id = i.object_id) AND (ddips.index_id = i.index_id)
										WHERE (o.type IN (''''U'''', ''''V''''))
										GROUP BY
											sch.name
											,o.name
											,i.name
											,ddips.partition_number
											,ddips.index_type_desc
											,ddips.alloc_unit_type_desc
											,ddips.index_depth
											,ddips.index_level
											'' + @columnstoreDeleteBufferStateDescGroupByStmt + '';
									END;
								'';
			';
			SET @stmt += '
								INSERT INTO dbo.fhsmIndexPhysical(
									DatabaseName, SchemaName, ObjectName, IndexName, Mode
									,PartitionNumber, IndexTypeDesc, AllocUnitTypeDesc, IndexDepth, IndexLevel, ColumnstoreDeleteBufferStateDesc
									,AvgFragmentationInPercent, FragmentCount, AvgFragmentSizeInPages
									,PageCount, AvgPageSpaceUsedInPercent, RecordCount
									,GhostRecordCount, VersionGhostRecordCount
									,MinRecordSizeInBytes, MaxRecordSizeInBytes, AvgRecordSizeInBytes
									,ForwardedRecordCount
									,CompressedPageCount
									,VersionRecordCount, InrowVersionRecordCount, InrowDiffVersionRecordCount, TotalInrowVersionPayloadSizeInBytes
									,OffrowRegularVersionRecordCount, OffrowLongTermVersionRecordCount
									,LastSQLServiceRestart
									,TimestampUTC, Timestamp
									,TimestampUTCDate, TimestampDate
									,TimeKey
									,DatabaseKey, SchemaKey, ObjectKey
									,IndexKey, IndexTypeKey, IndexAllocTypeKey
								)
								EXEC sp_executesql
									@stmt
									,N''@mode nvarchar(8), @object nvarchar(128), @now datetime, @nowUTC datetime''
									,@mode = @mode, @object = @object, @now = @now, @nowUTC = @nowUTC;
							END
							ELSE BEGIN
								SET @message = ''Database '''''' + @database + '''''' is member of a replica but this server is not the primary node'';
								EXEC dbo.fhsmSPLog @name = @name, @task = @thisTask, @type = ''Warning'', @message = @message;
							END;
						END;

						CLOSE dCur;
						DEALLOCATE dCur;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPIndexPhysical
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPIndexPhysical';
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
				,'dbo.fhsmIndexPhysical'
				,1
				,'TimestampUTC'
				,1
				,90
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
				@enableIndexPhysical
				,'Index physical'
				,PARSENAME('dbo.fhsmSPIndexPhysical', 1)
				,12 * 60 * 60
				,CAST('1900-1-1T22:00:00.0000' AS datetime2(0))
				,CAST('1900-1-1T23:00:00.0000' AS datetime2(0))
				,1, 1, 1, 1, 1, 1, 1
				,'@Databases = ''USER_DATABASES, msdb'' ; @Mode = LIMITED'
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
			,SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4, SrcColumn5, SrcColumn6
			,OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4, OutputColumn5, OutputColumn6
		) AS (
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmIndexPhysical' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Schema' AS DimensionName
				,'SchemaKey' AS DimensionKey
				,'dbo.fhsmIndexPhysical' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', NULL, NULL, NULL, NULL
				,'Database', 'Schema', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Object' AS DimensionName
				,'ObjectKey' AS DimensionKey
				,'dbo.fhsmIndexPhysical' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', NULL, NULL, NULL
				,'Database', 'Schema', 'Object', NULL, NULL, NULL

			UNION ALL

			SELECT
				'Index' AS DimensionName
				,'IndexKey' AS DimensionKey
				,'dbo.fhsmIndexPhysical' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'COALESCE(src.[IndexName], ''N.A.'')', NULL, NULL
				,'Database', 'Schema', 'Object', 'Index', NULL, NULL

			UNION ALL

			SELECT
				'Index type' AS DimensionName
				,'IndexTypeKey' AS DimensionKey
				,'dbo.fhsmIndexPhysical' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'COALESCE(src.[IndexName], ''N.A.'')', 'src.[IndexTypeDesc]', NULL
				,'Database', 'Schema', 'Object', 'Index', 'IndexType', NULL

			UNION ALL

			SELECT
				'Index alloc type' AS DimensionName
				,'IndexAllocTypeKey' AS DimensionKey
				,'dbo.fhsmIndexPhysical' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'COALESCE(src.[IndexName], ''N.A.'')', 'src.[IndexTypeDesc]', 'src.[AllocUnitTypeDesc]'
				,'Database', 'Schema', 'Object', 'Index', 'IndexType', 'IndexAllocType'
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
				,tgt.SrcColumn4 = src.SrcColumn4
				,tgt.SrcColumn5 = src.SrcColumn5
				,tgt.SrcColumn6 = src.SrcColumn6
				,tgt.OutputColumn1 = src.OutputColumn1
				,tgt.OutputColumn2 = src.OutputColumn2
				,tgt.OutputColumn3 = src.OutputColumn3
				,tgt.OutputColumn4 = src.OutputColumn4
				,tgt.OutputColumn5 = src.OutputColumn5
				,tgt.OutputColumn6 = src.OutputColumn6
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(
				DimensionName, DimensionKey
				,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
				,SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4, SrcColumn5, SrcColumn6
				,OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4, OutputColumn5, OutputColumn6
			)
			VALUES(
				src.DimensionName, src.DimensionKey
				,src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn
				,src.SrcColumn1, src.SrcColumn2, src.SrcColumn3, src.SrcColumn4, src.SrcColumn5, src.SrcColumn6
				,src.OutputColumn1, src.OutputColumn2, src.OutputColumn3, src.OutputColumn4, src.OutputColumn5, src.OutputColumn6
			);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmIndexPhysical';
	END;
END;
