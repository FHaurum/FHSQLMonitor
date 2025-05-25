SET NOCOUNT ON;

--
-- Default installations parameters
--
BEGIN
	DECLARE @createSQLAgentJob bit;
	DECLARE @fhSQLMonitorDatabase nvarchar(128);
	DECLARE @pbiSchema nvarchar(128);

	SET @createSQLAgentJob = 1;
	SET @fhSQLMonitorDatabase = 'FHSQLMonitor';
	SET @pbiSchema = 'FHSM';
END;

--
-- No need to change more from here on
--

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing FHSQLMonitor main', 0, 1) WITH NOWAIT;
END;

--
-- Declare variables
--
BEGIN
	DECLARE @myUserName nvarchar(128);
	DECLARE @nowUTC datetime;
	DECLARE @nowUTCStr nvarchar(128);
	DECLARE @objectName nvarchar(128);
	DECLARE @stmt nvarchar(max);
	DECLARE @tableCompressionStmt nvarchar(max);
	DECLARE @version nvarchar(128);

	SET @myUserName = SUSER_NAME();
	SET @nowUTC = SYSUTCDATETIME();
	SET @nowUTCStr = CONVERT(nvarchar(128), @nowUTC, 126);
	SET @version = '2.6.0';
END;

--
-- Only execute if we are in the master database
--
IF NOT ((SELECT DB_NAME()) = 'master')
BEGIN
	RAISERROR('Can not install as current database is not ''master''', 0, 1) WITH NOWAIT;
END
ELSE BEGIN
	--
	-- Create database if it not already exists
	--
	IF NOT EXISTS (SELECT * FROM sys.databases AS d WHERE (d.name = @fhSQLMonitorDatabase))
	BEGIN
		SET @stmt = '
			RAISERROR(''Creating database ' + @fhSQLMonitorDatabase + ''', 0, 1) WITH NOWAIT;

			CREATE DATABASE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
		';
		EXEC(@stmt);

		SET @stmt = '
			RAISERROR(''Changing database ' + @fhSQLMonitorDatabase + ' to simple recovery mode'', 0, 1) WITH NOWAIT;

			ALTER DATABASE ' + QUOTENAME(@fhSQLMonitorDatabase) + ' SET RECOVERY SIMPLE;
		';
		EXEC(@stmt);
	END;

	--
	-- Create or alter stored procedure dbo.fhsmSPExtendedProperties
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmSPExtendedProperties'', ''P'') IS NULL
			BEGIN
				RAISERROR(''Creating stub stored procedure dbo.fhsmSPExtendedProperties'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE PROC dbo.fhsmSPExtendedProperties AS SELECT ''''dummy'''' AS Txt'');
			END;

			--
			-- Alter dbo.fhsmSPExtendedProperties
			--
			BEGIN
				RAISERROR(''Alter stored procedure dbo.fhsmSPExtendedProperties'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER PROC dbo.fhsmSPExtendedProperties(
						@objectType nvarchar(128)
						,@updateIfExists bit
						,@propertyName nvarchar(128)
						,@propertyValue sql_variant
						,@level0name nvarchar(128) = NULL
						,@level1name nvarchar(128) = NULL
					)
					AS
					BEGIN
						SET NOCOUNT ON;

						DECLARE @message nvarchar(max);

						IF (@objectType = ''''Database'''')
						BEGIN
							IF NOT EXISTS (
								SELECT *
								FROM sys.extended_properties AS ep
								WHERE (ep.class = 0) AND (ep.name = @propertyName)
							)
							BEGIN
								EXEC sys.sp_addextendedproperty @name = @propertyName, @value = @propertyValue;
							END
							ELSE BEGIN
								IF (@updateIfExists = 1)
								BEGIN
									EXEC sys.sp_updateextendedproperty @name = @propertyName, @value = @propertyValue;
								END;
							END;
						END
						ELSE IF (@objectType = ''''Schema'''')
						BEGIN
							IF NOT EXISTS (
								SELECT *
								FROM sys.extended_properties AS ep
								WHERE (ep.class = 3) AND (ep.major_id = SCHEMA_ID(@level0name)) AND (ep.name = @propertyName)
							)
							BEGIN
								EXEC sys.sp_addextendedproperty @name = @propertyName, @level0type = ''''SCHEMA'''', @level0name = @level0name, @value = @propertyValue;
							END
							ELSE BEGIN
								IF (@updateIfExists = 1)
								BEGIN
									EXEC sys.sp_updateextendedproperty @name = @propertyName, @level0type = ''''SCHEMA'''', @level0name = @level0name, @value = @propertyValue;
								END;
							END;
						END
						ELSE IF (@objectType IN (''''Table'''', ''''View'''', ''''Function'''', ''''Procedure''''))
						BEGIN
							SET @objectType = UPPER(@objectType);

							IF NOT EXISTS (
								SELECT *
								FROM sys.extended_properties AS ep
								WHERE (ep.class = 1) AND (ep.major_id = OBJECT_ID(QUOTENAME(@level0name) + ''''.'''' + QUOTENAME(@level1name))) AND (ep.name = @propertyName)
							)
							BEGIN
								EXEC sys.sp_addextendedproperty @name = @propertyName, @level0type = ''''SCHEMA'''', @level0name = @level0name, @level1type = @objectType, @level1name = @level1name, @value = @propertyValue;
							END
							ELSE BEGIN
								IF (@updateIfExists = 1)
								BEGIN
									EXEC sys.sp_updateextendedproperty @name = @propertyName, @level0type = ''''SCHEMA'''', @level0name = @level0name, @level1type = @objectType, @level1name = @level1name, @value = @propertyValue;
								END;
							END;
						END
						ELSE BEGIN
							SET @message = ''''Unknown object type - '''''''''''' + @objectType + '''''''''''''''';
							PRINT @message;

							RETURN -1;
						END;

						RETURN 0;
					END;
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the stored procedure dbo.fhsmSPExtendedProperties
	--
	BEGIN
		SET @objectName = 'dbo.fhsmSPExtendedProperties';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Register extended properties on the database
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Database'', @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Database'', @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Database'', @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Database'', @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Database'', @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create 'PBI' schema if it not already exists
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);
			IF (SCHEMA_ID(''' + @pbiSchema + ''') IS NULL)
			BEGIN
				SET @stmt = ''CREATE SCHEMA ' + QUOTENAME(@pbiSchema) + ';'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the 'PBI' schema
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Schema'', @level0name = @pbiSchema, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Schema'', @level0name = @pbiSchema, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Schema'', @level0name = @pbiSchema, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Schema'', @level0name = @pbiSchema, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Schema'', @level0name = @pbiSchema, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@pbiSchema nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@pbiSchema = @pbiSchema
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create or alter function dbo.fhsmFNParseDimensionColumn
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmFNParseDimensionColumn'', ''FN'') IS NULL
			BEGIN
				RAISERROR(''Creating stub function dbo.fhsmFNParseDimensionColumn'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE FUNCTION dbo.fhsmFNParseDimensionColumn() RETURNS nvarchar(128) AS BEGIN RETURN NULL; END;'');
			END;

			--
			-- Alter dbo.fhsmFNParseDimensionColumn
			--
			BEGIN
				RAISERROR(''Alter function dbo.fhsmFNParseDimensionColumn'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER FUNCTION dbo.fhsmFNParseDimensionColumn(@column nvarchar(128))
					RETURNS nvarchar(128)
					AS
					BEGIN
						DECLARE @pos1 int;
						DECLARE @pos2 int;
						DECLARE @token nvarchar(128);

						SET @token = ''''CASE '''';
						IF (LEFT(@column, LEN(@token)) = @token)
						BEGIN
							SET @pos1 = CHARINDEX('''' '''', @column);
							SET @pos2 = CHARINDEX('''' '''', @column, @pos1 + 1);

							SET @column = SUBSTRING(@column, @pos1 + 1, @pos2 - @pos1 - 1);
						END;

						SET @token = ''''CAST('''';
						IF (LEFT(@column, LEN(@token)) = @token)
						BEGIN
							SET @pos1 = CHARINDEX('''' '''', @column);

							SET @column = SUBSTRING(@column, LEN(@token) + 1, @pos1 - LEN(@token) - 1);
						END;

						SET @token = ''''COALESCE('''';
						IF (LEFT(@column, LEN(@token)) = @token)
						BEGIN
							SET @pos1 = CHARINDEX('''','''', @column);

							SET @column = SUBSTRING(@column, LEN(@token) + 1, @pos1 - LEN(@token) - 1);
						END;

						SET @token = ''''CONVERT('''';
						IF (LEFT(@column, LEN(@token)) = @token)
						BEGIN
							SET @pos1 = CHARINDEX('''','''', @column);
							SET @pos2 = CHARINDEX('''','''', @column, @pos1 + 1);

							SET @column = SUBSTRING(@column, @pos1 + 1, @pos2 - @pos1 - 1);
						END;

						SET @column = LTRIM(RTRIM(@column));

						RETURN @column;
					END;
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the function dbo.fhsmFNParseDimensionColumn
	--
	BEGIN
		SET @objectName = 'dbo.fhsmFNParseDimensionColumn';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create or alter function dbo.fhsmFNTryParseAsInt
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmFNTryParseAsInt'', ''FN'') IS NULL
			BEGIN
				RAISERROR(''Creating stub function dbo.fhsmFNTryParseAsInt'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE FUNCTION dbo.fhsmFNTryParseAsInt() RETURNS int AS BEGIN RETURN NULL; END;'');
			END;

			--
			-- Alter dbo.fhsmFNTryParseAsInt
			--
			BEGIN
				RAISERROR(''Alter function dbo.fhsmFNTryParseAsInt'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER FUNCTION dbo.fhsmFNTryParseAsInt(@str nvarchar(128))
					RETURNS int
					AS
					BEGIN
						DECLARE @i int;
						DECLARE @chkFlg bit;
						DECLARE @retVal int;

						SET @chkFlg = 0;

						SET @str = LTRIM(RTRIM(@str));

						IF (@str IS NOT NULL)
						BEGIN
							IF (LEN(@str) > 0)
							BEGIN
								SET @i = 1;

								WHILE (@i <= LEN(@str))
								BEGIN
									IF NOT (SUBSTRING(@str, @i, 1) LIKE ''''[0-9]'''')
									BEGIN
										BREAK;
									END;

									SET @i += 1;

									IF (@i > LEN(@str))
									BEGIN
										SET @chkFlg = 1;
									END;
								END;
							END;
						END;

						IF (@chkFlg = 0)
						BEGIN
							SET @retVal = NULL;
						END
						ELSE BEGIN
							SET @retVal = CAST(@str AS int);
						END;

						RETURN @retVal;
					END;
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the function dbo.fhsmFNTryParseAsInt
	--
	BEGIN
		SET @objectName = 'dbo.fhsmFNTryParseAsInt';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Check if SQL version allows to use data compression
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @edition nvarchar(128);
			DECLARE @productEndPos int;
			DECLARE @productStartPos int;
			DECLARE @productVersion nvarchar(128);
			DECLARE @productVersion1 int;
			DECLARE @productVersion2 int;
			DECLARE @productVersion3 int;

			SET @tableCompressionStmt = '''';

			SET @edition = CAST(SERVERPROPERTY(''Edition'') AS nvarchar);

			SET @productVersion = CAST(SERVERPROPERTY(''ProductVersion'') AS nvarchar);

			SET @productStartPos = 1;
			SET @productEndPos = CHARINDEX(''.'', CAST(@productVersion AS nvarchar(128)) COLLATE DATABASE_DEFAULT, @productStartPos);
			SET @productVersion1 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));

			SET @productStartPos = @productEndPos + 1;
			SET @productEndPos = CHARINDEX(''.'', CAST(@productVersion AS nvarchar(128)) COLLATE DATABASE_DEFAULT, @productStartPos);
			SET @productVersion2 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));

			SET @productStartPos = @productEndPos + 1;
			SET @productEndPos = CHARINDEX(''.'', CAST(@productVersion AS nvarchar(128)) COLLATE DATABASE_DEFAULT, @productStartPos);
			SET @productVersion3 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));

			IF (CAST(@edition AS nvarchar(128)) COLLATE DATABASE_DEFAULT = ''SQL Azure'')
				OR (SUBSTRING(CAST(@edition AS nvarchar(128)) COLLATE DATABASE_DEFAULT, 1, CHARINDEX('' '', CAST(@edition AS nvarchar(128)) COLLATE DATABASE_DEFAULT)) = ''Developer'')
				OR (SUBSTRING(CAST(@edition AS nvarchar(128)) COLLATE DATABASE_DEFAULT, 1, CHARINDEX('' '', CAST(@edition AS nvarchar(128)) COLLATE DATABASE_DEFAULT)) = ''Enterprise'')
				OR (@productVersion1 > 13)
				OR ((@productVersion1 = 13) AND (@productVersion2 >= 1))
				OR ((@productVersion1 = 13) AND (@productVersion2 = 0) AND (@productVersion3 >= 4001))
			BEGIN
				SET @tableCompressionStmt = '' WITH (DATA_COMPRESSION = PAGE)'';
			END;
		';
		EXEC sp_executesql
			@stmt
			,N'@tableCompressionStmt nvarchar(max) OUTPUT'
			,@tableCompressionStmt = @tableCompressionStmt OUTPUT;
	END;

	--
	-- Create table dbo.fhsmConfigurations and indexes if they not already exists
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			IF OBJECT_ID(''dbo.fhsmConfigurations'', ''U'') IS NULL
			BEGIN
				RAISERROR(''Creating table dbo.fhsmConfigurations'', 0, 1) WITH NOWAIT;

				CREATE TABLE dbo.fhsmConfigurations(
					Id int identity(1,1) NOT NULL
					,[Key] nvarchar(128) NOT NULL
					,Value nvarchar(128) NOT NULL
					,CONSTRAINT PK_fhsmConfigurations PRIMARY KEY([Key])' + @tableCompressionStmt + '
				);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID(''dbo.fhsmConfigurations'')) AND (i.name = ''NC_fhsmConfigurations_Id''))
			BEGIN
				CREATE NONCLUSTERED INDEX NC_fhsmConfigurations_Id ON dbo.fhsmConfigurations(Id)' + @tableCompressionStmt + ';
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the table dbo.fhsmConfigurations
	--
	BEGIN
		SET @objectName = 'dbo.fhsmConfigurations';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Save installation data dbo.fhsmConfigurations
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			WITH
			cfg([Key], Value) AS(
				SELECT
					''PBISchema''
					,''' + @pbiSchema + '''
			)
			MERGE dbo.fhsmConfigurations AS tgt
			USING cfg AS src ON (src.[Key] = tgt.[Key])
			WHEN MATCHED
				THEN UPDATE
					SET tgt.Value = src.Value
			WHEN NOT MATCHED BY TARGET
				THEN INSERT([Key], Value)
				VALUES(src.[Key], src.Value);

			WITH
			cfg([Key], Value) AS(
				SELECT
					''Version''
					,''' + CAST(@version AS nvarchar) + '''
			)
			MERGE dbo.fhsmConfigurations AS tgt
			USING cfg AS src ON (src.[Key] = tgt.[Key])
			WHEN MATCHED
				THEN UPDATE
					SET tgt.Value = src.Value
			WHEN NOT MATCHED BY TARGET
				THEN INSERT([Key], Value)
				VALUES(src.[Key], src.Value);
		';
		EXEC(@stmt);
	END;

	--
	-- Create table dbo.fhsmDimensions if it not already exists
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			IF OBJECT_ID(''dbo.fhsmDimensions'', ''U'') IS NULL
			BEGIN
				RAISERROR(''Creating table dbo.fhsmDimensions'', 0, 1) WITH NOWAIT;

				CREATE TABLE dbo.fhsmDimensions(
					Id int identity(1,1) NOT NULL
					,DimensionName nvarchar(128) NOT NULL
					,DimensionKey nvarchar(128) NOT NULL
					,SrcTable nvarchar(128) NOT NULL
					,SrcAlias nvarchar(128) NOT NULL
					,SrcWhere nvarchar(max) NULL
					,SrcDateColumn nvarchar(128) NOT NULL
					,SrcColumn1 nvarchar(128) NOT NULL
					,SrcColumn2 nvarchar(128) NULL
					,SrcColumn3 nvarchar(128) NULL
					,SrcColumn4 nvarchar(128) NULL
					,SrcColumn5 nvarchar(128) NULL
					,SrcColumn6 nvarchar(128) NULL
					,OutputColumn1 nvarchar(128) NOT NULL
					,OutputColumn2 nvarchar(128) NULL
					,OutputColumn3 nvarchar(128) NULL
					,OutputColumn4 nvarchar(128) NULL
					,OutputColumn5 nvarchar(128) NULL
					,OutputColumn6 nvarchar(128) NULL
					,CONSTRAINT PK_fhsmDimensions PRIMARY KEY(Id)' + @tableCompressionStmt + '
					,CONSTRAINT UQ_fhsmDimensions_SrcTable_DimensionName UNIQUE(SrcTable, DimensionName)' + @tableCompressionStmt + '
				);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the table dbo.fhsmDimensions
	--
	BEGIN
		SET @objectName = 'dbo.fhsmDimensions';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create table dbo.fhsmRetentions and indexes if they not already exists
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			IF OBJECT_ID(''dbo.fhsmRetentions'', ''U'') IS NULL
			BEGIN
				RAISERROR(''Creating table dbo.fhsmRetentions'', 0, 1) WITH NOWAIT;

				CREATE TABLE dbo.fhsmRetentions(
					Id int identity(1,1) NOT NULL
					,Enabled bit NOT NULL
					,TableName nvarchar(128) NOT NULL
					,Sequence tinyint NOT NULL
					,TimeColumn nvarchar(128) NOT NULL
					,IsUtc bit NOT NULL
					,Days int NOT NULL
					,Filter nvarchar(max) NULL
					,LastStartedUTC datetime NULL
					,LastExecutedUTC datetime NULL
					,CONSTRAINT PK_fhsmRetentions PRIMARY KEY(Id)' + @tableCompressionStmt + '
					,CONSTRAINT UQ_fhsmRetentions_TableName_Sequence UNIQUE(TableName, Sequence)' + @tableCompressionStmt + '
				);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID(''dbo.fhsmRetentions'')) AND (i.name = ''NC_fhsmRetentions_Enabled_TableName_Sequence''))
			BEGIN
				CREATE NONCLUSTERED INDEX NC_fhsmRetentions_Enabled_TableName_Sequence ON dbo.fhsmRetentions(Enabled, TableName, Sequence)' + @tableCompressionStmt + ';
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the table dbo.fhsmRetentions
	--
	BEGIN
		SET @objectName = 'dbo.fhsmRetentions';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create table dbo.fhsmLog and indexes if they not already exists
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			IF OBJECT_ID(''dbo.fhsmLog'', ''U'') IS NULL
			BEGIN
				RAISERROR(''Creating table dbo.fhsmLog'', 0, 1) WITH NOWAIT;

				CREATE TABLE dbo.fhsmLog(
					Id int identity(1,1) NOT NULL
					,Name nvarchar(128) NOT NULL
					,Version nvarchar(128) NULL
					,Task nvarchar(128) NOT NULL
					,Type nvarchar(16) NOT NULL
					,Message nvarchar(max) NOT NULL
					,TimestampUTC datetime NOT NULL CONSTRAINT DEF_fhsmLog_TimestampUTC DEFAULT (SYSUTCDATETIME())
					,Timestamp datetime NOT NULL CONSTRAINT DEF_fhsmLog_Timestamp DEFAULT (SYSDATETIME())
					,CONSTRAINT PK_fhsmLog PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID(''dbo.fhsmLog'')) AND (i.name = ''NC_fhsmLog_TimestampUTC''))
			BEGIN
				CREATE NONCLUSTERED INDEX NC_fhsmLog_TimestampUTC ON dbo.fhsmLog(TimestampUTC)' + @tableCompressionStmt + ';
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID(''dbo.fhsmLog'')) AND (i.name = ''NC_fhsmLog_Timestamp''))
			BEGIN
				CREATE NONCLUSTERED INDEX NC_fhsmLog_Timestamp ON dbo.fhsmLog(Timestamp)' + @tableCompressionStmt + ';
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID(''dbo.fhsmLog'')) AND (i.name = ''NC_fhsmLog_Type_Timestamp''))
			BEGIN
				CREATE NONCLUSTERED INDEX NC_fhsmLog_Type_Timestamp ON dbo.fhsmLog(Type, Timestamp)' + @tableCompressionStmt + ';
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the table dbo.fhsmLog
	--
	BEGIN
		SET @objectName = 'dbo.fhsmLog';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Register retention for dbo.fhsmLog
	--
	BEGIN
		-- Every day between 23:00 and 24:00
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			WITH
			retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter) AS(
				SELECT
					1
					,''dbo.fhsmLog''
					,1
					,''TimestampUTC''
					,1
					,30
					,NULL
			)
			MERGE dbo.fhsmRetentions AS tgt
			USING retention AS src ON (src.TableName = tgt.TableName) AND (src.Sequence = tgt.Sequence)
			WHEN NOT MATCHED BY TARGET
				THEN INSERT(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter)
				VALUES(src.Enabled, src.TableName, src.Sequence, src.TimeColumn, src.IsUtc, src.Days, src.Filter);
		';
		EXEC(@stmt);
	END;

	--
	-- Create table dbo.fhsmSchedules and indexes if they not already exists
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			IF OBJECT_ID(''dbo.fhsmSchedules'', ''U'') IS NULL
			BEGIN
				RAISERROR(''Creating table dbo.fhsmSchedules'', 0, 1) WITH NOWAIT;

				CREATE TABLE dbo.fhsmSchedules(
					Id int identity(1,1) NOT NULL
					,Enabled bit NOT NULL
					,Name nvarchar(128) NOT NULL
					,Task nvarchar(128) NOT NULL
					,Parameters nvarchar(max) NULL
					,ExecutionDelaySec int NOT NULL
					,FromTime time(0) NOT NULL
					,ToTime time(0) NOT NULL
					,Monday bit NOT NULL
					,Tuesday bit NOT NULL
					,Wednesday bit NOT NULL
					,Thursday bit NOT NULL
					,Friday bit NOT NULL
					,Saturday bit NOT NULL
					,Sunday bit NOT NULL
					,LastStartedUTC datetime NULL
					,LastExecutedUTC datetime NULL
					,LastErrorMessage nvarchar(max) NULL
					,CONSTRAINT PK_fhsmSchedules PRIMARY KEY(Id)' + @tableCompressionStmt + '
					,CONSTRAINT UQ_fhsmSchedules_Name UNIQUE(Name)' + @tableCompressionStmt + '
				);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID(''dbo.fhsmSchedules'')) AND (i.name = ''NC_fhsmSchedules_Enabled_Name''))
			BEGIN
				CREATE NONCLUSTERED INDEX NC_fhsmSchedules_Enabled_Name ON dbo.fhsmSchedules(Enabled, Name)' + @tableCompressionStmt + ';
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the table dbo.fhsmSchedules
	--
	BEGIN
		SET @objectName = 'dbo.fhsmSchedules';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Table'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create or alter function dbo.fhsmFNAgentJobTime
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmFNAgentJobTime'', ''IF'') IS NULL
			BEGIN
				RAISERROR(''Creating stub function dbo.fhsmFNAgentJobTime'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE FUNCTION dbo.fhsmFNAgentJobTime() RETURNS TABLE AS RETURN (SELECT ''''dummy'''' AS Txt);'');
			END;

			--
			-- Alter dbo.fhsmFNAgentJobTime
			--
			BEGIN
				RAISERROR(''Alter function dbo.fhsmFNAgentJobTime'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER FUNCTION dbo.fhsmFNAgentJobTime(
						@date int
						,@time int
						,@duration int
					)
					RETURNS TABLE AS RETURN
					(
						SELECT
							CONVERT(
								datetime,
								(CAST((@date / 10000) AS nvarchar)							-- years
								+ ''''-''''
								+ RIGHT(''''0'''' + CAST((@date % 10000 / 100) AS nvarchar), 2)	-- months
								+ ''''-''''
								+ RIGHT(''''0'''' + CAST((@date % 100) AS nvarchar), 2)			-- days
								+ ''''T''''
								+ RIGHT(''''0'''' + CAST((@time / 10000) AS nvarchar), 2)			-- hours
								+ '''':''''
								+ RIGHT(''''0'''' + CAST((@time % 10000 / 100) AS nvarchar), 2)	-- minutes
								+ '''':''''
								+ RIGHT(''''0'''' + CAST((@time % 100) AS nvarchar), 2))			-- seconds
								,126
							) AS StartDateTime
							,(@duration / 10000) * 3600			-- convert hours to seconds, can be greater than 24
								+ ((@duration % 10000) / 100) * 60	-- convert minutes to seconds
								+ (@duration % 100) AS DurationSeconds
					);
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the function dbo.fhsmFNAgentJobTime
	--
	BEGIN
		SET @objectName = 'dbo.fhsmFNAgentJobTime';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create or alter function dbo.fhsmFNGenerateKey
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @productEndPos int;
			DECLARE @productStartPos int;
			DECLARE @productVersion nvarchar(128);
			DECLARE @productVersion1 int;
			DECLARE @productVersion2 int;
			DECLARE @productVersion3 int;
			DECLARE @stmt nvarchar(max);

			--
			-- Initialize variables
			--
			BEGIN
				SET @productVersion = CAST(SERVERPROPERTY(''ProductVersion'') AS nvarchar);
				SET @productStartPos = 1;
				SET @productEndPos = CHARINDEX(''.'', @productVersion, @productStartPos);
				SET @productVersion1 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
				SET @productStartPos = @productEndPos + 1;
				SET @productEndPos = CHARINDEX(''.'', @productVersion, @productStartPos);
				SET @productVersion2 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
				SET @productStartPos = @productEndPos + 1;
				SET @productEndPos = CHARINDEX(''.'', @productVersion, @productStartPos);
				SET @productVersion3 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
			END;

			IF OBJECT_ID(''dbo.fhsmFNGenerateKey'', ''IF'') IS NULL
			BEGIN
				RAISERROR(''Creating stub function dbo.fhsmFNGenerateKey'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE FUNCTION dbo.fhsmFNGenerateKey() RETURNS TABLE AS RETURN (SELECT ''''dummy'''' AS Txt);'');
			END;

			--
			-- Alter dbo.fhsmFNGenerateKey
			--
			BEGIN
				RAISERROR(''Alter function dbo.fhsmFNGenerateKey'', 0, 1) WITH NOWAIT;
			
				IF (@productVersion1 <= 10)
				BEGIN
					-- SQL Versions SQL2008R2 or lower

					SET @stmt = ''
						ALTER FUNCTION dbo.fhsmFNGenerateKey(
							@p1 nchar(128) = NULL
							,@p2 nchar(128) = NULL
							,@p3 nchar(128) = NULL
							,@p4 nchar(128) = NULL
							,@p5 nchar(128) = NULL
							,@p6 nchar(128) = NULL
						)
						RETURNS TABLE AS RETURN
						(
							SELECT CONVERT(
								bigint
								,HASHBYTES(
									''''SHA1''''
									 ,ISNULL(CAST(UPPER(@p1) AS nvarchar(128)), '''''''')
									+ ISNULL(CAST(UPPER(@p2) AS nvarchar(128)), '''''''')
									+ ISNULL(CAST(UPPER(@p3) AS nvarchar(128)), '''''''')
									+ ISNULL(CAST(UPPER(@p4) AS nvarchar(128)), '''''''')
									+ ISNULL(CAST(UPPER(@p5) AS nvarchar(128)), '''''''')
									+ ISNULL(CAST(UPPER(@p6) AS nvarchar(128)), '''''''')
								)
								,2
							) AS [Key]
						);
					'';
					EXEC(@stmt);
				END
				ELSE BEGIN
					-- SQL Versions SQL2012 or higher

					SET @stmt = ''
						ALTER FUNCTION dbo.fhsmFNGenerateKey(
							@p1 nchar(128) = NULL
							,@p2 nchar(128) = NULL
							,@p3 nchar(128) = NULL
							,@p4 nchar(128) = NULL
							,@p5 nchar(128) = NULL
							,@p6 nchar(128) = NULL
						)
						RETURNS TABLE AS RETURN
						(
							SELECT CONVERT(
								bigint
								,HASHBYTES(
									''''SHA2_256''''
									,CONCAT(
										UPPER(@p1)
										,UPPER(@p2)
										,UPPER(@p3)
										,UPPER(@p4)
										,UPPER(@p5)
										,UPPER(@p6)
									)
								)
								,2
							) AS [Key]
						);
					'';
					EXEC(@stmt);
				END;
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the function dbo.fhsmFNGenerateKey
	--
	BEGIN
		SET @objectName = 'dbo.fhsmFNGenerateKey';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create or alter function dbo.fhsmFNGetConfiguration
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmFNGetConfiguration'', ''FN'') IS NULL
			BEGIN
				RAISERROR(''Creating stub function dbo.fhsmFNGetConfiguration'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE FUNCTION dbo.fhsmFNGetConfiguration() RETURNS bit AS BEGIN RETURN 0; END;'');
			END;

			--
			-- Alter dbo.fhsmFNGetConfiguration
			--
			BEGIN
				RAISERROR(''Alter function dbo.fhsmFNGetConfiguration'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER FUNCTION dbo.fhsmFNGetConfiguration(
						@key nvarchar(128)
					)
					RETURNS nvarchar(128)
					AS
					BEGIN
						DECLARE @value nvarchar(128);

						SET @value = (
							SELECT c.Value
							FROM dbo.fhsmConfigurations AS c
							WHERE (c.[Key] = @key)
						);

						RETURN @value;
					END;
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the function dbo.fhsmFNGetConfiguration
	--
	BEGIN
		SET @objectName = 'dbo.fhsmFNGetConfiguration';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create or alter function dbo.fhsmFNGetTaskParameter
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmFNGetTaskParameter'', ''FN'') IS NULL
			BEGIN
				RAISERROR(''Creating stub function dbo.fhsmFNGetTaskParameter'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE FUNCTION dbo.fhsmFNGetTaskParameter() RETURNS bit AS BEGIN RETURN 0; END;'');
			END;

			--
			-- Alter dbo.fhsmFNGetTaskParameter
			--
			BEGIN
				RAISERROR(''Alter function dbo.fhsmFNGetTaskParameter'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER FUNCTION dbo.fhsmFNGetTaskParameter(
						@task nvarchar(128)
						,@name nvarchar(128)
					)
					RETURNS nvarchar(max)
					AS
					BEGIN
						DECLARE @parameters nvarchar(max);

						SET @parameters = (
							SELECT s.Parameters
							FROM dbo.fhsmSchedules AS s
							WHERE (s.Task = @task) AND (s.Name = @name)
						);

						RETURN @parameters;
					END;
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the function dbo.fhsmFNGetTaskParameter
	--
	BEGIN
		SET @objectName = 'dbo.fhsmFNGetTaskParameter';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create or alter function dbo.fhsmFNGetExecutionDelaySec
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmFNGetExecutionDelaySec'', ''FN'') IS NULL
			BEGIN
				RAISERROR(''Creating stub function dbo.fhsmFNGetExecutionDelaySec'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE FUNCTION dbo.fhsmFNGetExecutionDelaySec() RETURNS bit AS BEGIN RETURN 0; END;'');
			END;

			--
			-- Alter dbo.fhsmFNGetExecutionDelaySec
			--
			BEGIN
				RAISERROR(''Alter function dbo.fhsmFNGetExecutionDelaySec'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER FUNCTION dbo.fhsmFNGetExecutionDelaySec(
						@task nvarchar(128)
						,@name nvarchar(128)
					)
					RETURNS int
					AS
					BEGIN
						DECLARE @parameters nvarchar(max);

						SET @parameters = (
							SELECT s.ExecutionDelaySec
							FROM dbo.fhsmSchedules AS s
							WHERE (s.Task = @task) AND (s.Name = @name)
						);

						RETURN @parameters;
					END;
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the function dbo.fhsmFNGetExecutionDelaySec
	--
	BEGIN
		SET @objectName = 'dbo.fhsmFNGetExecutionDelaySec';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create or alter function dbo.fhsmFNIsValidInstallation
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmFNIsValidInstallation'', ''FN'') IS NULL
			BEGIN
				RAISERROR(''Creating stub function dbo.fhsmFNIsValidInstallation'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE FUNCTION dbo.fhsmFNIsValidInstallation() RETURNS bit AS BEGIN RETURN 0; END;'');
			END;

			--
			-- Alter dbo.fhsmFNIsValidInstallation
			--
			BEGIN
				RAISERROR(''Alter function dbo.fhsmFNIsValidInstallation'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER FUNCTION dbo.fhsmFNIsValidInstallation()
					RETURNS bit
					AS
					BEGIN
						DECLARE @checkCount int;
						DECLARE @retVal bit;

						SET @checkCount = (
							SELECT COUNT(*)
							FROM (
								SELECT ep.name
								FROM sys.extended_properties AS ep
								CROSS APPLY (SELECT o.name, o.schema_id FROM sys.objects AS o WHERE (o.object_id = ep.major_id)) AS Object
								CROSS APPLY (SELECT sch.name FROM sys.schemas AS sch WHERE (sch.schema_id = Object.schema_id)) AS [Schema]
								WHERE (ep.class = 1) AND (ep.name = ''''FHSMVersion'''')
									AND ([Schema].name = ''''dbo'''')
									AND (Object.name IN (
										''''fhsmConfigurations'''', ''''fhsmDimensions'''', ''''fhsmLog'''', ''''fhsmRetentions'''', ''''fhsmSchedules''''
										,''''fhsmSPCleanup'''', ''''fhsmSPExtendedProperties'''', ''''fhsmSPLog'''', ''''fhsmSPSchedules'''', ''''fhsmSPUpdateDimensions''''
										,''''fhsmFNAgentJobTime'''', ''''fhsmFNGenerateKey'''', ''''fhsmFNGetConfiguration'''', ''''fhsmFNGetExecutionDelaySec'''', ''''fhsmFNGetTaskParameter''''
										,''''fhsmFNParseDatabasesStr'''', ''''fhsmFNParseDimensionColumn'''', ''''fhsmFNSplitString'''', ''''fhsmFNTryParseAsInt''''
									))
							) AS a
						);

						SET @retVal = CASE WHEN (@checkCount <> 19) THEN 0 ELSE 1 END;

						RETURN @retVal;
					END;
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the function dbo.fhsmFNIsValidInstallation
	--
	BEGIN
		SET @objectName = 'dbo.fhsmFNIsValidInstallation';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create or alter function dbo.fhsmFNParseDatabasesStr
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmFNParseDatabasesStr'', ''TF'') IS NULL
			BEGIN
				RAISERROR(''Creating stub function dbo.fhsmFNParseDatabasesStr'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE FUNCTION dbo.fhsmFNParseDatabasesStr() RETURNS @dummy TABLE(A int) AS BEGIN RETURN; END;'');
			END;

			--
			-- Alter dbo.fhsmFNParseDatabasesStr
			--
			BEGIN
				RAISERROR(''Alter function dbo.fhsmFNParseDatabasesStr'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER FUNCTION dbo.fhsmFNParseDatabasesStr(
						@databases nvarchar(max)
					)
					RETURNS
						@dbTable TABLE(
							DatabaseName nvarchar(128)
							,[Order] int
						)
					AS
					BEGIN
		';
		SET @stmt += '
						DECLARE @selectedDatabases TABLE(DatabaseName nvarchar(128), DatabaseType nvarchar(1), StartPosition int, Selected bit);
						DECLARE @stringDelimiter nvarchar(max) = '''','''';
						DECLARE @tmpDatabases TABLE(Id int identity, DatabaseName nvarchar(128), DatabaseType nvarchar(1), StartPosition int, [Order] int, Selected bit, PRIMARY KEY(Selected, [Order], Id));

						-- Remove CR-LF if they exists in the input
						SET @databases = REPLACE(@databases, char(10), '''''''');
						SET @databases = REPLACE(@databases, char(13), '''''''');

						-- Remove any spaces after delimiter
						WHILE (CHARINDEX(@stringDelimiter + '''' '''', @databases) > 0)
						BEGIN
							SET @databases = REPLACE(@databases, @stringDelimiter + '''' '''', @stringDelimiter);
						END;

						-- Remove any spaces before delimiter
						WHILE (CHARINDEX('''' '''' + @stringDelimiter, @databases) > 0)
						BEGIN
							SET @databases = REPLACE(@databases, '''' '''' + @stringDelimiter, @stringDelimiter);
						END;

						-- Trim leading and trailing spaces away
						SET @databases = LTRIM(RTRIM(@databases));
		';
		SET @stmt += '

						-- Split the @databases parameter into individual items
						WITH
						Databases1 AS (
							SELECT
								1 AS StartPosition
								,ISNULL(NULLIF(CHARINDEX(@stringDelimiter, @databases, 1), 0), LEN(@databases) + 1) AS EndPosition
								,SUBSTRING(@databases, 1, ISNULL(NULLIF(CHARINDEX(@stringDelimiter, @databases, 1), 0), LEN(@databases) + 1) - 1) AS DatabaseItem
							WHERE @databases IS NOT NULL

							UNION ALL

							SELECT
								CAST(EndPosition AS int) + 1 AS StartPosition
								,ISNULL(NULLIF(CHARINDEX(@stringDelimiter, @databases, EndPosition + 1), 0), LEN(@databases) + 1) AS EndPosition
								,SUBSTRING(@databases, EndPosition + 1, ISNULL(NULLIF(CHARINDEX(@stringDelimiter, @databases, EndPosition + 1), 0), LEN(@databases) + 1) - EndPosition - 1) AS DatabaseItem
							FROM Databases1
							WHERE EndPosition < LEN(@databases) + 1
						)
						,Databases2 AS (
							SELECT
								CASE WHEN DatabaseItem LIKE ''''-%'''' THEN RIGHT(DatabaseItem,LEN(DatabaseItem) - 1) ELSE DatabaseItem END AS DatabaseItem
								,StartPosition
								,CASE WHEN DatabaseItem LIKE ''''-%'''' THEN 0 ELSE 1 END AS Selected
							FROM Databases1
						)
						,Databases3 AS (
							SELECT
								CASE WHEN DatabaseItem IN(''''ALL_DATABASES'''', ''''SYSTEM_DATABASES'''', ''''USER_DATABASES'''') THEN ''''%'''' ELSE DatabaseItem END AS DatabaseItem
								,CASE WHEN DatabaseItem = ''''SYSTEM_DATABASES'''' THEN ''''S'''' WHEN DatabaseItem = ''''USER_DATABASES'''' THEN ''''U'''' ELSE NULL END AS DatabaseType
								,StartPosition
								,Selected
							FROM Databases2
						)
						,Databases4 AS (
							SELECT
								CASE WHEN LEFT(DatabaseItem,1) = ''''['''' AND RIGHT(DatabaseItem,1) = '''']'''' THEN PARSENAME(DatabaseItem, 1) ELSE DatabaseItem END AS DatabaseName
								,DatabaseType
								,StartPosition
								,Selected
							FROM Databases3
						)
						INSERT INTO @selectedDatabases(DatabaseName, DatabaseType, StartPosition, Selected)
						SELECT DatabaseName, DatabaseType, StartPosition, Selected
						FROM Databases4
						OPTION (MAXRECURSION 0);
		';
		SET @stmt += '

						-- Insert databases on the server into @tmpDatabases
						INSERT INTO @tmpDatabases(DatabaseName, DatabaseType, [Order], Selected)
						SELECT
							d.name AS DatabaseName
							,CASE WHEN name IN(''''master'''', ''''msdb'''', ''''model'''', ''''tempdb'''') OR is_distributor = 1 THEN ''''S'''' ELSE ''''U'''' END AS DatabaseType
							,0 AS [Order]
							,0 AS Selected
						FROM sys.databases AS d
						WHERE (d.source_database_id IS NULL)
						ORDER BY d.name ASC;

						-- Update @tmpDatabases with the list of those that are selected
						UPDATE tmpDatabases
						SET tmpDatabases.Selected = SelectedDatabases.Selected
						FROM @tmpDatabases AS tmpDatabases
						INNER JOIN @selectedDatabases AS SelectedDatabases
							ON (tmpDatabases.DatabaseName LIKE REPLACE(SelectedDatabases.DatabaseName, ''''_'''', ''''[_]''''))
							AND ((tmpDatabases.DatabaseType = SelectedDatabases.DatabaseType) OR (SelectedDatabases.DatabaseType IS NULL))
						WHERE (SelectedDatabases.Selected = 1);

						-- Update @tmpDatabases with the list of those that are de-selected
						UPDATE tmpDatabases
						SET tmpDatabases.Selected = SelectedDatabases.Selected
						FROM @tmpDatabases AS tmpDatabases
						INNER JOIN @selectedDatabases AS SelectedDatabases
							ON (tmpDatabases.DatabaseName LIKE REPLACE(SelectedDatabases.DatabaseName, ''''_'''', ''''[_]''''))
							AND ((tmpDatabases.DatabaseType = SelectedDatabases.DatabaseType) OR (SelectedDatabases.DatabaseType IS NULL))
						WHERE (SelectedDatabases.Selected = 0);
		';
		SET @stmt += '

						-- Update @tmpDatabases StartPosition according to the position the databases are in @databases
						UPDATE tmpDatabases
						SET tmpDatabases.StartPosition = SelectedDatabases2.StartPosition
						FROM @tmpDatabases AS tmpDatabases
						INNER JOIN (
							SELECT
								tmpDatabases.DatabaseName
								,MIN(SelectedDatabases.StartPosition) AS StartPosition
							FROM @tmpDatabases AS tmpDatabases
							INNER JOIN @selectedDatabases AS SelectedDatabases
								ON (tmpDatabases.DatabaseName LIKE REPLACE(SelectedDatabases.DatabaseName, ''''_'''', ''''[_]''''))
								AND ((tmpDatabases.DatabaseType = SelectedDatabases.DatabaseType) OR (SelectedDatabases.DatabaseType IS NULL))
							WHERE (SelectedDatabases.Selected = 1)
							GROUP BY tmpDatabases.DatabaseName
						) AS SelectedDatabases2
						ON (tmpDatabases.DatabaseName = SelectedDatabases2.DatabaseName);

						-- Update @tmpDatabases Order based upon the StartPosition
						WITH
						tmpDatabases AS (
							SELECT
								DatabaseName
								,[Order]
								,ROW_NUMBER() OVER (ORDER BY StartPosition ASC, DatabaseName ASC) AS RowNumber
							FROM @tmpDatabases AS tmpDatabases
							WHERE (Selected = 1)
						)
						UPDATE tmpDatabases
						SET [Order] = RowNumber;

						-- Insert data into the result table
						INSERT INTO @dbTable(DatabaseName, [Order])
						SELECT td.DatabaseName, td.[Order]
						FROM @tmpDatabases AS td
						WHERE (td.Selected = 1);

						RETURN;
					END;
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the function dbo.fhsmFNParseDatabasesStr
	--
	BEGIN
		SET @objectName = 'dbo.fhsmFNParseDatabasesStr';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create or alter function dbo.fhsmFNSplitString
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmFNSplitString'', ''IF'') IS NULL
			BEGIN
				RAISERROR(''Creating stub function dbo.fhsmFNSplitString'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE FUNCTION dbo.fhsmFNSplitString() RETURNS TABLE AS RETURN (SELECT ''''dummy'''' AS Txt);'');
			END;

			--
			-- Alter dbo.fhsmFNSplitString
			--
			BEGIN
				RAISERROR(''Alter function dbo.fhsmFNSplitString'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER FUNCTION dbo.fhsmFNSplitString(
						@string nvarchar(max)
						,@delimiter nvarchar(max)
					)
					RETURNS TABLE AS RETURN
					(
						SELECT
							ROW_NUMBER() OVER(ORDER BY(SELECT NULL)) AS Part
							,LTRIM(RTRIM(Split.a.value(''''.'''', ''''nvarchar(max)''''))) AS Txt
						FROM (
							SELECT CAST(''''<X>'''' + REPLACE(@string, @delimiter, ''''</X><X>'''') + ''''</X>'''' AS XML) AS String
						) AS a
						CROSS APPLY String.nodes(''''/X'''') AS Split(a)
					);
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the function dbo.fhsmFNSplitString
	--
	BEGIN
		SET @objectName = 'dbo.fhsmFNSplitString';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Function'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create or alter stored procedure dbo.fhsmSPLog
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmSPLog'', ''P'') IS NULL
			BEGIN
				RAISERROR(''Creating stub stored procedure dbo.fhsmSPLog'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE PROC dbo.fhsmSPLog AS SELECT ''''dummy'''' AS Txt'');
			END;

			--
			-- Alter dbo.fhsmSPLog
			--
			BEGIN
				RAISERROR(''Alter stored procedure dbo.fhsmSPLog'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER PROC dbo.fhsmSPLog(
						@name nvarchar(128)
						,@version nvarchar(128) = NULL
						,@task nvarchar(128)
						,@type nvarchar(16)
						,@message nvarchar(max)
					)
					AS
					BEGIN
						SET NOCOUNT ON;

						DECLARE @printMessage nvarchar(max);

						SET @printMessage = @name + '''': '''' + COALESCE(@version, ''''N.A.'''') + '''': '''' + @task + '''': '''' + @type + '''': '''' + @message;
						PRINT @printMessage;

						INSERT INTO dbo.fhsmLog(Name, Version, Task, Type, Message)
						VALUES (@name, @version, @task, @type, @message);

						RETURN 0;
					END;
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the stored procedure dbo.fhsmSPLog
	--
	BEGIN
		SET @objectName = 'dbo.fhsmSPLog';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create or alter stored procedure dbo.fhsmSPCleanup
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmSPCleanup'', ''P'') IS NULL
			BEGIN
				RAISERROR(''Creating stub stored procedure dbo.fhsmSPCleanup'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE PROC dbo.fhsmSPCleanup AS SELECT ''''dummy'''' AS Txt'');
			END;
		';
		SET @stmt += '
			--
			-- Alter dbo.fhsmSPCleanup
			--
			BEGIN
				RAISERROR(''Alter stored procedure dbo.fhsmSPCleanup'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER PROC dbo.fhsmSPCleanup(
						@name nvarchar(128)
						,@version nvarchar(128) OUTPUT
					)
					AS
					BEGIN
						SET NOCOUNT ON;

						DECLARE @bulkSize int;
						DECLARE @bulkSizeStr nvarchar(128);
						DECLARE @days int;
						DECLARE @defaultBulkSize int;
						DECLARE @filter nvarchar(max);
						DECLARE @id int;
						DECLARE @message nvarchar(max);
						DECLARE @parameters nvarchar(max);
						DECLARE @parametersTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
						DECLARE @rowsDeleted int;
						DECLARE @rowsDeletedTotal int;
						DECLARE @sequence tinyint;
						DECLARE @stmt nvarchar(max);
						DECLARE @tableName nvarchar(128);
						DECLARE @thisTask nvarchar(128);
						DECLARE @timeColumn nvarchar(128);

						SET @defaultBulkSize = 5000;
						SET @thisTask = OBJECT_NAME(@@PROCID);
						SET @version = ''''' + @version + ''''';

						--
						-- Get the parameters for the command
						--
						BEGIN
							SET @parameters = dbo.fhsmFNGetTaskParameter(@thisTask, @name);

							INSERT INTO @parametersTable([Key], Value)
							SELECT
								(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''''='''') AS s WHERE (s.Part = 1)) AS [Key]
								,(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''''='''') AS s WHERE (s.Part = 2)) AS Value
							FROM dbo.fhsmFNSplitString(@parameters, '''';'''') AS p;

							SET @bulkSizeStr = (SELECT pt.Value FROM @parametersTable AS pt WHERE (pt.[Key] = ''''@BulkSize''''));
							SET @bulkSize = dbo.fhsmFNTryParseAsInt(@bulkSizeStr);

							IF (@bulkSize < 1) OR (@bulkSize IS NULL)
							BEGIN
								SET @bulkSize = @defaultBulkSize;
							END;
						END;

						DECLARE tCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
						SELECT r.Id, r.TableName, r.Sequence, r.TimeColumn, r.Days, NULLIF(RTRIM(LTRIM(r.Filter)), '''''''')
						FROM dbo.fhsmRetentions AS r
						WHERE (r.Enabled = 1)
						ORDER BY r.TableName, r.Sequence;

						OPEN tCur;
		';
		SET @stmt += '

						WHILE (1 = 1)
						BEGIN
							FETCH NEXT FROM tCur
							INTO @id, @tableName, @sequence, @timeColumn, @days, @filter;

							IF (@@FETCH_STATUS <> 0)
							BEGIN
								BREAK;
							END;

							IF (OBJECT_ID(@tableName) IS NULL)
							BEGIN
								SET @message = ''''Table '''''''''''' + @tableName + '''''''''''' does not exist'''';
								EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''''Warning'''', @message = @message;
							END
							ELSE IF NOT EXISTS(SELECT * FROM sys.columns AS c WHERE (c.object_id = OBJECT_ID(@tableName)) AND (c.name = '''''''' + @timeColumn + ''''''''))
							BEGIN
								SET @message = ''''Column '''''''''''' + @timeColumn + '''''''''''' in Table '''''''''''' + @tableName + '''''''''''' does not exist'''';
								EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''''Warning'''', @message = @message;
							END
							ELSE BEGIN
								SET @stmt = ''''
									DECLARE @latestDate datetime;
									DECLARE @timeLimit datetime;

									SET @latestDate = (SELECT MAX(t.'''' + @timeColumn + '''') FROM '''' + @tableName + '''' AS t);
									SET @timeLimit = DATEADD(DAY, ABS(@days) * -1, @latestDate);

									BEGIN TRANSACTION;
										DELETE TOP(@bulkSize) t
										FROM '''' + @tableName + '''' AS t
										WHERE (t.'''' + @timeColumn + '''' < @timeLimit)'''' + COALESCE('''' AND ('''' + @filter + '''')'''', '''''''') + '''';

										SET @rowsDeleted = @@ROWCOUNT;
									COMMIT TRANSACTION;

									CHECKPOINT;
								'''';

								UPDATE r
								SET r.LastStartedUTC = SYSUTCDATETIME()
								FROM dbo.fhsmRetentions AS r
								WHERE (r.Id = @id);

								SET @rowsDeletedTotal = 0;

								WHILE (1 = 1)
								BEGIN
									EXEC sp_executesql
										@stmt
										,N''''@days int, @bulkSize int, @rowsDeleted int OUTPUT''''
										,@days = @days
										,@bulkSize = @bulkSize
										,@rowsDeleted = @rowsDeleted OUTPUT;

									IF (@rowsDeleted = 0)
									BEGIN
										BREAK;
									END;

									SET @rowsDeletedTotal += @rowsDeleted;

									UPDATE r
									SET r.LastExecutedUTC = SYSUTCDATETIME()
									FROM dbo.fhsmRetentions AS r
									WHERE (r.Id = @id);

									SET @message = ''''Deleted ''''
										+ CAST(@rowsDeleted AS nvarchar) + '''' records in table '''' + @tableName + '''' sequence '''' + CAST(@sequence AS nvarchar)
										+ '''' older than '''' + CAST(@days AS nvarchar) + '''' days'''';
									EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''''Info'''', @message = @message;
								END;

								UPDATE r
								SET r.LastExecutedUTC = SYSUTCDATETIME()
								FROM dbo.fhsmRetentions AS r
								WHERE (r.Id = @id);

								IF (@rowsDeletedTotal > 0)
								BEGIN
									SET @message = ''''Deleted in total ''''
										+ CAST(@rowsDeletedTotal AS nvarchar) + '''' records in table '''' + @tableName + '''' sequence '''' + CAST(@sequence AS nvarchar)
										+ '''' older than '''' + CAST(@days AS nvarchar) + '''' days'''';
									EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''''Info'''', @message = @message;
								END
								ELSE BEGIN
									SET @message = ''''No records deleted in table '''' + @tableName + '''' older than '''' + CAST(@days AS nvarchar) + '''' days'''';
									EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''''Debug'''', @message = @message;
								END
							END;
						END;

						CLOSE tCur;
						DEALLOCATE tCur;

						RETURN 0;
					END;
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the stored procedure dbo.fhsmSPCleanup
	--
	BEGIN
		SET @objectName = 'dbo.fhsmSPCleanup';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Register schedule for dbo.fhsmSPCleanup
	--
	BEGIN
		-- Every day between 23:00 and 24:00
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			WITH
			schedules(Enabled, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters) AS(
				SELECT
					1
					,''Cleanup data''
					,PARSENAME(''dbo.fhsmSPCleanup'', 1)
					,12 * 60 * 60
					,CAST(''1900-1-1T23:00:00.0000'' AS datetime2(0))
					,CAST(''1900-1-1T23:59:59.0000'' AS datetime2(0))
					,1, 1, 1, 1, 1, 1, 1
					,''@BulkSize = 5000''
			)
			MERGE dbo.fhsmSchedules AS tgt
			USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
			WHEN NOT MATCHED BY TARGET
				THEN INSERT(Enabled, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters)
				VALUES(src.Enabled, src.Name, src.Task, src.ExecutionDelaySec, src.FromTime, src.ToTime, src.Monday, src.Tuesday, src.Wednesday, src.Thursday, src.Friday, src.Saturday, src.Sunday, src.Parameters);
		';
		EXEC(@stmt);
	END;

	--
	-- Create or alter stored procedure dbo.fhsmSPSchedules
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmSPSchedules'', ''P'') IS NULL
			BEGIN
				RAISERROR(''Creating stub stored procedure dbo.fhsmSPSchedules'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE PROC dbo.fhsmSPSchedules AS SELECT ''''dummy'''' AS Txt'');
			END;

			--
			-- Alter dbo.fhsmSPSchedules
			--
			BEGIN
				RAISERROR(''Alter stored procedure dbo.fhsmSPSchedules'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER PROC dbo.fhsmSPSchedules (
						@test bit = 0
					)
					AS
					BEGIN
						SET NOCOUNT ON;

						DECLARE @enabled bit;
						DECLARE @errorMsg nvarchar(max);
						DECLARE @executionDelaySec int;
						DECLARE @fromTime time(0);
						DECLARE @id int;
						DECLARE @lastExecutedUTC datetime;
						DECLARE @lastStartedUTC datetime;
						DECLARE @message nvarchar(max);
						DECLARE @monday bit, @tuesday bit, @wednesday bit, @thursday bit, @friday bit, @saturday bit, @sunday bit;
						DECLARE @name nvarchar(128);
						DECLARE @now datetime;
						DECLARE @nowUTC datetime;
						DECLARE @parameters nvarchar(max);
						DECLARE @stmt nvarchar(max);
						DECLARE @task nvarchar(128);
						DECLARE @thisTask nvarchar(128);
						DECLARE @timeNow time(0);
						DECLARE @toTime time(0);
						DECLARE @version nvarchar(128);

						SET @thisTask = OBJECT_NAME(@@PROCID);

						DECLARE sCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
						SELECT s.Enabled, s.Id, s.Name, s.Task, s.Parameters, s.ExecutionDelaySec, s.FromTime, s.ToTime, s.Monday, s.Tuesday, s.Wednesday, s.Thursday, s.Friday, s.Saturday, s.Sunday, s.LastStartedUTC, s.LastExecutedUTC
						FROM dbo.fhsmSchedules AS s
						ORDER BY s.Task, s.Name;

						OPEN sCur;
		';
		SET @stmt += '

						WHILE (1 = 1)
						BEGIN
							FETCH NEXT FROM sCur
							INTO @enabled, @id, @name, @task, @parameters, @executionDelaySec, @fromTime, @toTime, @monday, @tuesday, @wednesday, @thursday, @friday, @saturday, @sunday, @lastStartedUTC, @lastExecutedUTC;

							IF (@@FETCH_STATUS <> 0)
							BEGIN
								BREAK;
							END;

							--
							-- NULL parameters if it is an empty string. Makes the log nicer
							--
							SET @parameters = NULLIF(@parameters, '''''''');

							-- Update time for every loop
							SELECT
								@now = SYSDATETIME()
								,@nowUTC = SYSUTCDATETIME();
							SET @timeNow = CAST(@now AS time(0));

							IF	(@test = 1)
								OR (
									(@enabled = 1)
									AND (@timeNow >= @fromTime) AND (@timeNow <= @toTime)
									AND (
										(@lastStartedUTC IS NULL)
										OR (DATEADD(SECOND, ABS(@executionDelaySec), DATEADD(MILLISECOND, -DATEPART(MILLISECOND, @lastStartedUTC), @lastStartedUTC)) < @nowUTC)
									)
									AND ((
										CASE DATEPART(WEEKDAY, @now)
											WHEN 1 THEN @sunday
											WHEN 2 THEN @monday
											WHEN 3 THEN @tuesday
											WHEN 4 THEN @wednesday
											WHEN 5 THEN @thursday
											WHEN 6 THEN @friday
											WHEN 7 THEN @saturday
										END
									) = 1)
								)
							BEGIN
								BEGIN TRY;
									UPDATE s
									SET s.LastStartedUTC = @nowUTC
									FROM dbo.fhsmSchedules AS s
									WHERE (s.Id = @id);

									SET @stmt = ''''EXEC '''' + @task + '''' @name = @name, @version = @version OUTPUT;'''';
									EXEC sp_executesql
										@stmt
										,N''''@name nvarchar(128), @version nvarchar(128) OUTPUT''''
										,@name = @name, @version = @version OUTPUT;

									UPDATE s
									SET
										s.LastExecutedUTC = SYSUTCDATETIME()
										,s.LastErrorMessage = NULL
									FROM dbo.fhsmSchedules AS s
									WHERE (s.Id = @id);

									SET @message = @thisTask + CASE WHEN (@test = 1) THEN '''' TEST'''' ELSE '''''''' END + '''' executed '''' + @task + '''' - '''' + @name + COALESCE('''' - '''' + @parameters, '''''''');
									EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @task, @type = ''''Info'''', @message = @message;
								END TRY
								BEGIN CATCH
									SET @errorMsg = ERROR_MESSAGE();

									UPDATE s
									SET
										s.LastExecutedUTC = SYSUTCDATETIME()
										,s.LastErrorMessage = @errorMsg
									FROM dbo.fhsmSchedules AS s
									WHERE (s.Id = @id);

									SET @message = @thisTask + '''' executing '''' + @task + '''' - '''' + @name + '''' failed due to - '''' + @errorMsg;
									EXEC dbo.fhsmSPLog @name = @name, @task = @task, @type = ''''Error'''', @message = @message;
								END CATCH;
							END;
						END;

						CLOSE sCur;
						DEALLOCATE sCur;

						RETURN 0;
					END;
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the stored procedure dbo.fhsmSPSchedules
	--
	BEGIN
		SET @objectName = 'dbo.fhsmSPSchedules';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create or alter stored procedure dbo.fhsmSPUpdateDimensions
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			DECLARE @stmt nvarchar(max);

			IF OBJECT_ID(''dbo.fhsmSPUpdateDimensions'', ''P'') IS NULL
			BEGIN
				RAISERROR(''Creating stub stored procedure dbo.fhsmSPUpdateDimensions'', 0, 1) WITH NOWAIT;

				EXEC(''CREATE PROC dbo.fhsmSPUpdateDimensions AS SELECT ''''dummy'''' AS Txt'');
			END;

			--
			-- Alter dbo.fhsmSPUpdateDimensions
			--
			BEGIN
				RAISERROR(''Alter stored procedure dbo.fhsmSPUpdateDimensions'', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER PROC dbo.fhsmSPUpdateDimensions(
						@table nvarchar(128) = NULL
					)
					AS
					BEGIN
						SET NOCOUNT ON;
		';
		SET @stmt += '

						DECLARE @currentDimensionName nvarchar(128);
						DECLARE @dimensionKey nvarchar(128);
						DECLARE @dimensionName nvarchar(128);
						DECLARE @dimensionStmt nvarchar(max);
						DECLARE @edition nvarchar(128);
						DECLARE @firstTable bit;
						DECLARE @indexName nvarchar(128);
						DECLARE @indexStmt nvarchar(max);
						DECLARE @myUserName nvarchar(128);
						DECLARE @nowUTC datetime;
						DECLARE @nowUTCStr nvarchar(128);
						DECLARE @outputColumn1 nvarchar(128);
						DECLARE @outputColumn2 nvarchar(128);
						DECLARE @outputColumn3 nvarchar(128);
						DECLARE @outputColumn4 nvarchar(128);
						DECLARE @outputColumn5 nvarchar(128);
						DECLARE @outputColumn6 nvarchar(128);
						DECLARE @pbiSchema nvarchar(128);
						DECLARE @productEndPos int;
						DECLARE @productStartPos int;
						DECLARE @productVersion nvarchar(128);
						DECLARE @productVersion1 int;
						DECLARE @productVersion2 int;
						DECLARE @productVersion3 int;
						DECLARE @srcAlias nvarchar(128);
						DECLARE @srcColumn1 nvarchar(128);
						DECLARE @srcColumn2 nvarchar(128);
						DECLARE @srcColumn3 nvarchar(128);
						DECLARE @srcColumn4 nvarchar(128);
						DECLARE @srcColumn5 nvarchar(128);
						DECLARE @srcColumn6 nvarchar(128);
						DECLARE @srcDateColumn nvarchar(128);
						DECLARE @srcTable nvarchar(128);
						DECLARE @srcWhere nvarchar(max);
						DECLARE @tableCompressionStmt nvarchar(max);
						DECLARE @version nvarchar(128);

						SET @myUserName = SUSER_NAME();
						SET @nowUTC = SYSUTCDATETIME();
						SET @nowUTCStr = CONVERT(nvarchar(128), @nowUTC, 126);
						SET @version = ''''' + @version + ''''';

						SET @productVersion = CAST(SERVERPROPERTY(''''ProductVersion'''') AS nvarchar);
						SET @productStartPos = 1;
						SET @productEndPos = CHARINDEX(''''.'''', @productVersion, @productStartPos);
						SET @productVersion1 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
						SET @productStartPos = @productEndPos + 1;
						SET @productEndPos = CHARINDEX(''''.'''', @productVersion, @productStartPos);
						SET @productVersion2 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));
						SET @productStartPos = @productEndPos + 1;
						SET @productEndPos = CHARINDEX(''''.'''', @productVersion, @productStartPos);
						SET @productVersion3 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartpos));

						SET @pbiSchema = dbo.fhsmFNGetConfiguration(''''PBISchema'''');
		';
		SET @stmt += '
						--
						-- Check if SQL version allows to use data compression
						--
						BEGIN
							SET @tableCompressionStmt = '''''''';

							SET @edition = CAST(SERVERPROPERTY(''''Edition'''') AS nvarchar);

							IF (@edition = ''''SQL Azure'''')
								OR (SUBSTRING(@edition, 1, CHARINDEX('''' '''', @edition)) = ''''Developer'''')
								OR (SUBSTRING(@edition, 1, CHARINDEX('''' '''', @edition)) = ''''Enterprise'''')
								OR (@productVersion1 > 13)
								OR ((@productVersion1 = 13) AND (@productVersion2 >= 1))
								OR ((@productVersion1 = 13) AND (@productVersion2 = 0) AND (@productVersion3 >= 4001))
							BEGIN
								SET @tableCompressionStmt = '''' WITH (DATA_COMPRESSION = PAGE)'''';
							END;
						END;
		';
		SET @stmt += '
						--
						-- Create indexes based upon dbo.fhsmDimensions
						--
						BEGIN
							DECLARE dCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
							SELECT DISTINCT d.SrcTable, d.SrcColumn1, d.SrcColumn2, d.SrcColumn3, d.SrcColumn4, d.SrcColumn5, d.SrcColumn6
							FROM dbo.fhsmDimensions AS d
							INNER JOIN (
								SELECT DISTINCT d.DimensionName
								FROM dbo.fhsmDimensions AS d
							) AS modifiedSrcTables ON (modifiedSrcTables.DimensionName = d.DimensionName)
							ORDER BY d.SrcTable, d.SrcColumn6 DESC, d.SrcColumn5 DESC, d.SrcColumn4 DESC, d.SrcColumn3 DESC, d.SrcColumn2 DESC, d.SrcColumn1 DESC;

							OPEN dCur;

							SET @currentDimensionName = '''';
							SET @dimensionStmt = '''';
							SET @firstTable = 1;

							WHILE (1 = 1)
							BEGIN
								FETCH NEXT FROM dCur
								INTO @srcTable, @srcColumn1, @srcColumn2, @srcColumn3, @srcColumn4, @srcColumn5, @srcColumn6

								IF (@@FETCH_STATUS <> 0)
								BEGIN
									BREAK;
								END;

								SET @srcColumn1 = dbo.[fhsmFNParseDimensionColumn](@srcColumn1);
								SET @srcColumn2 = dbo.[fhsmFNParseDimensionColumn](@srcColumn2);
								SET @srcColumn3 = dbo.[fhsmFNParseDimensionColumn](@srcColumn3);
								SET @srcColumn4 = dbo.[fhsmFNParseDimensionColumn](@srcColumn4);
								SET @srcColumn5 = dbo.[fhsmFNParseDimensionColumn](@srcColumn5);
								SET @srcColumn6 = dbo.[fhsmFNParseDimensionColumn](@srcColumn6);

								SET @indexName =
									''''NCAuto_'''' + PARSENAME(@srcTable, 1) + ''''_''''
										+ PARSENAME(@srcColumn1, 1)
										+ COALESCE(''''_'''' + PARSENAME(@srcColumn2, 1), '''''''')
										+ COALESCE(''''_'''' + PARSENAME(@srcColumn3, 1), '''''''')
										+ COALESCE(''''_'''' + PARSENAME(@srcColumn4, 1), '''''''')
										+ COALESCE(''''_'''' + PARSENAME(@srcColumn5, 1), '''''''')
										+ COALESCE(''''_'''' + PARSENAME(@srcColumn6, 1), '''''''');

								SET @indexStmt = ''''
									SET ANSI_WARNINGS OFF;

									DECLARE @coveringIndexExists int;
									DECLARE @indexName nvarchar(128);
									DECLARE @stmt nvarchar(max);
		';
		SET @stmt += '
									DECLARE iCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
									SELECT i.name AS IndexName
									FROM '''' + COALESCE(QUOTENAME(PARSENAME(@srcTable, 3)) + ''''.'''', '''''''') + ''''sys.indexes AS i
									INNER JOIN '''' + COALESCE(QUOTENAME(PARSENAME(@srcTable, 3)) + ''''.'''', '''''''') + ''''sys.objects AS o ON (o.object_id = i.object_id)
									INNER JOIN '''' + COALESCE(QUOTENAME(PARSENAME(@srcTable, 3)) + ''''.'''', '''''''') + ''''sys.schemas AS sch ON (sch.schema_id = o.schema_id)
									WHERE (sch.name = '''''''''''' + PARSENAME(@srcTable, 2) + '''''''''''') AND (o.name = '''''''''''' + PARSENAME(@srcTable, 1) + '''''''''''')
									ORDER BY i.name;

									OPEN iCur;

									SET @coveringIndexExists = 0;

									WHILE (1 = 1)
									BEGIN
										FETCH NEXT FROM iCur
										INTO @indexName;

										IF (@@FETCH_STATUS <> 0)
										BEGIN
											BREAK;
										END;

										IF EXISTS (
											SELECT *
											FROM (
												SELECT
													i.name,
													MAX(CASE WHEN (ic.key_ordinal = 1) THEN c.name END) AS Column1,
													MAX(CASE WHEN (ic.key_ordinal = 2) THEN c.name END) AS Column2,
													MAX(CASE WHEN (ic.key_ordinal = 3) THEN c.name END) AS Column3,
													MAX(CASE WHEN (ic.key_ordinal = 4) THEN c.name END) AS Column4,
													MAX(CASE WHEN (ic.key_ordinal = 5) THEN c.name END) AS Column5,
													MAX(CASE WHEN (ic.key_ordinal = 6) THEN c.name END) AS Column6
													  FROM '''' + COALESCE(QUOTENAME(PARSENAME(@srcTable, 3)) + ''''.'''', '''''''') + ''''sys.indexes AS i
												INNER JOIN '''' + COALESCE(QUOTENAME(PARSENAME(@srcTable, 3)) + ''''.'''', '''''''') + ''''sys.index_columns AS ic ON (ic.object_id = i.object_id) AND (ic.index_id = i.index_id)
												INNER JOIN '''' + COALESCE(QUOTENAME(PARSENAME(@srcTable, 3)) + ''''.'''', '''''''') + ''''sys.columns AS c ON (c.object_id = ic.object_id) AND (c.column_id = ic.column_id)
												INNER JOIN '''' + COALESCE(QUOTENAME(PARSENAME(@srcTable, 3)) + ''''.'''', '''''''') + ''''sys.objects AS o ON (o.object_id = c.object_id)
												INNER JOIN '''' + COALESCE(QUOTENAME(PARSENAME(@srcTable, 3)) + ''''.'''', '''''''') + ''''sys.schemas AS sch ON (sch.schema_id = o.schema_id)
												WHERE (sch.name = '''''''''''' + PARSENAME(@srcTable, 2) + '''''''''''') AND (o.name = '''''''''''' + PARSENAME(@srcTable, 1) + '''''''''''') AND (i.name = @indexName)
												GROUP BY i.name
											) AS a
											WHERE (1 = 1)
												AND (a.Column1 = PARSENAME(@srcColumn1, 1))
												AND ((a.Column2 = PARSENAME(@srcColumn2, 1)) OR (PARSENAME(@srcColumn2, 1) IS NULL))
												AND ((a.Column3 = PARSENAME(@srcColumn3, 1)) OR (PARSENAME(@srcColumn3, 1) IS NULL))
												AND ((a.Column4 = PARSENAME(@srcColumn4, 1)) OR (PARSENAME(@srcColumn4, 1) IS NULL))
												AND ((a.Column5 = PARSENAME(@srcColumn5, 1)) OR (PARSENAME(@srcColumn5, 1) IS NULL))
												AND ((a.Column6 = PARSENAME(@srcColumn6, 1)) OR (PARSENAME(@srcColumn6, 1) IS NULL))
										)
										BEGIN
											SET @coveringIndexExists = 1;
											BREAK;
										END;
									END;

									CLOSE iCur;
									DEALLOCATE iCur;
		';
		SET @stmt += '
									IF (@coveringIndexExists = 0)
									BEGIN
										SET @stmt = ''''''''Adding index ['''' + @indexName + ''''] to table '''' + @srcTable + '''''''''''';
										RAISERROR(@stmt, 0, 1) WITH NOWAIT;

										SET @stmt = ''''''''
											CREATE NONCLUSTERED INDEX ''''
											+ ''''['''' + @indexName + ''''] ON '''' + @srcTable
											+ ''''(''''
												+ PARSENAME(@srcColumn1, 1)
												+ COALESCE('''', '''' + PARSENAME(@srcColumn2, 1), '''''''')
												+ COALESCE('''', '''' + PARSENAME(@srcColumn3, 1), '''''''')
												+ COALESCE('''', '''' + PARSENAME(@srcColumn4, 1), '''''''')
												+ COALESCE('''', '''' + PARSENAME(@srcColumn5, 1), '''''''')
												+ COALESCE('''', '''' + PARSENAME(@srcColumn6, 1), '''''''')
											+ '''')'''' + @tableCompressionStmt + '''';
										'''''''';
										EXEC(@stmt);
									END;
								'''';

								EXEC sp_executesql
									@indexStmt
									,N''''@srcColumn1 nvarchar(128), @srcColumn2 nvarchar(128), @srcColumn3 nvarchar(128), @srcColumn4 nvarchar(128), @srcColumn5 nvarchar(128), @srcColumn6 nvarchar(128)''''
									,@srcColumn1 = @srcColumn1
									,@srcColumn2 = @srcColumn2
									,@srcColumn3 = @srcColumn3
									,@srcColumn4 = @srcColumn4
									,@srcColumn5 = @srcColumn5
									,@srcColumn6 = @srcColumn6;
							END;

							CLOSE dCur;
							DEALLOCATE dCur;
						END;
		';
		SET @stmt += '
						--
						-- Create Time dimension if it does not exist
						--
						BEGIN
							SET @dimensionStmt = ''''
								DECLARE @stmt nvarchar(max);

								IF OBJECT_ID('''''''''''' + QUOTENAME(@pbiSchema) + ''''.Time'''''''', ''''''''V'''''''') IS NULL
								BEGIN
									SET @stmt = ''''''''
										EXEC(''''''''''''''''CREATE VIEW '''' + QUOTENAME(@pbiSchema) + ''''.Time AS SELECT ''''''''''''''''''''''''''''''''dummy'''''''''''''''''''''''''''''''' AS Txt'''''''''''''''');
									'''''''';
									EXEC(@stmt);

									--
									-- Alter fact Time
									--
									SET @stmt = ''''''''
										ALTER VIEW '''' + QUOTENAME(@pbiSchema) + ''''.Time
										AS
										--
										-- This view is auto generated by dbo.fhsmSPUpdateDimensions
										--
										WITH
										L0 AS (SELECT 1 AS c UNION ALL SELECT 1)
										,L1 AS (SELECT 1 AS c FROM L0 AS A CROSS JOIN L0 AS B)
										,L2 AS (SELECT 1 AS c FROM L1 AS A CROSS JOIN L1 AS B)
										,L3 AS (SELECT 1 AS c FROM L2 AS A CROSS JOIN L2 AS B)
										,L4 AS (SELECT 1 AS c FROM L3 AS A CROSS JOIN L3 AS B)
										,L5 AS (SELECT 1 AS c FROM L4 AS A CROSS JOIN L4 AS B)
										,Nums AS(SELECT ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS n FROM L5)
										SELECT
											Nums.n - 1 AS TimeKey
											,(Nums.n - 1) / (60 * 60) AS Hour
											,((Nums.n - 1) / 60) % 60 AS Minute
											,(Nums.n - 1) % 60 AS Second
										FROM Nums
										WHERE Nums.n <= (24 * 60 * 60);
									'''''''';
									EXEC(@stmt);
		';
		SET @stmt += '

									--
									-- Register extended properties
									--
									EXEC dbo.fhsmSPExtendedProperties @objectType = ''''''''View'''''''', @level0name = @pbiSchema, @level1name = ''''''''Time'''''''', @updateIfExists = 1, @propertyName = ''''''''FHSMVersion'''''''', @propertyValue = @version;
									EXEC dbo.fhsmSPExtendedProperties @objectType = ''''''''View'''''''', @level0name = @pbiSchema, @level1name = ''''''''Time'''''''', @updateIfExists = 0, @propertyName = ''''''''FHSMCreated'''''''', @propertyValue = @nowUTCStr;
									EXEC dbo.fhsmSPExtendedProperties @objectType = ''''''''View'''''''', @level0name = @pbiSchema, @level1name = ''''''''Time'''''''', @updateIfExists = 0, @propertyName = ''''''''FHSMCreatedBy'''''''', @propertyValue = @myUserName;
									EXEC dbo.fhsmSPExtendedProperties @objectType = ''''''''View'''''''', @level0name = @pbiSchema, @level1name = ''''''''Time'''''''', @updateIfExists = 1, @propertyName = ''''''''FHSMModified'''''''', @propertyValue = @nowUTCStr;
									EXEC dbo.fhsmSPExtendedProperties @objectType = ''''''''View'''''''', @level0name = @pbiSchema, @level1name = ''''''''Time'''''''', @updateIfExists = 1, @propertyName = ''''''''FHSMModifiedBy'''''''', @propertyValue = @myUserName;
								END;
							'''';
							EXEC sp_executesql
								@dimensionStmt
								,N''''@myUserName nvarchar(128), @nowUTCStr nvarchar(128), @pbiSchema nvarchar(128), @version nvarchar(128)''''
								,@myUserName = @myUserName
								,@nowUTCStr = @nowUTCStr
								,@pbiSchema = @pbiSchema
								,@version = @version;
						END;
		';
		SET @stmt += '

						--
						-- Create date dimension based upon dbo.fhsmDimensions
						--
						BEGIN
							-- Group by just in case different SrcDateColumn writings are registered for the same SrcTable
							DECLARE dCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
							SELECT
								d.SrcTable
								,MAX(d.SrcAlias) AS SrcAlias
								,MAX(d.SrcDateColumn) AS SrcDateColumn
							FROM dbo.fhsmDimensions AS d
							GROUP BY d.SrcTable
							ORDER BY d.SrcTable;

							OPEN dCur;

							SET @dimensionStmt = '''''''';
							SET @firstTable = 1;

							WHILE (1 = 1)
							BEGIN
								FETCH NEXT FROM dCur
								INTO @srcTable, @srcAlias, @srcDateColumn;
			';
			SET @stmt += '

								IF (@@FETCH_STATUS <> 0)
								BEGIN
									IF (@dimensionStmt <> '''''''')
									BEGIN
										--
										-- Terminate view statement
										--
										SET @dimensionStmt += ''''
												) AS a
											)
											,L0 AS (SELECT 1 AS c UNION ALL SELECT 1)
											,L1 AS (SELECT 1 AS c FROM L0 AS A CROSS JOIN L0 AS B)
											,L2 AS (SELECT 1 AS c FROM L1 AS A CROSS JOIN L1 AS B)
											,L3 AS (SELECT 1 AS c FROM L2 AS A CROSS JOIN L2 AS B)
											,L4 AS (SELECT 1 AS c FROM L3 AS A CROSS JOIN L3 AS B)
											,Nums AS(SELECT ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS n FROM L4)
											SELECT
												a.DateKey AS Date
												,DATEPART(YEAR, a.DateKey) * 100 + DATEPART(MONTH, a.DateKey) AS YearMonthKey
												,weekdays.DayNumberOfWeek
												,DATEPART(DAY, a.DateKey) AS DayNumberOfMonth
												,DATEPART(DY, a.DateKey) AS DayNumberOfYear
												,DATEPART(ISO_WEEK, a.DateKey) AS WeekNumber
												,''''''''Week '''''''' + CAST(DATEPART(ISO_WEEK, a.DateKey) AS nvarchar) AS WeekName
												,CASE WHEN weekdays.SQLWeekDay IN (7, 1) THEN 1 ELSE 0 END AS IsWeekend
												,weekdays.WeekdayName
												,weekdays.WeekdayAbbreviation
												,months.MonthNumber AS MonthNumber
												,months.MonthName
												,months.MonthAbbreviation
												,DATEPART(QUARTER, a.DateKey) AS QuarterNumber
												,''''''''Q'''''''' + CAST(DATEPART(QUARTER, a.DateKey) AS varchar) AS QuarterLabel
												,YEAR(a.DateKey) AS Year
												,months.MonthAbbreviation + ''''''''-'''''''' + CAST(YEAR(a.DateKey) AS nvarchar) AS MonthYearLabel
												,-1 * DATEDIFF(DAY, SYSDATETIME(), a.DateKey) AS DayIndex
			';
			SET @stmt += '
											FROM (
												SELECT
													DATEADD(DAY, Nums.n - 1, CAST((CAST(YearRange.MinYear AS nvarchar) + ''''''''-01-01T00:00:00.000'''''''') AS date)) AS DateKey
												FROM Nums
												CROSS APPLY YearRange
												WHERE (YEAR(DATEADD(DAY, Nums.n - 1,  CAST((CAST(YearRange.MinYear AS nvarchar) + ''''''''-01-01T00:00:00.000'''''''') AS date))) <= YearRange.MaxYear)
											) AS a
											LEFT OUTER JOIN (
												VALUES  (2, 1, ''''''''Monday'''''''',    ''''''''Mon''''''''),	
														(3, 2, ''''''''Tuesday'''''''',   ''''''''Tue''''''''),
														(4, 3, ''''''''Wednesday'''''''', ''''''''Wed''''''''),
														(5, 4, ''''''''Thursday'''''''',  ''''''''Thu''''''''),
														(6, 5, ''''''''Friday'''''''',    ''''''''Fri''''''''),
														(7, 6, ''''''''Saturday'''''''',  ''''''''Sat''''''''),
														(1, 7, ''''''''Sunday'''''''',    ''''''''Sun'''''''')
											) AS weekdays (SQLWeekDay, DayNumberOfWeek, WeekdayName, WeekdayAbbreviation)
												ON (weekdays.SQLWeekDay = DATEPART(WEEKDAY, a.DateKey))
											LEFT OUTER JOIN (
												VALUES  (1,  ''''''''January'''''''',   ''''''''Jan''''''''),
														(2,  ''''''''February'''''''',  ''''''''Feb''''''''),
														(3,  ''''''''March'''''''',     ''''''''Mar''''''''),
														(4,  ''''''''April'''''''',     ''''''''Apr''''''''),
														(5,  ''''''''May'''''''',       ''''''''May''''''''),
														(6,  ''''''''June'''''''',      ''''''''Jun''''''''),
														(7,  ''''''''July'''''''',      ''''''''Jul''''''''),
														(8,  ''''''''August'''''''',    ''''''''Aug''''''''),
														(9,  ''''''''September'''''''', ''''''''Sep''''''''),
														(10, ''''''''October'''''''',   ''''''''Oct''''''''),
														(11, ''''''''November'''''''',  ''''''''Nov''''''''),
														(12, ''''''''December'''''''',  ''''''''Dec'''''''')
											) AS months (MonthNumber, MonthName, MonthAbbreviation)
												ON (months.MonthNumber = DATEPART(MONTH, a.DateKey));
										'''';
			';
			SET @stmt += '

										--
										-- Create dimension
										--
										EXEC(@dimensionStmt);

										--
										-- Register extended properties
										--
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = ''''Date'''', @updateIfExists = 1, @propertyName = ''''FHSMVersion'''', @propertyValue = @version;
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = ''''Date'''', @updateIfExists = 0, @propertyName = ''''FHSMCreated'''', @propertyValue = @nowUTCStr;
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = ''''Date'''', @updateIfExists = 0, @propertyName = ''''FHSMCreatedBy'''', @propertyValue = @myUserName;
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = ''''Date'''', @updateIfExists = 1, @propertyName = ''''FHSMModified'''', @propertyValue = @nowUTCStr;
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = ''''Date'''', @updateIfExists = 1, @propertyName = ''''FHSMModifiedBy'''', @propertyValue = @myUserName;
									END;

									BREAK;
								END;
			';
			SET @stmt += '

								--
								-- Set header of view
								--
								IF (@dimensionStmt = '''''''')
								BEGIN
									SET @dimensionStmt = ''''
										IF OBJECT_ID('''''''''''' + QUOTENAME(@pbiSchema) + ''''.Date'''''''', ''''''''V'''''''') IS NULL
										BEGIN
											EXEC(''''''''CREATE VIEW '''' + QUOTENAME(@pbiSchema) + ''''.Date AS SELECT ''''''''''''''''dummy'''''''''''''''' AS Txt'''''''');
										END;
									'''';
									EXEC(@dimensionStmt);

									SET @dimensionStmt = ''''
										ALTER VIEW '''' + QUOTENAME(@pbiSchema) + ''''.Date
										AS
										--
										-- This view is auto generated by dbo.fhsmSPUpdateDimensions
										--
										WITH YearRange AS
										(
											SELECT
												MIN(a.MinYear) AS MinYear
												,MAX(a.MaxYear) AS MaxYear
											FROM (
									'''';
								END;
			';
			SET @stmt += '

								IF (@firstTable = 0)
								BEGIN
									SET @dimensionStmt += ''''
										UNION
									'''';
								END;

								SET @firstTable = 0;

								SET @dimensionStmt += ''''
									SELECT
										DATEPART(YEAR, COALESCE(MIN('''' + @srcDateColumn + ''''), SYSDATETIME())) AS MinYear
										,DATEPART(YEAR, COALESCE(MAX('''' + @srcDateColumn + ''''), SYSDATETIME())) AS MaxYear
									FROM '''' + @srcTable + '''' AS '''' + @srcAlias + ''''
								'''';
							END;

							CLOSE dCur;
							DEALLOCATE dCur;
						END;

						--
						-- Create dynamic dimension based upon dbo.fhsmDimensions
						--
						BEGIN
							DECLARE dCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
							SELECT d.DimensionName, d.DimensionKey, d.SrcTable, d.SrcAlias, d.SrcWhere, d.SrcColumn1, d.SrcColumn2, d.SrcColumn3, d.SrcColumn4, d.SrcColumn5, d.SrcColumn6, d.OutputColumn1, d.OutputColumn2, d.OutputColumn3, d.OutputColumn4, d.OutputColumn5, d.OutputColumn6
							FROM dbo.fhsmDimensions AS d
							INNER JOIN (
								SELECT DISTINCT d.DimensionName
								FROM dbo.fhsmDimensions AS d
								WHERE ((d.SrcTable = @table) OR (@table IS NULL))
							) AS modifiedSrcTables ON (modifiedSrcTables.DimensionName = d.DimensionName)
							ORDER BY d.DimensionName, d.SrcTable;

							OPEN dCur;

							SET @currentDimensionName = '''''''';
							SET @dimensionStmt = '''''''';
							SET @firstTable = 1;
			';
			SET @stmt += '

							WHILE (1 = 1)
							BEGIN
								FETCH NEXT FROM dCur
								INTO @dimensionName, @dimensionKey, @srcTable, @srcAlias, @srcWhere, @srcColumn1, @srcColumn2, @srcColumn3, @srcColumn4, @srcColumn5, @srcColumn6, @outputColumn1, @outputColumn2, @outputColumn3, @outputColumn4, @outputColumn5, @outputColumn6;

								IF (@@FETCH_STATUS <> 0)
								BEGIN
									IF (@currentDimensionName <> '''''''')
									BEGIN
										--
										-- Terminate view statement
										--
										SET @dimensionStmt += ''''
											) AS a;
										'''';

										--
										-- Create @currentDimensionName
										--
										EXEC(@dimensionStmt);

										--
										-- Register extended properties
										--
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = @currentDimensionName, @updateIfExists = 1, @propertyName = ''''FHSMVersion'''', @propertyValue = @version;
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = @currentDimensionName, @updateIfExists = 0, @propertyName = ''''FHSMCreated'''', @propertyValue = @nowUTCStr;
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = @currentDimensionName, @updateIfExists = 0, @propertyName = ''''FHSMCreatedBy'''', @propertyValue = @myUserName;
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = @currentDimensionName, @updateIfExists = 1, @propertyName = ''''FHSMModified'''', @propertyValue = @nowUTCStr;
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = @currentDimensionName, @updateIfExists = 1, @propertyName = ''''FHSMModifiedBy'''', @propertyValue = @myUserName;

										-- Zero variable
										SET @dimensionStmt = '''''''';
										SET @firstTable = 1;
									END;

									BREAK;
								END;
			';
			SET @stmt += '
								IF (@dimensionName <> @currentDimensionName)
								BEGIN
									IF (@currentDimensionName <> '''''''')
									BEGIN
										--
										-- Terminate view statement
										--
										SET @dimensionStmt += ''''
											) AS a;
										'''';

										--
										-- Create @currentDimensionName
										--
										EXEC(@dimensionStmt);

										--
										-- Register extended properties
										--
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = @currentDimensionName, @updateIfExists = 1, @propertyName = ''''FHSMVersion'''', @propertyValue = @version;
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = @currentDimensionName, @updateIfExists = 0, @propertyName = ''''FHSMCreated'''', @propertyValue = @nowUTCStr;
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = @currentDimensionName, @updateIfExists = 0, @propertyName = ''''FHSMCreatedBy'''', @propertyValue = @myUserName;
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = @currentDimensionName, @updateIfExists = 1, @propertyName = ''''FHSMModified'''', @propertyValue = @nowUTCStr;
										EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @pbiSchema, @level1name = @currentDimensionName, @updateIfExists = 1, @propertyName = ''''FHSMModifiedBy'''', @propertyValue = @myUserName;

										-- Zero variable
										SET @dimensionStmt = '''''''';
										SET @firstTable = 1;
									END;
			';
			SET @stmt += '

									--
									-- Setup new view - create stub and prepare the statement for the real view
									--
									BEGIN
										SET @dimensionStmt = ''''
											IF OBJECT_ID('''''''''''' + QUOTENAME(@pbiSchema) + ''''.'''' + QUOTENAME(@dimensionName) + '''''''''''', ''''''''V'''''''') IS NULL
											BEGIN
												EXEC(''''''''CREATE VIEW '''' + QUOTENAME(@pbiSchema) + ''''.'''' + QUOTENAME(@dimensionName) + '''' AS SELECT ''''''''''''''''dummy'''''''''''''''' AS Txt'''''''');
											END;
										'''';
										EXEC(@dimensionStmt);

										SET @dimensionStmt = ''''
											ALTER VIEW '''' + QUOTENAME(@pbiSchema) + ''''.'''' + QUOTENAME(@dimensionName) + ''''
											AS
											--
											-- This view is auto generated by dbo.fhsmSPUpdateDimensions
											--
											SELECT
												a.'''' + QUOTENAME(@outputColumn1)
													+ COALESCE('''', a.'''' + QUOTENAME(@outputColumn2), '''''''')
													+ COALESCE('''', a.'''' + QUOTENAME(@outputColumn3), '''''''')
													+ COALESCE('''', a.'''' + QUOTENAME(@outputColumn4), '''''''')
													+ COALESCE('''', a.'''' + QUOTENAME(@outputColumn5), '''''''')
													+ COALESCE('''', a.'''' + QUOTENAME(@outputColumn6), '''''''') + ''''
												,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.'''' + QUOTENAME(@outputColumn1)
													+ COALESCE('''', a.'''' + QUOTENAME(@outputColumn2), '''', DEFAULT'''')
													+ COALESCE('''', a.'''' + QUOTENAME(@outputColumn3), '''', DEFAULT'''')
													+ COALESCE('''', a.'''' + QUOTENAME(@outputColumn4), '''', DEFAULT'''')
													+ COALESCE('''', a.'''' + QUOTENAME(@outputColumn5), '''', DEFAULT'''')
													+ COALESCE('''', a.'''' + QUOTENAME(@outputColumn6), '''', DEFAULT'''')
												+ '''') AS k) AS '''' + QUOTENAME(@dimensionKey) + ''''
											FROM (
										'''';
									END;
								END;
			';
			SET @stmt += '
								IF (@firstTable = 0)
								BEGIN
									-- Second time we are here
									SET @dimensionStmt += ''''
										UNION
									'''';
								END;

								SET @dimensionStmt += ''''
									SELECT
										DISTINCT
										'''' + @srcColumn1 + '''' COLLATE DATABASE_DEFAULT AS '''' + QUOTENAME(@outputColumn1)
											+ COALESCE('''', '''' + @srcColumn2 + '''' COLLATE DATABASE_DEFAULT AS '''' + QUOTENAME(@outputColumn2), '''''''')
											+ COALESCE('''', '''' + @srcColumn3 + '''' COLLATE DATABASE_DEFAULT AS '''' + QUOTENAME(@outputColumn3), '''''''')
											+ COALESCE('''', '''' + @srcColumn4 + '''' COLLATE DATABASE_DEFAULT AS '''' + QUOTENAME(@outputColumn4), '''''''')
											+ COALESCE('''', '''' + @srcColumn5 + '''' COLLATE DATABASE_DEFAULT AS '''' + QUOTENAME(@outputColumn5), '''''''')
											+ COALESCE('''', '''' + @srcColumn6 + '''' COLLATE DATABASE_DEFAULT AS '''' + QUOTENAME(@outputColumn6), '''''''') + ''''
									FROM '''' + @srcTable + '''' AS '''' + @srcAlias + ''''
									'''' + COALESCE(@srcWhere, '''''''') + ''''
								'''';

								SET @currentDimensionName = @dimensionName;
								SET @firstTable = 0;
							END;

							CLOSE dCur;
							DEALLOCATE dCur;
						END;

						RETURN 0;
					END;
				'';
				EXEC(@stmt);
			END;
		';
		EXEC(@stmt);
	END;

	--
	-- Register extended properties on the stored procedure dbo.fhsmSPUpdateDimensions
	--
	BEGIN
		SET @objectName = 'dbo.fhsmSPUpdateDimensions';

		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
			DECLARE @objName nvarchar(128);
			DECLARE @schName nvarchar(128);

			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = ''Procedure'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
		';
		EXEC sp_executesql
			@stmt
			,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
			,@objectName = @objectName
			,@version = @version
			,@nowUTCStr = @nowUTCStr
			,@myUserName = @myUserName;
	END;

	--
	-- Create views
	--
	BEGIN
		--
		-- Create view @pbiSchema.[Configurations]
		--
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Configurations') + ''', ''V'') IS NULL
				BEGIN
					RAISERROR(''Creating stub view ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Configurations') + ''', 0, 1) WITH NOWAIT;

					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Configurations') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @stmt nvarchar(max);

				RAISERROR(''Alter view ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Configurations') + ''', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Configurations') + '
					AS
					SELECT
						c.[Key]
						,c.Value
					FROM dbo.fhsmConfigurations AS c;
				'';
				EXEC(@stmt);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Configurations]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Configurations');

			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @objName nvarchar(128);
				DECLARE @schName nvarchar(128);

				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
			';
			EXEC sp_executesql
				@stmt
				,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
				,@objectName = @objectName
				,@version = @version
				,@nowUTCStr = @nowUTCStr
				,@myUserName = @myUserName;
		END;

		--
		-- Create view @pbiSchema.[Log]
		--
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log') + ''', ''V'') IS NULL
				BEGIN
					RAISERROR(''Creating stub view ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log') + ''', 0, 1) WITH NOWAIT;

					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @stmt nvarchar(max);

				RAISERROR(''Alter view ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log') + ''', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log') + '
					AS
					SELECT
						l.Id
						,l.Name
						,l.Task
						,l.Type
						,l.Message
						,l.Version
						,l.TimestampUTC, l.Timestamp
					FROM dbo.fhsmLog AS l
					WHERE (l.TimestampUTC > DATEADD(DAY, -1, (SELECT MAX(lMax.TimestampUTC) FROM dbo.fhsmLog AS lMax)));
				'';
				EXEC(@stmt);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Log]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Log');

			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @objName nvarchar(128);
				DECLARE @schName nvarchar(128);

				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
			';
			EXEC sp_executesql
				@stmt
				,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
				,@objectName = @objectName
				,@version = @version
				,@nowUTCStr = @nowUTCStr
				,@myUserName = @myUserName;
		END;

		--
		-- Create view @pbiSchema.[Retentions]
		--
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Retentions') + ''', ''V'') IS NULL
				BEGIN
					RAISERROR(''Creating stub view ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Retentions') + ''', 0, 1) WITH NOWAIT;

					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Retentions') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @stmt nvarchar(max);

				RAISERROR(''Alter view ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Retentions') + ''', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Retentions') + '
					AS
					SELECT
						r.Enabled
						,r.TableName AS [Table]
						,r.TimeColumn AS [Time column]
						,r.IsUtc AS [Is UTC]
						,r.Days
						,r.LastStartedUTC AS [Last started UTC]
						,r.LastExecutedUTC AS [Last executed UTC]
					FROM dbo.fhsmRetentions AS r;
				'';
				EXEC(@stmt);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Retentions]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Retentions');

			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @objName nvarchar(128);
				DECLARE @schName nvarchar(128);

				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
			';
			EXEC sp_executesql
				@stmt
				,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
				,@objectName = @objectName
				,@version = @version
				,@nowUTCStr = @nowUTCStr
				,@myUserName = @myUserName;
		END;

		--
		-- Create view @pbiSchema.[Schedules]
		--
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Schedules') + ''', ''V'') IS NULL
				BEGIN
					RAISERROR(''Creating stub view ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Schedules') + ''', 0, 1) WITH NOWAIT;

					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Schedules') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @stmt nvarchar(max);

				RAISERROR(''Alter view ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Schedules') + ''', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Schedules') + '
					AS
					SELECT
						s.Enabled
						,s.Name
						,s.Task
						,s.Parameters
						,s.ExecutionDelaySec AS [Execution delay in sec.]
						,s.FromTime AS [From time]
						,s.ToTime AS [To time]
						,s.Monday, s.Tuesday, s.Wednesday, s.Thursday, s.Friday, s.Saturday, s.Sunday
						,s.LastStartedUTC AS [Last started UTC]
						,s.LastExecutedUTC AS [Last executed UTC]
						,s.LastErrorMessage
					FROM dbo.fhsmSchedules AS s;
				'';
				EXEC(@stmt);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Schedules]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Schedules');

			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @objName nvarchar(128);
				DECLARE @schName nvarchar(128);

				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
			';
			EXEC sp_executesql
				@stmt
				,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
				,@objectName = @objectName
				,@version = @version
				,@nowUTCStr = @nowUTCStr
				,@myUserName = @myUserName;
		END;

		--
		-- Create view @pbiSchema.[Junk dimensions]
		--
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Junk dimensions') + ''', ''V'') IS NULL
				BEGIN
					RAISERROR(''Creating stub view ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Junk dimensions') + ''', 0, 1) WITH NOWAIT;

					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Junk dimensions') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @stmt nvarchar(max);

				RAISERROR(''Alter view ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Junk dimensions') + ''', 0, 1) WITH NOWAIT;

				SET @stmt = ''
					ALTER VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Junk dimensions') + '
					AS
					SELECT
						 junkType.Category
						 ,junkType.Name
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(junkType.Category, junkType.Type, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS [Key]
					FROM (
								  SELECT 1 AS Category, ''''D'''' AS Type, ''''Database'''' AS Name
						UNION ALL SELECT 1 AS Category, ''''I'''' AS Type, ''''Differential database'''' AS Name
						UNION ALL SELECT 1 AS Category, ''''L'''' AS Type, ''''Log'''' AS Name
						UNION ALL SELECT 1 AS Category, ''''F'''' AS Type, ''''File/filegroup'''' AS Name
						UNION ALL SELECT 1 AS Category, ''''G'''' AS Type, ''''Differential file'''' AS Name
						UNION ALL SELECT 1 AS Category, ''''P'''' AS Type, ''''Partial'''' AS Name
						UNION ALL SELECT 1 AS Category, ''''Q'''' AS Type, ''''Differential partial'''' AS Name
					) AS junkType;
				'';
				EXEC(@stmt);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Junk dimensions]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Junk dimensions');

			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @objName nvarchar(128);
				DECLARE @schName nvarchar(128);

				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMVersion'', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreated'', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''FHSMCreatedBy'', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModified'', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = ''View'', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''FHSMModifiedBy'', @propertyValue = @myUserName;
			';
			EXEC sp_executesql
				@stmt
				,N'@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant'
				,@objectName = @objectName
				,@version = @version
				,@nowUTCStr = @nowUTCStr
				,@myUserName = @myUserName;
		END;
	END;

	--
	-- Create SQL agent job if it not already exists
	--
	IF (@createSQLAgentJob = 1)
		AND NOT EXISTS (
			SELECT *
			FROM msdb.dbo.sysjobs AS sj
			WHERE (sj.name = 'FHSQLMonitor in ' + @fhSQLMonitorDatabase)
		)
	BEGIN
		SET @stmt = '
			RAISERROR(''Creating SQL agent job ' + @fhSQLMonitorDatabase + ''', 0, 1) WITH NOWAIT;

			EXEC msdb.dbo.sp_add_job
				@job_name = N''FHSQLMonitor in ' + @fhSQLMonitorDatabase + '''
				,@enabled = 0
				,@notify_level_eventlog = 0
				,@notify_level_email = 2
				,@notify_level_page = 2
				,@delete_level = 0;

			EXEC msdb.dbo.sp_add_jobserver
				@job_name=N''FHSQLMonitor in ' + @fhSQLMonitorDatabase + '''
				,@server_name = N''' + @@SERVERNAME + ''';

			EXEC msdb.dbo.sp_add_jobstep
				@job_name = N''FHSQLMonitor in ' + @fhSQLMonitorDatabase + '''
				,@step_name = N''Run FHSQLMonitor''
				,@step_id = 1
				,@cmdexec_success_code = 0
				,@on_success_action = 1
				,@on_fail_action = 2
				,@retry_attempts = 0
				,@retry_interval = 0
				,@os_run_priority = 0
				,@subsystem = N''TSQL''
				,@command = N''EXEC dbo.fhsmSPSchedules;''
				,@database_name = N''' + @fhSQLMonitorDatabase + '''
				,@flags = 0;

			EXEC msdb.dbo.sp_update_job
				@job_name = N''FHSQLMonitor in ' + @fhSQLMonitorDatabase + '''
				,@enabled = 0
				,@start_step_id = 1
				,@notify_level_eventlog = 0
				,@notify_level_email = 2
				,@notify_level_page = 2
				,@delete_level = 0
				,@description = N''''
				,@notify_email_operator_name = N''''
				,@notify_page_operator_name = N'''';

			EXEC msdb.dbo.sp_add_jobschedule
				@job_name = N''FHSQLMonitor in ' + @fhSQLMonitorDatabase + '''
				,@name = N''FHSQLMonitor in ' + @fhSQLMonitorDatabase + '''
				,@enabled = 1
				,@freq_type = 4
				,@freq_interval = 1
				,@freq_subday_type = 2	-- seconds
				,@freq_subday_interval = 30
				,@freq_relative_interval = 0
				,@freq_recurrence_factor = 1
				,@active_start_date = 20200910
				,@active_end_date = 99991231
				,@active_start_time = 0
				,@active_end_time = 235959;
		';
		EXEC(@stmt);
	END;
END;
