SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableMemory bit;
	DECLARE @ignoreAutoIndex bit;

	SET @enableMemory = 0;
	SET @ignoreAutoIndex = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing Memory', 0, 1) WITH NOWAIT;
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
		SET @version = '2.13.0';

		SET @productVersion = CAST(SERVERPROPERTY('ProductVersion') AS nvarchar);
		SET @productStartPos = 1;
		SET @productEndPos = CHARINDEX('.', @productVersion, @productStartPos);
		SET @productVersion1 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));
		SET @productStartPos = @productEndPos + 1;
		SET @productEndPos = CHARINDEX('.', @productVersion, @productStartPos);
		SET @productVersion2 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));
		SET @productStartPos = @productEndPos + 1;
		SET @productEndPos = CHARINDEX('.', @productVersion, @productStartPos);
		SET @productVersion3 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));
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
		-- Create table dbo.fhsmBufferDescriptions and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmBufferDescriptions', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmBufferDescriptions', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmBufferDescriptions(
						Id int identity(1,1) NOT NULL
						,DatabaseName nvarchar(128) NOT NULL
						,Cnt int NOT NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_BufferDescriptions PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmBufferDescriptions')) AND (i.name = 'NC_fhsmBufferDescriptions_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmBufferDescriptions_TimestampUTC] to table dbo.fhsmBufferDescriptions', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmBufferDescriptions_TimestampUTC ON dbo.fhsmBufferDescriptions(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmBufferDescriptions')) AND (i.name = 'NC_fhsmBufferDescriptions_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmBufferDescriptions_Timestamp] to table dbo.fhsmBufferDescriptions', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmBufferDescriptions_Timestamp ON dbo.fhsmBufferDescriptions(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmBufferDescriptions
			--
			BEGIN
				SET @objectName = 'dbo.fhsmBufferDescriptions';
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
		-- Create table dbo.fhsmMemoryClerks and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmMemoryClerks', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmMemoryClerks', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmMemoryClerks(
						Id int identity(1,1) NOT NULL
						,Type nvarchar(60) NOT NULL
						,PagesKB bigint NOT NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_MemoryClerks PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmMemoryClerks')) AND (i.name = 'NC_fhsmMemoryClerks_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmMemoryClerks_TimestampUTC] to table dbo.fhsmMemoryClerks', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmMemoryClerks_TimestampUTC ON dbo.fhsmMemoryClerks(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmMemoryClerks')) AND (i.name = 'NC_fhsmMemoryClerks_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmMemoryClerks_Timestamp] to table dbo.fhsmMemoryClerks', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmMemoryClerks_Timestamp ON dbo.fhsmMemoryClerks(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmMemoryClerks
			--
			BEGIN
				SET @objectName = 'dbo.fhsmMemoryClerks';
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
		-- Create fact view @pbiSchema.[Buffer pool usage]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Buffer pool usage') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Buffer pool usage') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Buffer pool usage') + '
				AS
				SELECT
					bd.Cnt * 8/1024.0 AS CachedSizeMB
					,CAST(bd.Timestamp AS date) AS Date
					,(DATEPART(HOUR, bd.Timestamp) * 60 * 60) + (DATEPART(MINUTE, bd.Timestamp) * 60) + (DATEPART(SECOND, bd.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(bd.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
				FROM dbo.fhsmBufferDescriptions AS bd;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Buffer pool usage]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Buffer pool usage');
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
		-- Create fact view @pbiSchema.[Memory clerks]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Memory clerks') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Memory clerks') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Memory clerks') + '
				AS
				SELECT
					mc.PagesKB
					,CAST(mc.Timestamp AS date) AS Date
					,(DATEPART(HOUR, mc.Timestamp) * 60 * 60) + (DATEPART(MINUTE, mc.Timestamp) * 60) + (DATEPART(SECOND, mc.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(mc.Type, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS MemoryClerkTypeKey
				FROM dbo.fhsmMemoryClerks AS mc
				WHERE (mc.Type IN (''MEMORYCLERK_SQLBUFFERPOOL'', ''MEMORYCLERK_SQLCONNECTIONPOOL'', ''OBJECTSTORE_LOCK_MANAGER''));
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Memory clerks]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Memory clerks');
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
		-- Create stored procedure dbo.fhsmSPMemory
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPMemory'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPMemory AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPMemory (
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

						INSERT INTO dbo.fhsmBufferDescriptions(DatabaseName, Cnt, TimestampUTC, Timestamp)
						SELECT
							DB_NAME(database_id) AS DatabaseName
							,COUNT(*) AS Cnt	--  Multiple with 8/1024.0 or divide by 128.0 to get it in MB
							,@nowUTC, @now
						FROM sys.dm_os_buffer_descriptors AS dobd WITH (NOLOCK)
						WHERE (dobd.database_id <> 32767) -- ResourceDB
						GROUP BY dobd.database_id;

						INSERT INTO dbo.fhsmMemoryClerks(Type, PagesKB, TimestampUTC, Timestamp)
						SELECT
							domc.type AS Type
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower
				SET @stmt += '
							,SUM(domc.single_pages_kb + domc.multi_pages_kb) AS PagesKB
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher
				SET @stmt += '
							,SUM(domc.pages_kb) AS PagesKB
				';
			END;
			SET @stmt += '
							,@nowUTC, @now
						FROM sys.dm_os_memory_clerks AS domc
						GROUP BY domc.type;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPMemory
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPMemory';
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
				,'dbo.fhsmBufferDescriptions'
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

		WITH
		retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter) AS(
			SELECT
				1
				,'dbo.fhsmMemoryClerks'
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
				@enableMemory									AS Enabled
				,0												AS DeploymentStatus
				,'Memory'									AS Name
				,PARSENAME('dbo.fhsmSPMemory', 1)				AS Task
				,60 * 60										AS ExecutionDelaySec
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
			,SrcColumn1, SrcColumn2, SrcColumn3
			,OutputColumn1, OutputColumn2, OutputColumn3
		) AS (
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmBufferDescriptions' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL
				,'Database', NULL, NULL

			UNION ALL

			SELECT
				'Memory clerk type' AS DimensionName
				,'MemoryClerkTypeKey' AS DimensionKey
				,'dbo.fhsmMemoryClerks' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[Type]', NULL, NULL
				,'Type', NULL, NULL
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
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmBufferDescriptions', @ignoreAutoIndex = @ignoreAutoIndex;
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmMemoryClerks', @ignoreAutoIndex = @ignoreAutoIndex;
	END;
END;
