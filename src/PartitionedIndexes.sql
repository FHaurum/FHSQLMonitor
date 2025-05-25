SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enablePartitionedIndexes bit;

	SET @enablePartitionedIndexes = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing PartitionedIndexes', 0, 1) WITH NOWAIT;
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
		SET @version = '2.6';

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
		-- Create table dbo.fhsmPartitionedIndexes and indexes if they not already exists
		--
		IF OBJECT_ID('dbo.fhsmPartitionedIndexes', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmPartitionedIndexes', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmPartitionedIndexes(
					Id int identity(1,1) NOT NULL
					,DatabaseName nvarchar(128) NOT NULL
					,SchemaName nvarchar(128) NOT NULL
					,ObjectName nvarchar(128) NOT NULL
					,IndexName nvarchar(128) NULL
					,IndexTypeDesc nvarchar(60) NOT NULL
					,PartitionSchemeName nvarchar(128) NOT NULL
					,PartitionFilegroupName nvarchar(128) NOT NULL
					,PartitionFunctionName nvarchar(128) NOT NULL
					,PartitionFunctionValueOnRight bit NOT NULL
					,PartitionFunctionCreateDate datetime NOT NULL
					,PartitionFunctionModifyDate datetime NOT NULL
					,PartitionBoundaryValue sql_variant NULL
					,PartitionColumn nvarchar(128) NOT NULL
					,PartitionNumber int NOT NULL
					,PartitionCompressionTypeDesc nvarchar(60) NOT NULL
					,PartitionRowCount bigint NOT NULL
					,TimestampUTC datetime NOT NULL
					,Timestamp datetime NOT NULL
					,CONSTRAINT PK_fhsmPartitionedIndexes PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmPartitionedIndexes')) AND (i.name = 'NC_fhsmPartitionedIndexes_TimestampUTC'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmPartitionedIndexes_TimestampUTC] to table dbo.fhsmPartitionedIndexes', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmPartitionedIndexes_TimestampUTC ON dbo.fhsmPartitionedIndexes(TimestampUTC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmPartitionedIndexes')) AND (i.name = 'NC_fhsmPartitionedIndexes_Timestamp'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmPartitionedIndexes_Timestamp] to table dbo.fhsmPartitionedIndexes', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmPartitionedIndexes_Timestamp ON dbo.fhsmPartitionedIndexes(Timestamp)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmPartitionedIndexes')) AND (i.name = 'NC_fhsmPartitionedIndexes_DatabaseName'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmPartitionedIndexes_DatabaseName] to table dbo.fhsmPartitionedIndexes', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmPartitionedIndexes_DatabaseName ON dbo.fhsmPartitionedIndexes(DatabaseName)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmPartitionedIndexes
		--
		BEGIN
			SET @objectName = 'dbo.fhsmPartitionedIndexes';
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
		-- Create fact view @pbiSchema.[Partitioned indexes]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Partitioned indexes') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Partitioned indexes') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Partitioned indexes') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
					WITH partitionedIndexes AS (
						SELECT
							pi.DatabaseName
							,pi.SchemaName 
							,pi.ObjectName
							,pi.IndexName
							,pi.IndexTypeDesc
							,pi.PartitionSchemeName
							,pi.PartitionFilegroupName
							,pi.PartitionFunctionName
							,pi.PartitionFunctionValueOnRight
							,pi.PartitionFunctionCreateDate
							,pi.PartitionFunctionModifyDate
							,pi.PartitionBoundaryValue
							,pi.PartitionColumn
							,pi.PartitionNumber
							,pi.PartitionCompressionTypeDesc
							,pi.PartitionRowCount
							,pi.Timestamp
							,ROW_NUMBER() OVER(PARTITION BY pi.TimestampUTC, pi.DatabaseName, pi.SchemaName, pi.ObjectName, pi.IndexName ORDER BY pi.PartitionNumber) AS Idx
						FROM dbo.fhsmPartitionedIndexes AS pi
						WHERE (pi.Timestamp IN (
							SELECT a.Timestamp
							FROM (
								SELECT
									pi2.Timestamp
									,ROW_NUMBER() OVER(PARTITION BY CAST(pi2.Timestamp AS date) ORDER BY pi2.Timestamp DESC) AS _Rnk_
								FROM dbo.fhsmPartitionedIndexes AS pi2
							) AS a
							WHERE (a._Rnk_ = 1)
						))
					)
				';
				SET @stmt += '
					SELECT
						pi.IndexTypeDesc
						,pi.PartitionSchemeName
						,pi.PartitionFilegroupName
						,pi.PartitionFunctionName
						,pi.PartitionFunctionValueOnRight
						,CASE 
							WHEN pi.PartitionFunctionValueOnRight = 0 
							THEN
								pi.PartitionColumn
								+ '' > ''
								+ CAST(ISNULL(lagPI.PartitionBoundaryValue, ''Infinity'') AS nvarchar)
								+ '' and ''
								+ pi.PartitionColumn
								+ '' <= ''
								+ CAST(ISNULL(pi.PartitionBoundaryValue, ''Infinity'') AS nvarchar) 
							ELSE
								pi.PartitionColumn
								+ '' >= ''
								+ CAST(ISNULL(pi.PartitionBoundaryValue, ''Infinity'') AS nvarchar)
								+ '' and ''
								+ pi.PartitionColumn
								+ '' < ''
								+ CAST(ISNULL(leadPI.PartitionBoundaryValue, ''Infinity'') AS nvarchar)
						END AS PartitionRange
						,ROW_NUMBER() OVER(ORDER BY pi.Timestamp DESC, pi.DatabaseName, pi.SchemaName, pi.ObjectName, pi.IndexName, CASE WHEN pi.PartitionFunctionValueOnRight = 0 THEN CASE WHEN pi.PartitionBoundaryValue IS NULL THEN 2 ELSE 1 END ELSE CASE WHEN pi.PartitionBoundaryValue IS NULL THEN 1 ELSE 2 END END, pi.PartitionBoundaryValue) AS SortOrder
						,pi.PartitionFunctionCreateDate
						,pi.PartitionFunctionModifyDate
						,pi.PartitionBoundaryValue
						,pi.PartitionColumn
						,pi.PartitionNumber
						,pi.PartitionCompressionTypeDesc
						,pi.PartitionRowCount
						,CAST(pi.Timestamp AS date) AS Date
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, DEFAULT,       DEFAULT,       DEFAULT,                          DEFAULT, DEFAULT) AS k) AS DatabaseKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.SchemaName, DEFAULT,       DEFAULT,                          DEFAULT, DEFAULT) AS k) AS SchemaKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.SchemaName, pi.ObjectName, DEFAULT,                          DEFAULT, DEFAULT) AS k) AS ObjectKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.SchemaName, pi.ObjectName, COALESCE(pi.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
					FROM partitionedIndexes AS pi
					LEFT OUTER JOIN partitionedIndexes AS lagPI ON
						(lagPI.Timestamp = pi.Timestamp)
						AND (lagPI.DatabaseName = pi.DatabaseName)
						AND (lagPI.SchemaName = pi.SchemaName)
						AND (lagPI.ObjectName = pi.ObjectName)
						AND ((lagPI.IndexName = pi.IndexName) OR ((lagPI.IndexName IS NULL) AND (pi.IndexName IS NULL)))
						AND (lagPI.Idx = pi.Idx - 1)
					LEFT OUTER JOIN partitionedIndexes AS leadPI ON
						(leadPI.Timestamp = pi.Timestamp)
						AND (leadPI.DatabaseName = pi.DatabaseName)
						AND (leadPI.SchemaName = pi.SchemaName)
						AND (leadPI.ObjectName = pi.ObjectName)
						AND ((leadPI.IndexName = pi.IndexName) OR ((leadPI.IndexName IS NULL) AND (pi.IndexName IS NULL)))
						AND (leadPI.Idx = pi.Idx + 1);
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
					SELECT
						pi.IndexTypeDesc
						,pi.PartitionSchemeName
						,pi.PartitionFilegroupName
						,pi.PartitionFunctionName
						,pi.PartitionFunctionValueOnRight
						,CASE 
							WHEN pi.PartitionFunctionValueOnRight = 0 
							THEN
								pi.PartitionColumn
								+ '' > ''
								+ CAST(ISNULL(LAG(pi.PartitionBoundaryValue) OVER(PARTITION BY pi.Timestamp, pi.DatabaseName, pi.SchemaName, pi.ObjectName, pi.IndexName ORDER BY pi.PartitionNumber), ''Infinity'') AS nvarchar)
								+ '' and ''
								+ pi.PartitionColumn
								+ '' <= ''
								+ CAST(ISNULL(pi.PartitionBoundaryValue, ''Infinity'') AS nvarchar) 
							ELSE
								pi.PartitionColumn
								+ '' >= ''
								+ CAST(ISNULL(pi.PartitionBoundaryValue, ''Infinity'') AS nvarchar)
								+ '' and ''
								+ pi.PartitionColumn
								+ '' < ''
								+ CAST(ISNULL(LEAD(pi.PartitionBoundaryValue) OVER(PARTITION BY pi.Timestamp, pi.DatabaseName, pi.SchemaName, pi.ObjectName, pi.IndexName ORDER BY pi.PartitionNumber), ''Infinity'') AS nvarchar)
						END AS PartitionRange
						,ROW_NUMBER() OVER(ORDER BY pi.Timestamp DESC, pi.DatabaseName, pi.SchemaName, pi.ObjectName, pi.IndexName, CASE WHEN pi.PartitionFunctionValueOnRight = 0 THEN CASE WHEN pi.PartitionBoundaryValue IS NULL THEN 2 ELSE 1 END ELSE CASE WHEN pi.PartitionBoundaryValue IS NULL THEN 1 ELSE 2 END END, pi.PartitionBoundaryValue) AS SortOrder
						,pi.PartitionFunctionCreateDate
						,pi.PartitionFunctionModifyDate
						,pi.PartitionBoundaryValue
						,pi.PartitionColumn
						,pi.PartitionNumber
						,pi.PartitionCompressionTypeDesc
						,pi.PartitionRowCount
						,CAST(pi.Timestamp AS date) AS Date
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, DEFAULT,       DEFAULT,       DEFAULT,                          DEFAULT, DEFAULT) AS k) AS DatabaseKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.SchemaName, DEFAULT,       DEFAULT,                          DEFAULT, DEFAULT) AS k) AS SchemaKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.SchemaName, pi.ObjectName, DEFAULT,                          DEFAULT, DEFAULT) AS k) AS ObjectKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(pi.DatabaseName, pi.SchemaName, pi.ObjectName, COALESCE(pi.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
					FROM dbo.fhsmPartitionedIndexes AS pi
					WHERE (pi.Timestamp IN (
						SELECT a.Timestamp
						FROM (
							SELECT
								pi2.Timestamp
								,ROW_NUMBER() OVER(PARTITION BY CAST(pi2.Timestamp AS date) ORDER BY pi2.Timestamp DESC) AS _Rnk_
							FROM dbo.fhsmPartitionedIndexes AS pi2
						) AS a
						WHERE (a._Rnk_ = 1)
					));
				';
			END;
			SET @stmt += '
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Partitioned indexes]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Partitioned indexes');
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
		-- Create stored procedure dbo.fhsmSPPartitionedIndexes
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPPartitionedIndexes'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPPartitionedIndexes AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPPartitionedIndexes (
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @database nvarchar(128);
					DECLARE @databases nvarchar(max);
					DECLARE @errorMsg nvarchar(max);
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
			';
			SET @stmt += '

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

						DECLARE dCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
						SELECT dl.DatabaseName, ' + CASE WHEN (@productVersion1 <= 10) THEN 'NULL' ELSE 'd.replica_id' END + ' AS replica_id
						FROM #dbList AS dl
						INNER JOIN sys.databases AS d ON (d.name COLLATE DATABASE_DEFAULT = dl.DatabaseName)
						ORDER BY dl.[Order];

						OPEN dCur;
			';
			SET @stmt += '

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
										,sch.name AS SchemaName
										,o.name AS ObjectName
										,i.name AS IndexName
										,i.type_desc AS IndexTypeDesc
										,ps.name AS PartitionSchemeName
										,ds.name AS PartitionFilegroupName
										,pf.name AS PartitionFunctionName
										,pf.boundary_value_on_right AS PartitionFunctionValueOnRight
										,pf.create_date AS PartitionFunctionCreateDate
										,pf.modify_date AS PartitionFunctionModifyDate
										,prv.value AS PartitionBoundaryValue
										,c.name AS PartitionColumn
										,pstats.partition_number AS PartitionNumber
										,p.data_compression_desc AS PartitionCompressionTypeDesc
										,pstats.row_count AS PartitionRowCount
										,@nowUTC, @now
									FROM sys.dm_db_partition_stats AS pstats
									INNER JOIN sys.objects AS o ON (o.object_id = pstats.object_id)
									INNER JOIN sys.schemas AS sch ON (sch.schema_id = o.schema_id)
									INNER JOIN sys.partitions AS p ON (p.partition_id = pstats.partition_id)
									INNER JOIN sys.destination_data_spaces AS dds ON (dds.destination_id = pstats.partition_number)
									INNER JOIN sys.data_spaces AS ds ON (ds.data_space_id = dds.data_space_id)
									INNER JOIN sys.partition_schemes AS ps ON (ps.data_space_id = dds.partition_scheme_id)
									INNER JOIN sys.partition_functions AS pf ON (pf.function_id = ps.function_id)
									INNER JOIN sys.indexes AS i ON (i.object_id = pstats.object_id) AND (i.index_id = pstats.index_id) AND (i.data_space_id = dds.partition_scheme_id)
									INNER JOIN sys.index_columns AS ic ON (ic.index_id = i.index_id) AND (ic.object_id = i.object_id) AND (ic.partition_ordinal > 0)
									INNER JOIN sys.columns AS c ON (c.object_id = ic.object_id) AND (c.column_id = ic.column_id)
									LEFT OUTER JOIN sys.partition_range_values AS prv ON (prv.function_id = pf.function_id) AND (pstats.partition_number = (CASE pf.boundary_value_on_right WHEN 0 THEN prv.boundary_id ELSE (prv.boundary_id + 1) END))
								'';
								BEGIN TRY
									INSERT INTO dbo.fhsmPartitionedIndexes(
										DatabaseName, SchemaName, ObjectName, IndexName, IndexTypeDesc
										,PartitionSchemeName
										,PartitionFilegroupName, PartitionFunctionName, PartitionFunctionValueOnRight, PartitionFunctionCreateDate, PartitionFunctionModifyDate, PartitionBoundaryValue, PartitionColumn
										,PartitionNumber, PartitionCompressionTypeDesc, PartitionRowCount
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
								EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Warning'', @message = @message;
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
		-- Register extended properties on the stored procedure dbo.fhsmSPPartitionedIndexes
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPPartitionedIndexes';
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
				,'dbo.fhsmPartitionedIndexes'
				,1
				,'TimestampUTC'
				,1
				,730
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
				@enablePartitionedIndexes
				,'Partitioned indexes'
				,PARSENAME('dbo.fhsmSPPartitionedIndexes', 1)
				,12 * 60 * 60
				,CAST('1900-1-1T23:00:00.0000' AS datetime2(0))
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))
				,1, 1, 1, 1, 1, 1, 1
				,'@Databases = ''USER_DATABASES, msdb'''
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
			,SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4, SrcColumn5
			,OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4, OutputColumn5
		) AS (
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmPartitionedIndexes' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL, NULL
				,'Database', NULL, NULL, NULL, NULL

			UNION ALL

			SELECT
				'Schema' AS DimensionName
				,'SchemaKey' AS DimensionKey
				,'dbo.fhsmPartitionedIndexes' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', NULL, NULL, NULL
				,'Database', 'Schema', NULL, NULL, NULL

			UNION ALL

			SELECT
				'Object' AS DimensionName
				,'ObjectKey' AS DimensionKey
				,'dbo.fhsmPartitionedIndexes' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', NULL, NULL
				,'Database', 'Schema', 'Object', NULL, NULL

			UNION ALL

			SELECT
				'Index' AS DimensionName
				,'IndexKey' AS DimensionKey
				,'dbo.fhsmPartitionedIndexes' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'COALESCE(src.[IndexName], ''N.A.'')', NULL
				,'Database', 'Schema', 'Object', 'Index', NULL
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
				,tgt.OutputColumn1 = src.OutputColumn1
				,tgt.OutputColumn2 = src.OutputColumn2
				,tgt.OutputColumn3 = src.OutputColumn3
				,tgt.OutputColumn4 = src.OutputColumn4
				,tgt.OutputColumn5 = src.OutputColumn5
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(
				DimensionName, DimensionKey
				,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
				,SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4, SrcColumn5
				,OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4, OutputColumn5
			)
			VALUES(
				src.DimensionName, src.DimensionKey
				,src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn
				,src.SrcColumn1, src.SrcColumn2, src.SrcColumn3, src.SrcColumn4, src.SrcColumn5
				,src.OutputColumn1, src.OutputColumn2, src.OutputColumn3, src.OutputColumn4, src.OutputColumn5
			);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmPartitionedIndexes';
	END;
END;
