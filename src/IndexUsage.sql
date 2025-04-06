SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableIndexUsage bit;

	SET @enableIndexUsage = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing IndexUsage', 0, 1) WITH NOWAIT;
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
		SET @version = '2.3';

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
	-- Variables used in view to control the statement output
	--
	BEGIN
		DECLARE @maxIndexColumnsLineLength int;
		DECLARE @maxIncludedColumnsLineLength int;

		SET @maxIndexColumnsLineLength = 40;
		SET @maxIncludedColumnsLineLength = 40;
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
		-- Create table dbo.fhsmIndexUsage if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmIndexUsage', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmIndexUsage', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmIndexUsage(
					Id int identity(1,1) NOT NULL
					,DatabaseName nvarchar(128) NOT NULL
					,SchemaName nvarchar(128) NOT NULL
					,ObjectName nvarchar(128) NOT NULL
					,IndexName nvarchar(128) NULL
					,UserSeeks bigint NULL
					,UserScans bigint NULL
					,UserLookups bigint NULL
					,UserUpdates bigint NULL
					,LastUserSeek datetime NULL
					,LastUserScan datetime NULL
					,LastUserLookup datetime NULL
					,LastUserUpdate datetime NULL
					,IndexType tinyint NOT NULL
					,IsUnique bit NOT NULL
					,IsPrimaryKey bit NOT NULL
					,IsUniqueConstraint bit NOT NULL
					,[FillFactor] tinyint NOT NULL
					,IsDisabled bit NOT NULL
					,IsHypothetical bit NOT NULL
					,AllowRowLocks bit NOT NULL
					,AllowPageLocks bit NOT NULL
					,HasFilter bit NOT NULL
					,FilterDefinition nvarchar(max) NULL
					,AutoCreated bit NULL
					,IndexColumns nvarchar(max) NULL
					,IncludedColumns nvarchar(max) NULL
					,LastSQLServiceRestart datetime NOT NULL
					,TimestampUTC datetime NOT NULL
					,Timestamp datetime NOT NULL
					,CONSTRAINT PK_fhsmIndexUsage PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);

				CREATE NONCLUSTERED INDEX NC_fhsmIndexUsage_TimestampUTC ON dbo.fhsmIndexUsage(TimestampUTC)' + @tableCompressionStmt + ';
				CREATE NONCLUSTERED INDEX NC_fhsmIndexUsage_Timestamp ON dbo.fhsmIndexUsage(Timestamp)' + @tableCompressionStmt + ';
				CREATE NONCLUSTERED INDEX NC_fhsmIndexUsage_DatabaseName_SchemaName_ObjectName_IndexName ON dbo.fhsmIndexUsage(DatabaseName, SchemaName, ObjectName, IndexName)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmIndexUsage
		--
		BEGIN
			SET @objectName = 'dbo.fhsmIndexUsage';
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
		-- Create fact view @pbiSchema.[Index configuration]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index configuration') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index configuration') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index configuration') + '
				AS
			';
			SET @stmt += '
				SELECT
					CAST(COALESCE((
						SELECT 1
						FROM dbo.fhsmIndexUsage AS iuIsHeap
						WHERE (iuIsHeap.TimestampUTC = iu.TimestampUTC)
							AND (iuIsHeap.DatabaseName = iu.DatabaseName)
							AND (iuIsHeap.SchemaName = iu.SchemaName)
							AND (iuIsHeap.ObjectName = iu.ObjectName)
							AND (iuIsHeap.IndexType = 0)
					), 0) AS bit) AS TableIsHeap
					,CASE iu.IndexType
						WHEN 0 THEN ''HEAP''
						WHEN 1 THEN ''CL''
						WHEN 2 THEN ''NCL''
						WHEN 3 THEN ''XML''
						WHEN 4 THEN ''Spatial''
						WHEN 5 THEN ''CL-COL''
						WHEN 6 THEN ''NCL-COL''
						WHEN 7 THEN ''NCL-HASH''
					END AS IndexTypeDesc
					,iu.IsUnique			+ 0 AS IsUnique
					,iu.IsPrimaryKey		+ 0 AS IsPrimaryKey
					,iu.IsUniqueConstraint	+ 0 AS IsUniqueConstraint
					,iu.[FillFactor]
					,iu.IsDisabled			+ 0 AS IsDisabled
					,iu.IsHypothetical		+ 0 AS IsHypothetical
					,iu.AllowRowLocks		+ 0 AS AllowRowLocks
					,iu.AllowPageLocks		+ 0 AS AllowPageLocks
					,iu.HasFilter			+ 0 AS HasFilter
					,iu.FilterDefinition
					,iu.AutoCreated			+ 0 AS AutoCreated
					,(dbo.fhsmFNSplitLines(iu.IndexColumns, ' + CAST(@maxIndexColumnsLineLength AS nvarchar) + ')) AS IndexColumns
					,(dbo.fhsmFNSplitLines(iu.IncludedColumns, ' + CAST(@maxIncludedColumnsLineLength AS nvarchar) + ')) AS IncludedColumns
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, iu.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, iu.SchemaName, iu.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, iu.SchemaName, iu.ObjectName, COALESCE(iu.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
				FROM dbo.fhsmIndexUsage AS iu
				WHERE (iu.TimestampUTC = (
					SELECT MAX(iuLatest.TimestampUTC)
					FROM dbo.fhsmIndexUsage AS iuLatest
				));
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Index configuration]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index configuration');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Index usage]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index usage') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index usage') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index usage') + '
				AS
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
				WITH indexUsage AS (
					SELECT
						iu.DatabaseName
						,iu.SchemaName
						,iu.ObjectName
						,iu.IndexName
						,iu.UserSeeks
						,iu.LastUserSeek
						,iu.UserScans
						,iu.LastUserScan
						,iu.UserLookups
						,iu.LastUserLookup
						,iu.UserUpdates
						,iu.LastUserUpdate
						,iu.LastSQLServiceRestart
						,iu.Timestamp
						,CAST(iu.Timestamp AS date) AS Date
						,ROW_NUMBER() OVER(PARTITION BY iu.DatabaseName, iu.SchemaName, iu.ObjectName, iu.IndexName ORDER BY iu.TimestampUTC) AS Idx
					FROM (
						SELECT
							iu.DatabaseName
							,iu.SchemaName
							,iu.ObjectName
							,iu.IndexName
						FROM dbo.fhsmIndexUsage AS iu
						WHERE (iu.TimestampUTC = (
							SELECT MAX(iuLatest.TimestampUTC)
							FROM dbo.fhsmIndexUsage AS iuLatest
						))
					) AS iuExists
					INNER JOIN dbo.fhsmIndexUsage AS iu ON
						(iu.DatabaseName = iuExists.DatabaseName)
						AND (iu.SchemaName = iuExists.SchemaName)
						AND (iu.ObjectName = iuExists.ObjectName)
						AND ((iu.IndexName = iuExists.IndexName) OR ((iu.IndexName IS NULL) AND (iuExists.IndexName IS NULL)))
				)
				';
			END;
			SET @stmt += '
				SELECT
					b.DeltaUserSeeks AS UserSeeks
					,b.LastUserSeek
					,b.DeltaUserScans AS UserScans
					,b.LastUserScan
					,b.DeltaUserLookups AS UserLookups
					,b.LastUserLookup
					,b.DeltaUserUpdates AS UserUpdates
					,b.LastUserUpdate
					,b.Timestamp
					,b.Date
					,b.TimeKey
					,b.DatabaseKey
					,b.SchemaKey
					,b.ObjectKey
					,b.IndexKey
				FROM (
			';
			SET @stmt += '
					SELECT
						CASE
							WHEN (a.PreviousUserSeeks IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL									-- Ignore 1. data set - Yes we loose one data set but better than having visuals showing very high data
							WHEN (a.PreviousUserSeeks > a.UserSeeks) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.UserSeeks	-- Either has the counters had an overflow or the server har been restarted
							ELSE a.UserSeeks - a.PreviousUserSeeks																						-- Difference
						END AS DeltaUserSeeks
						,a.LastUserSeek
						,CASE
							WHEN (a.PreviousUserScans IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousUserScans > a.UserScans) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.UserScans
							ELSE a.UserScans - a.PreviousUserScans
						END AS DeltaUserScans
						,a.LastUserScan
						,CASE
							WHEN (a.PreviousUserLookups IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousUserLookups > a.UserLookups) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.UserLookups
							ELSE a.UserLookups - a.PreviousUserLookups
						END AS DeltaUserLookups
						,a.LastUserLookup
						,CASE
							WHEN (a.PreviousUserUpdates IS NULL) OR (a.PreviousLastSQLServiceRestart IS NULL) THEN NULL
							WHEN (a.PreviousUserUpdates > a.UserUpdates) OR (a.PreviousLastSQLServiceRestart <> a.LastSQLServiceRestart) THEN a.UserUpdates
							ELSE a.UserUpdates - a.PreviousUserUpdates
						END AS DeltaUserUpdates
						,a.LastUserUpdate
						,a.Timestamp
						,a.Date
						,a.TimeKey
						,a.DatabaseKey
						,a.SchemaKey
						,a.ObjectKey
						,a.IndexKey
					FROM (
			';
			IF (@productVersion1 <= 10)
			BEGIN
				-- SQL Versions SQL2008R2 or lower

				SET @stmt += '
						SELECT
							iu.UserSeeks
							,prevIU.UserSeeks AS PreviousUserSeeks
							,iu.LastUserSeek
							,iu.UserScans
							,prevIU.UserScans AS PreviousUserScans
							,iu.LastUserScan
							,iu.UserLookups
							,prevIU.UserLookups AS PreviousUserLookups
							,iu.LastUserLookup
							,iu.UserUpdates
							,prevIU.UserUpdates AS PreviousUserUpdates
							,iu.LastUserUpdate
							,iu.LastSQLServiceRestart
							,prevIU.LastSQLServiceRestart AS PreviousLastSQLServiceRestart
							,iu.Timestamp
							,CAST(iu.Timestamp AS date) AS Date
							,(DATEPART(HOUR, iu.Timestamp) * 60 * 60) + (DATEPART(MINUTE, iu.Timestamp) * 60) + (DATEPART(SECOND, iu.Timestamp)) AS TimeKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, iu.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, iu.SchemaName, iu.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, iu.SchemaName, iu.ObjectName, COALESCE(iu.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
						FROM indexUsage AS iu
						LEFT OUTER JOIN indexUsage AS prevIU ON
							(prevIU.DatabaseName = iu.DatabaseName)
							AND (prevIU.SchemaName = iu.SchemaName)
							AND (prevIU.ObjectName = iu.ObjectName)
							AND ((prevIU.IndexName = iu.IndexName) OR ((prevIU.IndexName IS NULL) AND (iu.IndexName IS NULL)))
							AND (prevIU.Idx = iu.Idx - 1)
				';
			END
			ELSE BEGIN
				-- SQL Versions SQL2012 or higher

				SET @stmt += '
						SELECT
							iu.UserSeeks
							,LAG(iu.UserSeeks) OVER(PARTITION BY iu.DatabaseName, iu.SchemaName, iu.ObjectName, iu.IndexName ORDER BY iu.TimestampUTC) AS PreviousUserSeeks
							,iu.LastUserSeek
							,iu.UserScans
							,LAG(iu.UserScans) OVER(PARTITION BY iu.DatabaseName, iu.SchemaName, iu.ObjectName, iu.IndexName ORDER BY iu.TimestampUTC) AS PreviousUserScans
							,iu.LastUserScan
							,iu.UserLookups
							,LAG(iu.UserLookups) OVER(PARTITION BY iu.DatabaseName, iu.SchemaName, iu.ObjectName, iu.IndexName ORDER BY iu.TimestampUTC) AS PreviousUserLookups
							,iu.LastUserLookup
							,iu.UserUpdates
							,LAG(iu.UserUpdates) OVER(PARTITION BY iu.DatabaseName, iu.SchemaName, iu.ObjectName, iu.IndexName ORDER BY iu.TimestampUTC) AS PreviousUserUpdates
							,iu.LastUserUpdate
							,iu.LastSQLServiceRestart
							,LAG(iu.LastSQLServiceRestart) OVER(PARTITION BY iu.DatabaseName, iu.SchemaName, iu.ObjectName, iu.IndexName ORDER BY iu.TimestampUTC) AS PreviousLastSQLServiceRestart
							,iu.Timestamp
							,CAST(iu.Timestamp AS date) AS Date
							,(DATEPART(HOUR, iu.Timestamp) * 60 * 60) + (DATEPART(MINUTE, iu.Timestamp) * 60) + (DATEPART(SECOND, iu.Timestamp)) AS TimeKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, iu.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, iu.SchemaName, iu.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, iu.SchemaName, iu.ObjectName, COALESCE(iu.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
						FROM (
							SELECT
								iu.DatabaseName
								,iu.SchemaName
								,iu.ObjectName
								,iu.IndexName
							FROM dbo.fhsmIndexUsage AS iu
							WHERE (iu.TimestampUTC = (
								SELECT MAX(iuLatest.TimestampUTC)
								FROM dbo.fhsmIndexUsage AS iuLatest
							))
						) AS iuExists
						INNER JOIN dbo.fhsmIndexUsage AS iu ON
							(iu.DatabaseName = iuExists.DatabaseName)
							AND (iu.SchemaName = iuExists.SchemaName)
							AND (iu.ObjectName = iuExists.ObjectName)
							AND ((iu.IndexName = iuExists.IndexName) OR ((iu.IndexName IS NULL) AND (iuExists.IndexName IS NULL)))
				';
			END;
			SET @stmt += '
					) AS a
				) AS b
				WHERE
					(b.DeltaUserSeeks <> 0)
					OR (b.DeltaUserScans <> 0)
					OR (b.DeltaUserLookups <> 0)
					OR (b.DeltaUserUpdates <> 0);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Index usage]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index usage');
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
		-- Create stored procedure dbo.fhsmSPIndexUsage
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPIndexUsage'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPIndexUsage AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPIndexUsage (
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @autoCreatedStmt nvarchar(max);
					DECLARE @database nvarchar(128);
					DECLARE @databases nvarchar(max);
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

						--
						-- Test if auto_created exists on indexes
						--
						BEGIN
							IF EXISTS(
								SELECT *
								FROM master.sys.system_columns AS sc
								INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
								WHERE (so.name = ''indexes'') AND (sc.name = ''auto_created'')
							)
							BEGIN
								SET @autoCreatedStmt = ''i.auto_created'';
							END
							ELSE BEGIN
								SET @autoCreatedStmt = ''NULL'';
							END;
						END;

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
										,s.user_seeks AS UserSeeks
										,s.user_scans AS UserScans
										,s.user_lookups AS UserLookups
										,s.user_updates AS UserUpdates
										,s.last_user_seek AS LastUserSeek
										,s.last_user_scan AS LastUserScan
										,s.last_user_lookup AS LastUserLookup
										,s.last_user_update AS LastUserUpdate
										,i.type AS IndexType
										,i.is_unique AS IsUnique
										,i.is_primary_key AS IsPrimaryKey
										,i.is_unique_constraint AS IsUniqueConstraint
										,i.fill_factor AS [FillFactor]
										,i.is_disabled AS IsDisabled
										,i.is_hypothetical AS IsHypothetical
										,i.allow_row_locks AS AllowRowLocks
										,i.allow_page_locks AS AllowPageLocks
										,i.has_filter AS HasFilter
										,i.filter_definition AS FilterDefinition
										,'' + @autoCreatedStmt + '' AS AutoCreated
										,indexColumns.Columns AS IndexColumns
										,includedColumns.Columns AS IncludedColumns
										,(SELECT d.create_date FROM sys.databases AS d WITH (NOLOCK) WHERE (d.name = ''''tempdb'''')) AS LastSQLServiceRestart
										,@nowUTC, @now
									FROM sys.indexes AS i WITH (NOLOCK)
									LEFT OUTER JOIN sys.dm_db_index_usage_stats AS s WITH (NOLOCK) ON (s.database_id = DB_ID()) AND (s.object_id = i.object_id) AND (s.index_id = i.index_id)
									INNER JOIN sys.objects AS o WITH (NOLOCK) ON (o.object_id = i.object_id)
									INNER JOIN sys.schemas AS sch WITH (NOLOCK) ON (sch.schema_id = o.schema_id)
				';
				SET @stmt += '
									OUTER APPLY (
										SELECT STUFF((
											SELECT '''','''' + QUOTENAME(c.name) AS ColumnName
											FROM sys.index_columns AS ic WITH (NOLOCK)
											INNER JOIN sys.columns AS c WITH (NOLOCK) ON (c.object_id = ic.object_id) AND (c.column_id = ic.column_id)
											WHERE (ic.object_id = i.object_id) AND (ic.index_id = i.index_id)
												AND (ic.is_included_column = 0) AND (ic.key_ordinal <> 0)
											ORDER BY ic.key_ordinal
											FOR XML PATH (''''''''), type
										).value(''''.'''', ''''nvarchar(max)''''), 1, 1, '''''''') AS Columns
									) AS indexColumns
									OUTER APPLY (
										SELECT STUFF((
											SELECT '''','''' + QUOTENAME(c.name) AS ColumnName
											FROM sys.index_columns AS ic WITH (NOLOCK)
											INNER JOIN sys.columns AS c WITH (NOLOCK) ON (c.object_id = ic.object_id) AND (c.column_id = ic.column_id)
											WHERE (ic.object_id = i.object_id) AND (ic.index_id = i.index_id)
												AND (ic.is_included_column = 1)
											ORDER BY ic.key_ordinal
											FOR XML PATH (''''''''), type
										).value(''''.'''', ''''nvarchar(max)''''), 1, 1, '''''''') AS Columns
									) AS includedColumns
									WHERE (o.type IN (''''U'''', ''''V''''))
								'';
								INSERT INTO dbo.fhsmIndexUsage(
									DatabaseName, SchemaName, ObjectName, IndexName
									,UserSeeks, UserScans, UserLookups, UserUpdates
									,LastUserSeek, LastUserScan, LastUserLookup, LastUserUpdate
									,IndexType, IsUnique, IsPrimaryKey, IsUniqueConstraint
									,[FillFactor]
									,IsDisabled, IsHypothetical
									,AllowRowLocks, AllowPageLocks
									,HasFilter, FilterDefinition
									,AutoCreated
									,IndexColumns, IncludedColumns
									,LastSQLServiceRestart
									,TimestampUTC, Timestamp
								)
								EXEC sp_executesql
									@stmt
									,N''@now datetime, @nowUTC datetime''
									,@now = @now, @nowUTC = @nowUTC;
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
		-- Register extended properties on the stored procedure dbo.fhsmSPIndexUsage
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPIndexUsage';
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
				,'dbo.fhsmIndexUsage'
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
				@enableIndexUsage
				,'Index usage'
				,PARSENAME('dbo.fhsmSPIndexUsage', 1)
				,4 * 60 * 60
				,CAST('1900-1-1T06:00:00.0000' AS datetime2(0))
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
			,SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4
			,OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4
		) AS (
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmIndexUsage' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL
				,'Database', NULL, NULL, NULL

			UNION ALL

			SELECT
				'Schema' AS DimensionName
				,'SchemaKey' AS DimensionKey
				,'dbo.fhsmIndexUsage' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', NULL, NULL
				,'Database', 'Schema', NULL, NULL

			UNION ALL

			SELECT
				'Object' AS DimensionName
				,'ObjectKey' AS DimensionKey
				,'dbo.fhsmIndexUsage' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', NULL
				,'Database', 'Schema', 'Object', NULL

			UNION ALL

			SELECT
				'Index' AS DimensionName
				,'IndexKey' AS DimensionKey
				,'dbo.fhsmIndexUsage' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', 'COALESCE(src.[IndexName], ''N.A.'')'
				,'Database', 'Schema', 'Object', 'Index'
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
				,tgt.OutputColumn1 = src.OutputColumn1
				,tgt.OutputColumn2 = src.OutputColumn2
				,tgt.OutputColumn3 = src.OutputColumn3
				,tgt.OutputColumn4 = src.OutputColumn4
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(
				DimensionName, DimensionKey
				,SrcTable, SrcAlias, SrcWhere, SrcDateColumn
				,SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4
				,OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4
			)
			VALUES(
				src.DimensionName, src.DimensionKey
				,src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn
				,src.SrcColumn1, src.SrcColumn2, src.SrcColumn3, src.SrcColumn4
				,src.OutputColumn1, src.OutputColumn2, src.OutputColumn3, src.OutputColumn4
			);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmIndexUsage';
	END;
END;
