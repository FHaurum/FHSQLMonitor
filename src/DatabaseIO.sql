SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableDatabaseIO bit;

	SET @enableDatabaseIO = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing DatabaseIO', 0, 1) WITH NOWAIT;
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
		SET @version = '2.7';

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
		-- Create table dbo.fhsmDatabaseIO and indexes if they not already exists
		--
		IF OBJECT_ID('dbo.fhsmDatabaseIO', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmDatabaseIO', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmDatabaseIO(
					Id int identity(1,1) NOT NULL
					,DatabaseName nvarchar(128) NOT NULL
					,LogicalName nvarchar(128) NOT NULL
					,Type tinyint NOT NULL
					,SampleMS bigint NOT NULL
					,IOStall bigint NOT NULL
					,NumOfReads bigint NOT NULL
					,NumOfBytesRead bigint NOT NULL
					,IOStallReadMS bigint NOT NULL
					,IOStallQueuedReadMS bigint NULL
					,NumOfWrites bigint NOT NULL
					,NumOfBytesWritten bigint NOT NULL
					,IOStallWriteMS bigint NOT NULL
					,IOStallQueuedWriteMS bigint NULL
					,SizeOnDiskBytes bigint NOT NULL
					,TimestampUTC datetime NOT NULL
					,Timestamp datetime NOT NULL
					,CONSTRAINT PK_DatabaseIO PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmDatabaseIO')) AND (i.name = 'NC_fhsmDatabaseIO_TimestampUTC'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmDatabaseIO_TimestampUTC] to table dbo.fhsmDatabaseIO', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmDatabaseIO_TimestampUTC ON dbo.fhsmDatabaseIO(TimestampUTC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmDatabaseIO')) AND (i.name = 'NC_fhsmDatabaseIO_Timestamp'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmDatabaseIO_Timestamp] to table dbo.fhsmDatabaseIO', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmDatabaseIO_Timestamp ON dbo.fhsmDatabaseIO(Timestamp)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmDatabaseIO')) AND (i.name = 'NC_fhsmDatabaseIO_DatabaseName_LogicalName_Type'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmDatabaseIO_DatabaseName_LogicalName_Type] to table dbo.fhsmDatabaseIO', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmDatabaseIO_DatabaseName_LogicalName_Type ON dbo.fhsmDatabaseIO(DatabaseName, LogicalName, Type)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmDatabaseIO
		--
		BEGIN
			SET @objectName = 'dbo.fhsmDatabaseIO';
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
		-- Create fact view @pbiSchema.[Database IO]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database IO') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database IO') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database IO') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				WITH databaseIO AS (
					SELECT
						dio.DatabaseName
						,dio.LogicalName
						,dio.Type
						,dio.SampleMS
						,dio.IOStall
						,dio.NumOfReads
						,dio.NumOfBytesRead
						,dio.IOStallReadMS
						,dio.IOStallQueuedReadMS
						,dio.NumOfWrites
						,dio.NumOfBytesWritten
						,dio.IOStallWriteMS
						,dio.IOStallQueuedWriteMS
						,dio.Timestamp
						,CAST(dio.Timestamp AS date) AS Date
						,ROW_NUMBER() OVER(PARTITION BY dio.DatabaseName, dio.LogicalName, dio.Type ORDER BY dio.TimestampUTC) AS Idx
					FROM dbo.fhsmDatabaseIO AS dio
				)
				';
			END;
			SET @stmt += '
				SELECT
					b.DeltaNumOfReads AS NumOfReads
					,b.DeltaNumOfBytesRead AS NumOfBytesRead
					,CASE
						WHEN b.DeltaNumOfReads = 0 THEN NULL
						ELSE b.DeltaIOStallReadMS / CAST(b.DeltaNumOfReads AS decimal(12,1))
					END AS ReadLatencyMS
					,b.DeltaNumOfWrites AS NumOfWrites
					,b.DeltaNumOfBytesWritten AS NumOfBytesWritten
					,CASE
						WHEN b.DeltaNumOfWrites = 0 THEN NULL
						ELSE b.DeltaIOStallWriteMS / CAST(b.DeltaNumOfWrites AS decimal(12,1))
					END AS WriteLatencyMS

					,b.Timestamp
					,CAST(b.Timestamp AS date) AS Date
					,(DATEPART(HOUR, b.Timestamp) * 60 * 60) + (DATEPART(MINUTE, b.Timestamp) * 60) + (DATEPART(SECOND, b.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(b.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(b.DatabaseName, b.LogicalName,
						CASE b.Type
							WHEN 0 THEN ''Data''
							WHEN 1 THEN ''Log''
							WHEN 2 THEN ''Filestream''
							WHEN 4 THEN ''Fulltext''
							ELSE ''Other''
						END,
					DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseFileKey
			';
			SET @stmt += '
				FROM (
					SELECT
						CASE
							WHEN (a.PreviousIOStall IS NULL) OR (a.PreviousSampleMS IS NULL) THEN NULL					-- Ignore 1. data set - Yes we loose one data set but better than having visuals showing very high data
							WHEN (a.PreviousIOStall > a.IOStall) OR (a.PreviousSampleMS > a.SampleMS) THEN a.IOStall	-- Either has the counters had an overflow or the server har been restarted
							ELSE a.IOStall - a.PreviousIOStall															-- Difference
						END AS DeltaIOStall
						,CASE
							WHEN (a.PreviousNumOfReads IS NULL) OR (a.PreviousSampleMS IS NULL) THEN NULL
							WHEN (a.PreviousNumOfReads > a.NumOfReads) OR (a.PreviousSampleMS > a.SampleMS) THEN a.NumOfReads
							ELSE a.NumOfReads - a.PreviousNumOfReads
						END AS DeltaNumOfReads
						,CASE
							WHEN (a.PreviousNumOfBytesRead IS NULL) OR (a.PreviousSampleMS IS NULL) THEN NULL
							WHEN (a.PreviousNumOfBytesRead > a.NumOfBytesRead) OR (a.PreviousSampleMS > a.SampleMS) THEN a.NumOfBytesRead
							ELSE a.NumOfBytesRead - a.PreviousNumOfBytesRead
						END AS DeltaNumOfBytesRead
						,CASE
							WHEN (a.PreviousIOStallReadMS IS NULL) OR (a.PreviousSampleMS IS NULL) THEN NULL
							WHEN (a.PreviousIOStallReadMS > a.IOStallReadMS) OR (a.PreviousSampleMS > a.SampleMS) THEN a.IOStallReadMS
							ELSE a.IOStallReadMS - a.PreviousIOStallReadMS
						END AS DeltaIOStallReadMS
						,CASE
							WHEN (a.PreviousIOStallQueuedReadMS IS NULL) OR (a.PreviousSampleMS IS NULL) THEN NULL
							WHEN (a.PreviousIOStallQueuedReadMS > a.IOStallQueuedReadMS) OR (a.PreviousSampleMS > a.SampleMS) THEN a.IOStallQueuedReadMS
							ELSE a.IOStallQueuedReadMS - a.PreviousIOStallQueuedReadMS
						END AS DeltaIOStallQueuedReadMS
						,CASE
							WHEN (a.PreviousNumOfWrites IS NULL) OR (a.PreviousSampleMS IS NULL) THEN NULL
							WHEN (a.PreviousNumOfWrites > a.NumOfWrites) OR (a.PreviousSampleMS > a.SampleMS) THEN a.NumOfWrites
							ELSE a.NumOfWrites - a.PreviousNumOfWrites
						END AS DeltaNumOfWrites
						,CASE
							WHEN (a.PreviousNumOfBytesWritten IS NULL) OR (a.PreviousSampleMS IS NULL) THEN NULL
							WHEN (a.PreviousNumOfBytesWritten > a.NumOfBytesWritten) OR (a.PreviousSampleMS > a.SampleMS) THEN a.NumOfBytesWritten
							ELSE a.NumOfBytesWritten - a.PreviousNumOfBytesWritten
						END AS DeltaNumOfBytesWritten
						,CASE
							WHEN (a.PreviousIOStallWriteMS IS NULL) OR (a.PreviousSampleMS IS NULL) THEN NULL
							WHEN (a.PreviousIOStallWriteMS > a.IOStallWriteMS) OR (a.PreviousSampleMS > a.SampleMS) THEN a.IOStallWriteMS
							ELSE a.IOStallWriteMS - a.PreviousIOStallWriteMS
						END AS DeltaIOStallWriteMS
						,CASE
							WHEN (a.PreviousIOStallQueuedWriteMS IS NULL) OR (a.PreviousSampleMS IS NULL) THEN NULL
							WHEN (a.PreviousIOStallQueuedWriteMS > a.IOStallQueuedWriteMS) OR (a.PreviousSampleMS > a.SampleMS) THEN a.IOStallQueuedWriteMS
							ELSE a.IOStallQueuedWriteMS - a.PreviousIOStallQueuedWriteMS
						END AS DeltaIOStallQueuedWriteMS

						,a.Timestamp
						,a.DatabaseName
						,a.LogicalName
						,a.Type
			';
			SET @stmt += '
					FROM (
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
						SELECT
							dio.SampleMS
							,prevDio.SampleMS AS PreviousSampleMS

							,dio.IOStall
							,prevDio.IOStall AS PreviousIOStall

							,dio.NumOfReads
							,prevDio.NumOfReads AS PreviousNumOfReads

							,dio.NumOfBytesRead
							,prevDio.NumOfBytesRead AS PreviousNumOfBytesRead

							,dio.IOStallReadMS
							,prevDio.IOStallReadMS AS PreviousIOStallReadMS

							,dio.IOStallQueuedReadMS
							,prevDio.IOStallQueuedReadMS AS PreviousIOStallQueuedReadMS

							,dio.NumOfWrites
							,prevDio.NumOfWrites AS PreviousNumOfWrites

							,dio.NumOfBytesWritten
							,prevDio.NumOfBytesWritten AS PreviousNumOfBytesWritten

							,dio.IOStallWriteMS
							,prevDio.IOStallWriteMS AS PreviousIOStallWriteMS

							,dio.IOStallQueuedWriteMS
							,prevDio.IOStallQueuedWriteMS AS PreviousIOStallQueuedWriteMS

							,dio.Timestamp
							,dio.DatabaseName
							,dio.LogicalName
							,dio.Type
						FROM databaseIO AS dio
						LEFT OUTER JOIN databaseIO AS prevDio ON
							(prevDio.DatabaseName = dio.DatabaseName)
							AND (prevDio.LogicalName = dio.LogicalName)
							AND (prevDio.Type = dio.Type)
							AND (prevDio.Idx = dio.Idx - 1)
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
						SELECT
							dio.SampleMS
							,LAG(dio.SampleMS) OVER(PARTITION BY dio.DatabaseName, dio.LogicalName, dio.Type ORDER BY dio.TimestampUTC) AS PreviousSampleMS

							,dio.IOStall
							,LAG(dio.IOStall) OVER(PARTITION BY dio.DatabaseName, dio.LogicalName, dio.Type ORDER BY dio.TimestampUTC) AS PreviousIOStall

							,dio.NumOfReads
							,LAG(dio.NumOfReads) OVER(PARTITION BY dio.DatabaseName, dio.LogicalName, dio.Type ORDER BY dio.TimestampUTC) AS PreviousNumOfReads

							,dio.NumOfBytesRead
							,LAG(dio.NumOfBytesRead) OVER(PARTITION BY dio.DatabaseName, dio.LogicalName, dio.Type ORDER BY dio.TimestampUTC) AS PreviousNumOfBytesRead

							,dio.IOStallReadMS
							,LAG(dio.IOStallReadMS) OVER(PARTITION BY dio.DatabaseName, dio.LogicalName, dio.Type ORDER BY dio.TimestampUTC) AS PreviousIOStallReadMS

							,dio.IOStallQueuedReadMS
							,LAG(dio.IOStallQueuedReadMS) OVER(PARTITION BY dio.DatabaseName, dio.LogicalName, dio.Type ORDER BY dio.TimestampUTC) AS PreviousIOStallQueuedReadMS

							,dio.NumOfWrites
							,LAG(dio.NumOfWrites) OVER(PARTITION BY dio.DatabaseName, dio.LogicalName, dio.Type ORDER BY dio.TimestampUTC) AS PreviousNumOfWrites

							,dio.NumOfBytesWritten
							,LAG(dio.NumOfBytesWritten) OVER(PARTITION BY dio.DatabaseName, dio.LogicalName, dio.Type ORDER BY dio.TimestampUTC) AS PreviousNumOfBytesWritten

							,dio.IOStallWriteMS
							,LAG(dio.IOStallWriteMS) OVER(PARTITION BY dio.DatabaseName, dio.LogicalName, dio.Type ORDER BY dio.TimestampUTC) AS PreviousIOStallWriteMS

							,dio.IOStallQueuedWriteMS
							,LAG(dio.IOStallQueuedWriteMS) OVER(PARTITION BY dio.DatabaseName, dio.LogicalName, dio.Type ORDER BY dio.TimestampUTC) AS PreviousIOStallQueuedWriteMS

							,dio.Timestamp
							,dio.DatabaseName
							,dio.LogicalName
							,dio.Type
						FROM dbo.fhsmDatabaseIO AS dio
				';
			END;
			SET @stmt += '
					) AS a
				) AS b
			';
			SET @stmt += '
				WHERE
					(b.DeltaIOStall <> 0)
					OR (b.DeltaNumOfReads <> 0)
					OR (b.DeltaNumOfBytesRead <> 0)
					OR (b.DeltaIOStallReadMS <> 0)
					OR (b.DeltaIOStallQueuedReadMS <> 0)
					OR (b.DeltaNumOfWrites <> 0)
					OR (b.DeltaNumOfBytesWritten <> 0)
					OR (b.DeltaIOStallWriteMS <> 0)
					OR (b.DeltaIOStallQueuedWriteMS <> 0);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Database IO]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Database IO');
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
		-- Create stored procedure dbo.fhsmSPDatabaseIO
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPDatabaseIO'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPDatabaseIO AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPDatabaseIO (
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @database nvarchar(128);
					DECLARE @databases nvarchar(max);
					DECLARE @errorMsg nvarchar(max);
					DECLARE @ioStallQueuedReadMSStmt nvarchar(max);
					DECLARE @ioStallQueuedWriteMSStmt nvarchar(max);
					DECLARE @message nvarchar(max);
					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameters nvarchar(max);
					DECLARE @parametersTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
					DECLARE @replicaId uniqueidentifier;
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);

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
						-- Test if io_stall_queued_read_ms (and thereby also io_stall_queued_write_ms) exists on dm_io_virtual_file_stats
						--
						BEGIN
							IF EXISTS(
								SELECT *
								FROM master.sys.system_columns AS sc
								INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
								WHERE (so.name = ''dm_io_virtual_file_stats'') AND (sc.name = ''io_stall_queued_read_ms'')
							)
							BEGIN
								SET @ioStallQueuedReadMSStmt = ''divfs.io_stall_queued_read_ms'';
								SET @ioStallQueuedWriteMSStmt = ''divfs.io_stall_queued_write_ms'';
							END
							ELSE BEGIN
								SET @ioStallQueuedReadMSStmt = ''NULL'';
								SET @ioStallQueuedWriteMSStmt = ''NULL'';
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
								SET @stmt = ''
									USE '' + QUOTENAME(@database) + '';

									SELECT
										DB_NAME() AS DatabaseName
										,df.name, df.Type
										,divfs.sample_ms
										,divfs.io_stall
										,divfs.num_of_reads, divfs.num_of_bytes_read, divfs.io_stall_read_ms, '' + @ioStallQueuedReadMSStmt + ''
										,divfs.num_of_writes, divfs.num_of_bytes_written, divfs.io_stall_write_ms, '' + @ioStallQueuedWriteMSStmt + ''
										,divfs.size_on_disk_bytes
										,@nowUTC, @now
									FROM sys.dm_io_virtual_file_stats(DB_ID(), NULL) AS divfs
									INNER JOIN sys.database_files AS df WITH (NOLOCK) ON (divfs.file_id = df.file_id);
								'';
								BEGIN TRY
									INSERT INTO dbo.fhsmDatabaseIO(
										DatabaseName, LogicalName, Type
										,SampleMS, IOStall
										,NumOfReads, NumOfBytesRead, IOStallReadMS, IOStallQueuedReadMS
										,NumOfWrites, NumOfBytesWritten, IOStallWriteMS, IOStallQueuedWriteMS
										,SizeOnDiskBytes
										,TimestampUTC, Timestamp
									)
									EXEC sp_executesql
										@stmt
										,N''@now datetime, @nowUTC datetime''
										,@now = @now, @nowUTC = @nowUTC;
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

					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPDatabaseIO
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPDatabaseIO';
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
				,'dbo.fhsmDatabaseIO'
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
		schedules(Enabled, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters) AS(
			SELECT
				@enableDatabaseIO
				,'Database IO'
				,PARSENAME('dbo.fhsmSPDatabaseIO', 1)
				,15 * 60
				,CAST('1900-1-1T00:00:00.0000' AS datetime2(0))
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))
				,1, 1, 1, 1, 1, 1, 1
				,'@Databases = ''ALL_DATABASES'''
		)
		MERGE dbo.fhsmSchedules AS tgt
		USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
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
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmDatabaseIO' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL
				,'Database', NULL, NULL

			UNION ALL

			SELECT
				'Database file' AS DimensionName
				,'DatabaseFileKey' AS DimensionKey
				,'dbo.fhsmDatabaseIO' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[LogicalName]', 'CASE src.[Type] WHEN 0 THEN ''Data'' WHEN 1 THEN ''Log'' WHEN 2 THEN ''Filestream'' WHEN 4 THEN ''Fulltext'' ELSE ''Other'' END'
				,'Database name', 'Logical name', 'Type'
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
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmDatabaseIO';
	END;
END;
