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
	DECLARE @cnt int;
	DECLARE @edition nvarchar(128);
	DECLARE @msg nvarchar(max);
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
		SET @version = '2.11.0';

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
		-- Create table dbo.fhsmIndexUsage and indexes if they not already exists
		--
		BEGIN
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
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmIndexUsage')) AND (i.name = 'NC_fhsmIndexUsage_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmIndexUsage_TimestampUTC] to table dbo.fhsmIndexUsage', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmIndexUsage_TimestampUTC ON dbo.fhsmIndexUsage(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmIndexUsage')) AND (i.name = 'NC_fhsmIndexUsage_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmIndexUsage_Timestamp] to table dbo.fhsmIndexUsage', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmIndexUsage_Timestamp ON dbo.fhsmIndexUsage(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmIndexUsage')) AND (i.name = 'NC_fhsmIndexUsage_DatabaseName_SchemaName_ObjectName_IndexName'))
			BEGIN
				RAISERROR('Dropping index [NC_fhsmIndexUsage_DatabaseName_SchemaName_ObjectName_IndexName] on table dbo.fhsmIndexUsage', 0, 1) WITH NOWAIT;

				SET @stmt = '
					DROP INDEX NC_fhsmIndexUsage_DatabaseName_SchemaName_ObjectName_IndexName ON dbo.fhsmIndexUsage;
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmIndexUsage')) AND (i.name = 'NC_fhsmIndexUsage_DatabaseName_SchemaName_ObjectName_IndexName_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmIndexUsage_DatabaseName_SchemaName_ObjectName_IndexName_TimestampUTC] to table dbo.fhsmIndexUsage', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmIndexUsage_DatabaseName_SchemaName_ObjectName_IndexName_TimestampUTC ON dbo.fhsmIndexUsage(DatabaseName, SchemaName, ObjectName, IndexName, TimestampUTC)' + @tableCompressionStmt + ';
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
		-- Create table dbo.fhsmIndexUsageDelta and indexes if they not already exists
		--
		BEGIN
			IF OBJECT_ID('dbo.fhsmIndexUsageDelta', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmIndexUsageDelta', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmIndexUsageDelta(
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
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmIndexUsageDelta PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			--
			-- Processing data from dbo.fhsmIndexUsage into dbo.fhsmIndexUsageDelta, and before adding indexes
			--
			IF NOT EXISTS(SELECT * FROM dbo.fhsmIndexUsageDelta)
			BEGIN
				SET @cnt = (SELECT COUNT(*) FROM dbo.fhsmIndexUsage);
				RAISERROR('Processing data from dbo.fhsmIndexUsage into dbo.fhsmIndexUsageDelta', 0, 1) WITH NOWAIT;
				SET @msg = '!!! This might take some time if there are lots of data in the table dbo.fhsmIndexUsage. The table contains ' + CAST(@cnt AS nvarchar) + ' rows';
				RAISERROR(@msg, 0, 1) WITH NOWAIT;

				SET @stmt = '';

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
							,iu.TimestampUTC
							,iu.Timestamp
							,ROW_NUMBER() OVER(PARTITION BY iu.DatabaseName, iu.SchemaName, iu.ObjectName, iu.IndexName ORDER BY iu.TimestampUTC) AS Idx
						FROM dbo.fhsmIndexUsage AS iu
					)
					';
				END;
				SET @stmt += '
					INSERT INTO dbo.fhsmIndexUsageDelta(
						DatabaseName, SchemaName, ObjectName, IndexName
						,UserSeeks, UserScans, UserLookups, UserUpdates
						,LastUserSeek, LastUserScan, LastUserLookup, LastUserUpdate
						,TimestampUTC, Timestamp
					)
					SELECT
						b.DatabaseName
						,b.SchemaName
						,b.ObjectName
						,b.IndexName
						,b.DeltaUserSeeks AS UserSeeks
						,b.DeltaUserScans AS UserScans
						,b.DeltaUserLookups AS UserLookups
						,b.DeltaUserUpdates AS UserUpdates
						,b.LastUserSeek
						,b.LastUserScan
						,b.LastUserLookup
						,b.LastUserUpdate
						,b.TimestampUTC
						,b.Timestamp
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
							,a.TimestampUTC
							,a.Timestamp
							,a.DatabaseName
							,a.SchemaName
							,a.ObjectName
							,a.IndexName
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
								,iu.TimestampUTC
								,iu.Timestamp
								,iu.DatabaseName
								,iu.SchemaName
								,iu.ObjectName
								,iu.IndexName
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
								,iu.TimestampUTC
								,iu.Timestamp
								,iu.DatabaseName
								,iu.SchemaName
								,iu.ObjectName
								,iu.IndexName
							FROM dbo.fhsmIndexUsage AS iu
					';
				END;
				SET @stmt += '
						) AS a
					) AS b
					WHERE
						(b.DeltaUserSeeks <> 0)
						OR (b.DeltaUserScans <> 0)
						OR (b.DeltaUserLookups <> 0)
						OR (b.DeltaUserUpdates <> 0)
					ORDER BY b.TimestampUTC, b.DatabaseName, b.SchemaName, b.ObjectName, b.IndexName;
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmIndexUsageDelta')) AND (i.name = 'NC_fhsmIndexUsageDelta_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmIndexUsageDelta_TimestampUTC] to table dbo.fhsmIndexUsageDelta', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmIndexUsageDelta_TimestampUTC ON dbo.fhsmIndexUsageDelta(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmIndexUsageDelta')) AND (i.name = 'NC_fhsmIndexUsageDelta_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmIndexUsageDelta_Timestamp] to table dbo.fhsmIndexUsageDelta', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmIndexUsageDelta_Timestamp ON dbo.fhsmIndexUsageDelta(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmIndexUsageDelta')) AND (i.name = 'NC_fhsmIndexUsageDelta_DatabaseName_SchemaName_ObjectName_IndexName_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmIndexUsageDelta_DatabaseName_SchemaName_ObjectName_IndexName_TimestampUTC] to table dbo.fhsmIndexUsageDelta', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmIndexUsageDelta_DatabaseName_SchemaName_ObjectName_IndexName_TimestampUTC ON dbo.fhsmIndexUsageDelta(DatabaseName, SchemaName, ObjectName, IndexName, TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmIndexUsageDelta
			--
			BEGIN
				SET @objectName = 'dbo.fhsmIndexUsageDelta';
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
					CAST(COALESCE((tableIsHeap.IsHeap), 0) AS bit) AS TableIsHeap
					,CASE CAST(COALESCE((tableIsHeap.IsHeap), 0) AS bit)
						WHEN 0 THEN ''No''
						WHEN 1 THEN ''Yes''
						ELSE ''N.A.''
					END AS TableIsHeapTxt
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
					,iu.IsUnique
					,CASE iu.IsUnique
						WHEN 0 THEN ''No''
						WHEN 1 THEN ''Yes''
						ELSE ''N.A.''
					END AS IsUniqueTxt
					,iu.IsPrimaryKey
					,CASE iu.IsPrimaryKey
						WHEN 0 THEN ''No''
						WHEN 1 THEN ''Yes''
						ELSE ''N.A.''
					END AS IsPrimaryKeyTxt
					,iu.IsUniqueConstraint
					,CASE iu.IsUniqueConstraint
						WHEN 0 THEN ''No''
						WHEN 1 THEN ''Yes''
						ELSE ''N.A.''
					END AS IsUniqueConstraintTxt
					,iu.[FillFactor]
					,iu.IsDisabled
					,CASE iu.IsDisabled
						WHEN 0 THEN ''No''
						WHEN 1 THEN ''Yes''
						ELSE ''N.A.''
					END AS IsDisabledTxt
					,iu.IsHypothetical
					,CASE iu.IsHypothetical
						WHEN 0 THEN ''No''
						WHEN 1 THEN ''Yes''
						ELSE ''N.A.''
					END AS IsHypotheticalTxt
					,iu.AllowRowLocks
					,CASE iu.AllowRowLocks
						WHEN 0 THEN ''No''
						WHEN 1 THEN ''Yes''
						ELSE ''N.A.''
					END AS AllowRowLocksTxt
					,iu.AllowPageLocks
					,CASE iu.AllowPageLocks
						WHEN 0 THEN ''No''
						WHEN 1 THEN ''Yes''
						ELSE ''N.A.''
					END AS AllowPageLocksTxt
					,iu.HasFilter
					,CASE iu.HasFilter
						WHEN 0 THEN ''No''
						WHEN 1 THEN ''Yes''
						ELSE ''N.A.''
					END AS HasFilterTxt
					,iu.FilterDefinition
					,iu.AutoCreated
					,CASE iu.AutoCreated
						WHEN 0 THEN ''No''
						WHEN 1 THEN ''Yes''
						ELSE ''N.A.''
					END AS AutoCreatedTxt
					,iu.IndexColumns
					,iu.IncludedColumns
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, iu.SchemaName, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS SchemaKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, iu.SchemaName, iu.ObjectName, DEFAULT, DEFAULT, DEFAULT) AS k) AS ObjectKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iu.DatabaseName, iu.SchemaName, iu.ObjectName, COALESCE(iu.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
				FROM dbo.fhsmIndexUsage AS iu
				OUTER APPLY (
					SELECT 1 AS IsHeap
					FROM dbo.fhsmIndexUsage AS iuIsHeap
					WHERE (iuIsHeap.TimestampUTC = iu.TimestampUTC)
						AND (iuIsHeap.DatabaseName = iu.DatabaseName)
						AND (iuIsHeap.SchemaName = iu.SchemaName)
						AND (iuIsHeap.ObjectName = iu.ObjectName)
						AND (iuIsHeap.IndexType = 0)
				) AS tableIsHeap
				WHERE (iu.TimestampUTC = (
					SELECT MAX(iuLatest.TimestampUTC)
					FROM dbo.fhsmIndexUsage AS iuLatest
				));
			';
			EXEC(@stmt);

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
		END;

		--
		-- Create fact view @pbiSchema.[Index not used]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index not used') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index not used') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index not used') + '
				AS
				SELECT
					 (SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iuExists.DatabaseName, DEFAULT,             DEFAULT,             DEFAULT,            DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iuExists.DatabaseName, iuExists.SchemaName, DEFAULT,             DEFAULT,            DEFAULT, DEFAULT) AS k) AS SchemaKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iuExists.DatabaseName, iuExists.SchemaName, iuExists.ObjectName, DEFAULT,            DEFAULT, DEFAULT) AS k) AS ObjectKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iuExists.DatabaseName, iuExists.SchemaName, iuExists.ObjectName, iuExists.IndexName, DEFAULT, DEFAULT) AS k) AS IndexKey
				FROM (
					SELECT
						iu.DatabaseName
						,iu.SchemaName
						,iu.ObjectName
						,iu.IndexName
					FROM dbo.fhsmIndexUsage AS iu
					WHERE
						(iu.TimestampUTC = (
							SELECT MAX(iuLatest.TimestampUTC)
							FROM dbo.fhsmIndexUsage AS iuLatest
						))
						AND (iu.IndexName IS NOT NULL)
				) AS iuExists
				WHERE NOT EXISTS (
					SELECT *
					FROM dbo.fhsmIndexUsageDelta AS iud
					WHERE
						(iud.DatabaseName = iuExists.DatabaseName)
						AND (iud.SchemaName = iuExists.SchemaName)
						AND (iud.ObjectName = iuExists.ObjectName)
						AND (iud.IndexName = iuExists.IndexName)
				);
			';
			EXEC(@stmt);

			--
			-- Register extended properties on fact view @pbiSchema.[Index not used]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Index not used');
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
				SELECT
					iud.UserSeeks
					,iud.LastUserSeek
					,iud.UserScans
					,iud.LastUserScan
					,iud.UserLookups
					,iud.LastUserLookup
					,iud.UserUpdates
					,iud.LastUserUpdate
					,iud.Timestamp
					,CAST(iud.Timestamp AS date) AS Date
					,(DATEPART(HOUR, iud.Timestamp) * 60 * 60) + (DATEPART(MINUTE, iud.Timestamp) * 60) + (DATEPART(SECOND, iud.Timestamp)) AS TimeKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iud.DatabaseName, DEFAULT,        DEFAULT,        DEFAULT,                           DEFAULT, DEFAULT) AS k) AS DatabaseKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iud.DatabaseName, iud.SchemaName, DEFAULT,        DEFAULT,                           DEFAULT, DEFAULT) AS k) AS SchemaKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iud.DatabaseName, iud.SchemaName, iud.ObjectName, DEFAULT,                           DEFAULT, DEFAULT) AS k) AS ObjectKey
					,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(iud.DatabaseName, iud.SchemaName, iud.ObjectName, COALESCE(iud.IndexName, ''N.A.''), DEFAULT, DEFAULT) AS k) AS IndexKey
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
				INNER JOIN dbo.fhsmIndexUsageDelta AS iud
					ON (iud.DatabaseName = iuExists.DatabaseName)
					AND (iud.SchemaName = iuExists.SchemaName)
					AND (iud.ObjectName = iuExists.ObjectName)
					AND ((iud.IndexName = iuExists.IndexName) OR ((iud.IndexName IS NULL) AND (iuExists.IndexName IS NULL)));
			';
			EXEC(@stmt);

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
					DECLARE @errorMsg nvarchar(max);
					DECLARE @message nvarchar(max);
					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameter nvarchar(max);
					DECLARE @parameterTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
					DECLARE @prevTimestampUTC datetime;
					DECLARE @processingId int;
					DECLARE @processingTimestamp datetime;
					DECLARE @processingTimestampUTC datetime;
					DECLARE @replicaId uniqueidentifier;
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);
					SET @version = ''' + @version + ''';

					--
					-- Get the parameter for the command
					--
					BEGIN
						SET @parameter = dbo.fhsmFNGetTaskParameter(@thisTask, @name);

						INSERT INTO @parameterTable([Key], Value)
						SELECT
							(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 1)) AS [Key]
							,(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''='') AS s WHERE (s.Part = 2)) AS Value
						FROM dbo.fhsmFNSplitString(@parameter, '';'') AS p;

						SET @databases = (SELECT pt.Value FROM @parameterTable AS pt WHERE (pt.[Key] = ''@Databases''));

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
						-- Remember latest to be used as previous when loading data into dbo.fhsmIndexUsageDelta
						--
						SET @prevTimestampUTC = (
							SELECT MAX(iu.TimestampUTC)
							FROM dbo.fhsmIndexUsage AS iu
						);

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

						SET @message = ''Before loading data into dbo.fhsmIndexUsage'';
						EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;

						--
						-- Insert Processing record and remember the @id in the variable @processingId
						-- Type: 1: Loading data into dbo.fhsmIndexUsage
						--
						SET @processingId = NULL;
						SELECT
							@processingTimestampUTC = SYSUTCDATETIME()
							,@processingTimestamp = SYSDATETIME();
						EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = NULL, @type = 1, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

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
								BEGIN TRY
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

						--
						-- Update Processing record from before execution with @version, @processingTimestampUTC and @processingTimestamp
						-- Type: 1: Loading data into dbo.fhsmIndexUsage
						--
						SELECT
							@processingTimestampUTC = SYSUTCDATETIME()
							,@processingTimestamp = SYSDATETIME();
						EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = @version, @type = 1, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

						SET @message = ''After loading data into dbo.fhsmIndexUsage'';
						EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
	';
	SET @stmt += '
						--
						-- Process all new records in dbo.fhsmIndexUsage into dbo.fhsmIndexUsageDelta
						--
						BEGIN
							SET @message = ''Before loading data into dbo.fhsmIndexUsageDelta'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;

							--
							-- Insert Processing record and remember the @id in the variable @processingId
							-- Type: 2: Loading data into dbo.fhsmIndexUsageDelta
							--
							SET @processingId = NULL;
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = NULL, @type = 2, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							INSERT INTO dbo.fhsmIndexUsageDelta(
								DatabaseName, SchemaName, ObjectName, IndexName
								,UserSeeks, UserScans, UserLookups, UserUpdates
								,LastUserSeek, LastUserScan, LastUserLookup, LastUserUpdate
								,TimestampUTC, Timestamp
							)
							SELECT
								b.DatabaseName
								,b.SchemaName
								,b.ObjectName
								,b.IndexName
								,b.DeltaUserSeeks AS UserSeeks
								,b.DeltaUserScans AS UserScans
								,b.DeltaUserLookups AS UserLookups
								,b.DeltaUserUpdates AS UserUpdates
								,b.LastUserSeek
								,b.LastUserScan
								,b.LastUserLookup
								,b.LastUserUpdate
								,b.TimestampUTC
								,b.Timestamp
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
									,a.TimestampUTC
									,a.Timestamp
									,a.DatabaseName
									,a.SchemaName
									,a.ObjectName
									,a.IndexName
	';
	SET @stmt += '
								FROM (
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
										,iu.TimestampUTC
										,iu.Timestamp
										,iu.DatabaseName
										,iu.SchemaName
										,iu.ObjectName
										,iu.IndexName
									FROM (
										SELECT *
										FROM dbo.fhsmIndexUsage AS iu
										WHERE (iu.TimestampUTC = @nowUTC)
									) AS iu
									INNER JOIN (
										SELECT *
										FROM dbo.fhsmIndexUsage AS iu
										WHERE (iu.TimestampUTC = @prevTimestampUTC)
									) AS prevIU
										ON (prevIU.DatabaseName = iu.DatabaseName)
										AND (prevIU.SchemaName = iu.SchemaName)
										AND (prevIU.ObjectName = iu.ObjectName)
										AND ((prevIU.IndexName = iu.IndexName) OR ((prevIU.IndexName IS NULL) AND (iu.IndexName IS NULL)))
	';
	SET @stmt += '
								) AS a
							) AS b
							WHERE
								(b.DeltaUserSeeks <> 0)
								OR (b.DeltaUserScans <> 0)
								OR (b.DeltaUserLookups <> 0)
								OR (b.DeltaUserUpdates <> 0);

							--
							-- Update Processing record from before execution with @version, @processingTimestampUTC and @processingTimestamp
							-- Type: 2: Loading data into dbo.fhsmIndexUsageDelta
							--
							SELECT
								@processingTimestampUTC = SYSUTCDATETIME()
								,@processingTimestamp = SYSDATETIME();
							EXEC dbo.fhsmSPProcessing @name = @name, @task = @thisTask, @version = @version, @type = 2, @timestampUTC = @processingTimestampUTC, @timestamp = @processingTimestamp, @id = @processingId OUTPUT;

							SET @message = ''After loading data into dbo.fhsmIndexUsageDelta'';
							EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Debug'', @message = @message;
						END;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);

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
		-- Create stored procedure dbo.fhsmSPControlIndexUsage
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPControlIndexUsage'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPControlIndexUsage AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPControlIndexUsage (
					@Type nvarchar(16)
					,@Command nvarchar(16)
					,@Name nvarchar(128) = NULL
					,@Parameter nvarchar(max) = NULL
					,@Task nvarchar(128) = NULL
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @message nvarchar(max);
					DECLARE @parameterChanges TABLE(
						Action nvarchar(10),
						DeletedTask nvarchar(128),
						DeletedName nvarchar(128),
						DeletedParameter nvarchar(max),
						InsertedTask nvarchar(128),
						InsertedName nvarchar(128),
						InsertedParameter nvarchar(max)
					);
					DECLARE @thisTask nvarchar(128);
					DECLARE @version nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);
					SET @version = ''' + @version + ''';
			';
			SET @stmt += '
					IF (@Type = ''Parameter'')
					BEGIN
						IF (@Command = ''set'')
						BEGIN
							SET @Parameter = NULLIF(@Parameter, '''');

							IF NOT EXISTS (
								SELECT *
								FROM dbo.fhsmSchedules AS s
								WHERE (s.Task = @Task) AND (s.Name = @Name) AND (s.DeploymentStatus <> -1)
							)
							BEGIN
								SET @message = ''Invalid @Task:'''''' + COALESCE(NULLIF(@Task, ''''), ''<NULL>'') + '''''' and @Name:'''''' + COALESCE(NULLIF(@Name, ''''), ''<NULL>'') + '''''''';
								RAISERROR(@message, 0, 1) WITH NOWAIT;
								RETURN -11;
							END;

							--
							-- Register configuration changes
							--
							BEGIN
								WITH
								conf(Task, Name, Parameter) AS(
									SELECT
										@Task AS Task
										,@Name AS Name
										,@Parameter AS Parameter
								)
								MERGE dbo.fhsmSchedules AS tgt
								USING conf AS src ON (src.[Task] = tgt.[Task] COLLATE SQL_Latin1_General_CP1_CI_AS) AND (src.[Name] = tgt.[Name] COLLATE SQL_Latin1_General_CP1_CI_AS)
								-- Not testing for NULL as a NULL parameter is not allowed
								WHEN MATCHED AND (tgt.Parameter <> src.Parameter)
									THEN UPDATE
										SET tgt.Parameter = src.Parameter
								WHEN NOT MATCHED BY TARGET
									THEN INSERT(Task, Name, Parameter)
									VALUES(src.Task, src.Name, src.Parameter)
								OUTPUT
									$action,
									deleted.Task,
									deleted.Name,
									deleted.Parameter,
									inserted.Task,
									inserted.Name,
									inserted.Parameter
								INTO @parameterChanges;

								IF (@@ROWCOUNT <> 0)
								BEGIN
									SET @message = (
										SELECT ''Parameter is '''''' + COALESCE(src.InsertedParameter, ''<NULL>'') + '''''' - changed from '''''' + COALESCE(src.DeletedParameter, ''<NULL>'') + ''''''''
										FROM @parameterChanges AS src
									);
									IF (@message IS NOT NULL)
									BEGIN
										EXEC dbo.fhsmSPLog @name = @Name, @version = @version, @task = @thisTask, @type = ''Info'', @message = @message;
									END;
								END;
							END;
			';
			SET @stmt += '
						END
						ELSE BEGIN
							SET @message = ''Illegal Combination of @Type:'''''' + COALESCE(@Type, ''<NULL>'') + '''''' and @Command:'''''' + COALESCE(@Command, ''<NULL>'') + '''''''';
							RAISERROR(@message, 0, 1) WITH NOWAIT;
							RETURN -19;
						END;
					END
			';
			SET @stmt += '
					ELSE IF (@Type = ''Uninstall'')
					BEGIN
						--
						-- Place holder
						--
						SET @Type = @Type;
					END
			';
			SET @stmt += '
					ELSE BEGIN
						SET @message = ''Illegal @Type:'''''' + COALESCE(@Type, ''<NULL>'') + '''''''';
						RAISERROR(@message, 0, 1) WITH NOWAIT;
						RETURN -999;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPControlIndexUsage
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPControlIndexUsage';
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

		WITH
		retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter) AS(
			SELECT
				1
				,'dbo.fhsmIndexUsageDelta'
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
		schedules(Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameter) AS(
			SELECT
				@enableIndexUsage								AS Enabled
				,0												AS DeploymentStatus
				,'Index usage'									AS Name
				,PARSENAME('dbo.fhsmSPIndexUsage', 1)			AS Task
				,4 * 60 * 60									AS ExecutionDelaySec
				,CAST('1900-1-1T06:00:00.0000' AS datetime2(0))	AS FromTime
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))	AS ToTime
				,1, 1, 1, 1, 1, 1, 1							-- Monday..Sunday
				,'@Databases = ''USER_DATABASES, msdb'''		AS Parameter
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
