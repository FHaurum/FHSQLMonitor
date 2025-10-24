SET NOCOUNT ON;

--
-- Default installations parameters
--
BEGIN
	DECLARE @createSQLAgentJob bit;
	DECLARE @fhsqlAgentJobName nvarchar(128);
	DECLARE @fhSQLMonitorDatabase nvarchar(128);
	DECLARE @pbiSchema nvarchar(128);
	DECLARE @buildTimeStr nvarchar(128);

	SET @createSQLAgentJob = 1;
	SET @fhsqlAgentJobName = 'FHSQLMonitor in FHSQLMonitor';
	SET @fhSQLMonitorDatabase = 'FHSQLMonitor';
	SET @pbiSchema = 'FHSM';
	SET @buildTimeStr = 'YYYY.MM.DD HH.MM.SS';
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
	SET @version = '2.11.1';
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
	END;

	--
	-- Create or alter function dbo.fhsmFNTryParseAsInt
	--
	BEGIN
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
			SET @productVersion1 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));

			SET @productStartPos = @productEndPos + 1;
			SET @productEndPos = CHARINDEX(''.'', CAST(@productVersion AS nvarchar(128)) COLLATE DATABASE_DEFAULT, @productStartPos);
			SET @productVersion2 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));

			SET @productStartPos = @productEndPos + 1;
			SET @productEndPos = CHARINDEX(''.'', CAST(@productVersion AS nvarchar(128)) COLLATE DATABASE_DEFAULT, @productStartPos);
			SET @productVersion3 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));

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
	END;

	--
	-- Save installation data in dbo.fhsmConfigurations
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

			WITH
			cfg([Key], Value) AS(
				SELECT
					''BuildTime''
					,''' + CAST(@buildTimeStr AS nvarchar) + '''
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
						,CreateAutoIndex bit NULL
						,CONSTRAINT PK_fhsmDimensions PRIMARY KEY(Id)' + @tableCompressionStmt + '
						,CONSTRAINT UQ_fhsmDimensions_SrcTable_DimensionName UNIQUE(SrcTable, DimensionName)' + @tableCompressionStmt + '
					);
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Adding column CreateAutoIndex to table dbo.fhsmDimensions if it not already exists
		--
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				IF NOT EXISTS (SELECT * FROM sys.columns AS c WHERE (c.object_id = OBJECT_ID(''dbo.fhsmDimensions'')) AND (c.name = ''CreateAutoIndex''))
				BEGIN
					RAISERROR(''Adding column [CreateAutoIndex] to table dbo.fhsmDimensions'', 0, 1) WITH NOWAIT;

					ALTER TABLE dbo.fhsmDimensions
						ADD CreateAutoIndex bit NULL;
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
		-- Delete registration for DatabaseFileKey as it wil be changed by DatabaseIO and DatabaseSize
		--
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DELETE d
				FROM dbo.fhsmDimensions AS d
				WHERE (1 = 1)
					AND (d.DimensionKey = ''DatabaseFileKey'')
					AND (d.SrcColumn4 IS NULL);
			';
			EXEC(@stmt);
		END;
	END;

	--
	-- Create table dbo.fhsmRetentions and indexes if they not already exists
	--
	BEGIN
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
	END;

	--
	-- Create table dbo.fhsmLog and indexes if they not already exists
	--
	BEGIN
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

				IF EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID(''dbo.fhsmLog'')) AND (i.name = ''NCAuto_fhsmLog_Task_Name''))
				BEGIN
					DROP INDEX NCAuto_fhsmLog_Task_Name ON dbo.fhsmLog;
				END;

				IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID(''dbo.fhsmLog'')) AND (i.name = ''NC_fhsmLog_Task_Name_Version''))
				BEGIN
					CREATE NONCLUSTERED INDEX NC_fhsmLog_Task_Name_Version ON dbo.fhsmLog(Task, Name, Version)' + @tableCompressionStmt + ';
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

				WITH
				retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter) AS(
					SELECT
						1
						,''dbo.fhsmLog''
						,2
						,''TimestampUTC''
						,1
						,7
						,''Type = ''''Debug''''''
				)
				MERGE dbo.fhsmRetentions AS tgt
				USING retention AS src ON (src.TableName = tgt.TableName) AND (src.Sequence = tgt.Sequence)
				WHEN NOT MATCHED BY TARGET
					THEN INSERT(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter)
					VALUES(src.Enabled, src.TableName, src.Sequence, src.TimeColumn, src.IsUtc, src.Days, src.Filter);
			';
			EXEC(@stmt);
		END;
	END;

	--
	-- Create table dbo.fhsmProcessing and indexes if they not already exists
	--
	BEGIN
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				IF OBJECT_ID(''dbo.fhsmProcessing'', ''U'') IS NULL
				BEGIN
					RAISERROR(''Creating table dbo.fhsmProcessing'', 0, 1) WITH NOWAIT;

					CREATE TABLE dbo.fhsmProcessing(
						Id int identity(1,1) NOT NULL
						,Name nvarchar(128) NOT NULL
						,Task nvarchar(128) NOT NULL
						,Version nvarchar(128) NULL
						,Type int NOT NULL
						,StartedTimestampUTC datetime NOT NULL
						,StartedTimestamp datetime NOT NULL
						,EndedTimestampUTC datetime NULL
						,EndedTimestamp datetime NULL
						,CONSTRAINT PK_fhsmProcessing PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				END;

				IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID(''dbo.fhsmProcessing'')) AND (i.name = ''NC_fhsmProcessing_StartedTimestampUTC''))
				BEGIN
					CREATE NONCLUSTERED INDEX NC_fhsmProcessing_StartedTimestampUTC ON dbo.fhsmProcessing(StartedTimestampUTC)' + @tableCompressionStmt + ';
				END;

				IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID(''dbo.fhsmProcessing'')) AND (i.name = ''NC_fhsmProcessing_StartedTimestamp''))
				BEGIN
					CREATE NONCLUSTERED INDEX NC_fhsmProcessing_StartedTimestamp ON dbo.fhsmProcessing(StartedTimestamp)' + @tableCompressionStmt + ';
				END;

				IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID(''dbo.fhsmProcessing'')) AND (i.name = ''NC_fhsmProcessing_Task_Name_Version''))
				BEGIN
					CREATE NONCLUSTERED INDEX NC_fhsmProcessing_Task_Name_Version ON dbo.fhsmProcessing(Task, Name, Version)' + @tableCompressionStmt + ';
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmProcessing
		--
		BEGIN
			SET @objectName = 'dbo.fhsmProcessing';

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
		-- Register retention for dbo.fhsmProcessing
		--
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				WITH
				retention(Enabled, TableName, Sequence, TimeColumn, IsUtc, Days, Filter) AS(
					SELECT
						1
						,''dbo.fhsmProcessing''
						,1
						,''StartedTimestampUTC''
						,1
						,90
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
	END;

	--
	-- Create table dbo.fhsmSchedules and indexes if they not already exists
	--
	BEGIN
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				IF OBJECT_ID(''dbo.fhsmSchedules'', ''U'') IS NULL
				BEGIN
					RAISERROR(''Creating table dbo.fhsmSchedules'', 0, 1) WITH NOWAIT;

					CREATE TABLE dbo.fhsmSchedules(
						Id int identity(1,1) NOT NULL
						,Enabled bit NOT NULL
						,DeploymentStatus int NOT NULL CONSTRAINT DEF_fhsmSchedules_DeploymentStatus DEFAULT 0
						,Name nvarchar(128) NOT NULL
						,Task nvarchar(128) NOT NULL
						,Parameter nvarchar(max) NULL
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
		-- Adding column DeploymentStatus to table dbo.fhsmSchedules if it not already exists
		--
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				IF NOT EXISTS (SELECT * FROM sys.columns AS c WHERE (c.object_id = OBJECT_ID(''dbo.fhsmSchedules'')) AND (c.name = ''DeploymentStatus''))
				BEGIN
					RAISERROR(''Adding column [DeploymentStatus] to table dbo.fhsmSchedules'', 0, 1) WITH NOWAIT;

					ALTER TABLE dbo.fhsmSchedules
						ADD DeploymentStatus int NOT NULL CONSTRAINT DEF_fhsmSchedules_DeploymentStatus DEFAULT 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Rename column Parameters on table dbo.fhsmSchedules to Parameter
		--
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				IF EXISTS (SELECT * FROM sys.columns AS c WHERE (c.object_id = OBJECT_ID(''dbo.fhsmSchedules'')) AND (c.name = ''Parameters''))
				BEGIN
					RAISERROR(''Renaming column [Parameters] on table dbo.fhsmSchedules to [Parameter]'', 0, 1) WITH NOWAIT;

					EXEC sp_rename ''dbo.fhsmSchedules.Parameters'', ''Parameter'', ''COLUMN'';
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
	END;

	--
	-- Create or alter function dbo.fhsmFNAgentJobTime
	--
	BEGIN
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
	END;

	--
	-- Create or alter function dbo.fhsmFNGenerateKey
	--
	BEGIN
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
					SET @productVersion1 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));
					SET @productStartPos = @productEndPos + 1;
					SET @productEndPos = CHARINDEX(''.'', @productVersion, @productStartPos);
					SET @productVersion2 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));
					SET @productStartPos = @productEndPos + 1;
					SET @productEndPos = CHARINDEX(''.'', @productVersion, @productStartPos);
					SET @productVersion3 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));
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
	END;

	--
	-- Create or alter function dbo.fhsmFNGetConfiguration
	--
	BEGIN
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
	END;

	--
	-- Create or alter function dbo.fhsmFNConvertToDisplayTxt
	--
	BEGIN
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @stmt nvarchar(max);

				IF OBJECT_ID(''dbo.fhsmFNConvertToDisplayTxt'', ''FN'') IS NULL
				BEGIN
					RAISERROR(''Creating stub function dbo.fhsmFNConvertToDisplayTxt'', 0, 1) WITH NOWAIT;

					EXEC(''CREATE FUNCTION dbo.fhsmFNConvertToDisplayTxt() RETURNS bit AS BEGIN RETURN 0; END;'');
				END;

				--
				-- Alter dbo.fhsmFNConvertToDisplayTxt
				--
				BEGIN
					RAISERROR(''Alter function dbo.fhsmFNConvertToDisplayTxt'', 0, 1) WITH NOWAIT;

					SET @stmt = ''
						ALTER FUNCTION dbo.fhsmFNConvertToDisplayTxt(
							@txt nvarchar(128)
						)
						RETURNS nvarchar(128)
						AS
						BEGIN
							RETURN UPPER(LEFT(@txt, 1)) + SUBSTRING(REPLACE(LOWER(@txt), ''''_'''', '''' ''''), 2, LEN(@txt));
						END;
					'';
					EXEC(@stmt);
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the function dbo.fhsmFNConvertToDisplayTxt
		--
		BEGIN
			SET @objectName = 'dbo.fhsmFNConvertToDisplayTxt';

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
	END;

	--
	-- Create or alter function dbo.fhsmFNGetTaskParameter
	--
	BEGIN
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
							DECLARE @parameter nvarchar(max);

							SET @parameter = (
								SELECT s.Parameter
								FROM dbo.fhsmSchedules AS s
								WHERE (s.Task = @task) AND (s.Name = @name)
							);

							RETURN @parameter;
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
	END;

	--
	-- Create or alter function dbo.fhsmFNGetExecutionDelaySec
	--
	BEGIN
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
							DECLARE @executionDelaySec nvarchar(max);

							SET @executionDelaySec = (
								SELECT s.ExecutionDelaySec
								FROM dbo.fhsmSchedules AS s
								WHERE (s.Task = @task) AND (s.Name = @name)
							);

							RETURN @executionDelaySec;
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
	END;

	--
	-- Create or alter function dbo.fhsmFNIsValidInstallation
	--
	BEGIN
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
											 ''''fhsmConfigurations'''',       ''''fhsmDimensions'''',             ''''fhsmLog'''',                ''''fhsmProcessing'''',             ''''fhsmRetentions''''
											,''''fhsmSchedules'''',            ''''fhsmSPAgentJobControl'''',      ''''fhsmSPCleanup'''',          ''''fhsmSPControl'''',              ''''fhsmSPControlCleanup''''
											,''''fhsmSPExtendedProperties'''', ''''fhsmSPLog'''',                  ''''fhsmSPProcessing'''',       ''''fhsmSPSchedules'''',            ''''fhsmSPUpdateDimensions''''
											,''''fhsmFNAgentJobTime'''',       ''''fhsmFNGenerateKey'''',          ''''fhsmFNGetConfiguration'''', ''''fhsmFNGetExecutionDelaySec'''', ''''fhsmFNGetTaskParameter''''
											,''''fhsmFNParseDatabasesStr'''',  ''''fhsmFNParseDimensionColumn'''', ''''fhsmFNSplitString'''',      ''''fhsmFNTryParseAsInt''''
										))
								) AS a
							);

							SET @retVal = CASE WHEN (@checkCount <> 24) THEN 0 ELSE 1 END;

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
	END;

	--
	-- Create or alter function dbo.fhsmFNParseDatabasesStr
	--
	BEGIN
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
	END;

	--
	-- Create or alter function dbo.fhsmFNSplitString
	--
	BEGIN
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
	END;

	--
	-- Create or alter stored procedure dbo.fhsmSPAgentJobControl
	--
	BEGIN
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @stmt nvarchar(max);

				IF OBJECT_ID(''dbo.fhsmSPAgentJobControl'', ''P'') IS NULL
				BEGIN
					RAISERROR(''Creating stub stored procedure dbo.fhsmSPAgentJobControl'', 0, 1) WITH NOWAIT;

					EXEC(''CREATE PROC dbo.fhsmSPAgentJobControl AS SELECT ''''dummy'''' AS Txt'');
				END;

				--
				-- Alter dbo.fhsmSPAgentJobControl
				--
				BEGIN
					RAISERROR(''Alter stored procedure dbo.fhsmSPAgentJobControl'', 0, 1) WITH NOWAIT;

					SET @stmt = ''
						ALTER PROC dbo.fhsmSPAgentJobControl(
							@command nvarchar(8),
							@jobStatus int OUTPUT
						)
						AS
						BEGIN
							SET NOCOUNT ON;
			';
			SET @stmt += '
							DECLARE @jobExecuting nvarchar(16);
							DECLARE @jobName nvarchar(128);
							DECLARE @message nvarchar(max);
							DECLARE @now datetime;
							DECLARE @nowStr nvarchar(max);
							DECLARE @waitCnt int;

							SET @jobName = dbo.fhsmFNGetConfiguration(''''AgentJobName'''');

							--
							-- Get job enabled status
							--
							BEGIN
								SET @jobStatus =
									COALESCE(
										(
											SELECT sj.enabled
											FROM msdb.dbo.sysjobs AS sj
											WHERE (sj.name = @jobName)
										),
										-1
									);

								IF (@jobStatus IN (0, 1))
								BEGIN
								   RAISERROR('''''''', 0, 1) WITH NOWAIT;
									SET @message = ''''Agent job '''' + QUOTENAME(@jobName) + '''' is '''' + CASE @jobStatus WHEN 1 THEN ''''enabled'''' WHEN 0 THEN ''''disabled'''' END;
									RAISERROR(@message, 0, 1) WITH NOWAIT;
								END;
							END;

							IF (@command = ''''Disable'''')
							BEGIN
								--
								-- Disable job if enabled
								--
								IF (@jobStatus = 1)
								BEGIN
									RAISERROR('''''''', 0, 1) WITH NOWAIT;
									SET @message = ''''Disabling job '''' + QUOTENAME(@jobName);
									RAISERROR(@message, 0, 1) WITH NOWAIT;

									EXEC msdb.dbo.sp_update_job
										@job_name = @jobName,
										@enabled = 0;

									WAITFOR DELAY ''''00:00:10'''';
								END;

								--
								-- Wait until job has stopped executing
								--
								BEGIN
									SET @waitCnt = 0;

									SET @jobExecuting = ''''Running'''';

									WHILE (@jobExecuting = ''''Running'''')
									BEGIN
										SET @jobExecuting = (
											SELECT
												TOP 1
												CASE
													WHEN ja.job_id IS NOT NULL AND ja.stop_execution_date IS NULL THEN ''''Running''''
													WHEN jh.run_status = 0 THEN ''''Failed''''
													WHEN jh.run_status = 1 THEN ''''Succeeded''''
													WHEN jh.run_status = 2 THEN ''''Retry''''
													WHEN jh.run_status = 3 THEN ''''Cancelled''''
												END AS JobLastOutcome
											FROM msdb.dbo.sysjobs AS j
											LEFT JOIN msdb.dbo.sysjobactivity AS ja ON
												(ja.job_id = j.job_id)
												AND (ja.run_requested_date IS NOT NULL)
												AND (ja.start_execution_date IS NOT NULL)
											LEFT JOIN msdb.dbo.sysjobsteps AS js ON
												(js.job_id = ja.job_id)
												AND (js.step_id = ja.last_executed_step_id)
											LEFT JOIN msdb.dbo.sysjobhistory AS jh ON
												(jh.job_id = j.job_id)
												AND (jh.instance_id = ja.job_history_id)
											WHERE j.name = @jobName
											ORDER BY ja.start_execution_date DESC
										);

										IF (@jobExecuting = ''''Running'''')
										BEGIN
											SET @waitCnt = @waitCnt + 1;

											SET @now = GETDATE();
											SET @nowStr = CONVERT(nvarchar, @now, 126);
											SET @nowStr = REPLACE(LEFT(@nowStr, LEN(@nowStr) - 4), ''''T'''', '''' '''');

											SET @message = ''''  Waiting for job '''' + QUOTENAME(@jobName) + '''' to stop executing - #:'''' + CAST(@waitCnt AS nvarchar) + '''' - '''' + @nowStr;
											RAISERROR(@message, 0, 1) WITH NOWAIT;

											WAITFOR DELAY ''''00:00:05'''';
										END;
									END;
								END;
							END
							ELSE IF (@command = ''''Enable'''')
							BEGIN
								--
								-- Enable job again if it was enabled when we started
								--
								IF (@jobStatus = 0)
								BEGIN
									RAISERROR('''''''', 0, 1) WITH NOWAIT;
									SET @message = ''''Enabling job '''' + QUOTENAME(@jobName);
									RAISERROR(@message, 0, 1) WITH NOWAIT;

									EXEC msdb.dbo.sp_update_job
										@job_name = @jobName,
										@enabled = 1;
								END;
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
		-- Register extended properties on the stored procedure dbo.fhsmSPAgentJobControl
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPAgentJobControl';

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
	END;

	--
	-- Create or alter stored procedure dbo.fhsmSPControl
	--
	BEGIN
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @stmt nvarchar(max);

				IF OBJECT_ID(''dbo.fhsmSPControl'', ''P'') IS NULL
				BEGIN
					RAISERROR(''Creating stub stored procedure dbo.fhsmSPControl'', 0, 1) WITH NOWAIT;

					EXEC(''CREATE PROC dbo.fhsmSPControl AS SELECT ''''dummy'''' AS Txt'');
				END;

				--
				-- Alter dbo.fhsmSPControl
				--
				BEGIN
					RAISERROR(''Alter stored procedure dbo.fhsmSPControl'', 0, 1) WITH NOWAIT;

					SET @stmt = ''
						ALTER PROC dbo.fhsmSPControl(
							@Command nvarchar(16) = '''''''',
							@Days int = NULL,
							@Enabled bit = NULL,
							@ExecutionDelaySec int = NULL,
							@Filter nvarchar(max) = '''''''',
							@Friday bit = NULL,
							@FromTime nvarchar(8) = '''''''',
							@IsUtc bit = NULL,
							@Key nvarchar(128) = '''''''',
							@Monday bit = NULL,
							@Name nvarchar(128) = '''''''',
							@NewValue nvarchar(128) = '''''''',
							@Parameter nvarchar(max) = '''''''',
							@Saturday bit = NULL,
							@Sequence tinyint = NULL,
							@Sunday bit = NULL,
							@TableName nvarchar(128) = '''''''',
							@Task nvarchar(128) = '''''''',
							@TimeColumn nvarchar(128) = '''''''',
							@Thursday bit = NULL,
							@ToTime nvarchar(8) = '''''''',
							@Tuesday bit = NULL,
							@Type nvarchar(16),
							@Value nvarchar(128) = '''''''',
							@Wednesday bit = NULL
						)
						AS
						BEGIN
							SET NOCOUNT ON;

							DECLARE @message nvarchar(max);
							DECLARE @retentionChanges TABLE(
								Action nvarchar(10),
								DeletedDays int,
								DeletedEnabled bit,
								InsertedDays int,
								InsertedEnabled bit
							);
							DECLARE @scheduleChanges TABLE(
								Action nvarchar(10),
								DeletedEnabled bit,
								DeletedExecutionDelaySec int,
								DeletedFromTime time(0),
								DeletedToTime time(0),
								DeletedMonday bit,
								DeletedTuesday bit,
								DeletedWednesday bit,
								DeletedThursday bit,
								DeletedFriday bit,
								DeletedSaturday bit,
								DeletedSunday bit,
								InsertedEnabled bit,
								InsertedExecutionDelaySec int,
								InsertedFromTime time(0),
								InsertedToTime time(0),
								InsertedMonday bit,
								InsertedTuesday bit,
								InsertedWednesday bit,
								InsertedThursday bit,
								InsertedFriday bit,
								InsertedSaturday bit,
								InsertedSunday bit
							);
							DECLARE @scheduleId int;
							DECLARE @spControl nvarchar(128);
							DECLARE @stmt nvarchar(max);
							DECLARE @thisTask nvarchar(128);
							DECLARE @version nvarchar(128);
			';
			SET @stmt += '
							SET @thisTask = OBJECT_NAME(@@PROCID);
							SET @version = ''''' + @version + ''''';

							SET @Command    = LTRIM(RTRIM(@Command));
							SET @Filter     = LTRIM(RTRIM(@Filter));
							SET @FromTime   = LTRIM(RTRIM(@FromTime));
							SET @Key        = LTRIM(RTRIM(@Key));
							SET @Name       = LTRIM(RTRIM(@Name));
							SET @Parameter  = LTRIM(RTRIM(@Parameter));
							SET @TableName  = LTRIM(RTRIM(@TableName));
							SET @Task       = LTRIM(RTRIM(@Task));
							SET @TimeColumn = LTRIM(RTRIM(@TimeColumn));
							SET @ToTime     = LTRIM(RTRIM(@ToTime));
							SET @Type       = LTRIM(RTRIM(@Type));
							SET @Value      = LTRIM(RTRIM(@Value));

							SET @Parameter = REPLACE(@Parameter, '''''''''''''''', '''''''''''''''''''''''');

							SET @Command = LOWER(@Command);
							SET @Command = COALESCE(NULLIF(@Command, ''''''''), ''''list'''');

							IF (@Command NOT IN (''''list'''', ''''rename'''', ''''set''''))
							BEGIN
								RAISERROR(''''@Command must be ''''''''list'''''''', ''''''''rename'''''''' or ''''''''set'''''''''''', 0, 1) WITH NOWAIT;
								RETURN -1;
							END;

							SET @Type   = LOWER(@Type);

							IF (@Type NOT IN (''''configuration'''', ''''parameter'''', ''''retention'''', ''''schedule'''', ''''uninstall''''))
							BEGIN
								RAISERROR(''''@Type must be ''''''''Configuration'''''''', ''''''''Parameter'''''''', ''''''''Retention'''''''', ''''''''Schedule'''''''' or ''''''''Uninstall'''''''''''', 0, 1) WITH NOWAIT;
								RETURN -2;
							END;
			';
			SET @stmt += '
							IF (@Type = ''''configuration'''')
							BEGIN
								IF (@Command = ''''list'''')
								BEGIN
									SELECT
										c.[Key],
										c.Value
									FROM dbo.fhsmConfigurations AS c
									WHERE (1 = 1)
										AND ((c.[Key]   LIKE ''''%'''' + @Key   + ''''%'''') OR (@Key = ''''''''))
										AND ((c.[Value] LIKE ''''%'''' + @Value + ''''%'''') OR (@Value = ''''''''))
									ORDER BY c.[Key];
								END
			';
			SET @stmt += '
								ELSE IF (@Command = ''''rename'''')
								BEGIN
									IF (@Key = ''''AgentJobName'''')
									BEGIN
										IF (@NewValue = '''''''')
										BEGIN
											SET @message = ''''New name must be set @NewValue:'''''''''''' + COALESCE(@NewValue, ''''<NULL>'''') + '''''''''''''''';
											RAISERROR(@message, 0, 1) WITH NOWAIT;
											RETURN -11;
										END;

										IF NOT EXISTS (
											SELECT *
											FROM msdb.dbo.sysjobs AS sj
											WHERE (sj.name = @Value)
										)
										BEGIN
											SET @message = ''''Agent job does not exists @Value:'''''''''''' + COALESCE(@Value, ''''<NULL>'''') + '''''''''''''''';
											RAISERROR(@message, 0, 1) WITH NOWAIT;
											RETURN -12;
										END;

										IF EXISTS (
											SELECT *
											FROM msdb.dbo.sysjobs AS sj
											WHERE (sj.name = @NewValue)
										)
										BEGIN
											SET @message = ''''Agent job name is alreay used @NewValue:'''''''''''' + COALESCE(@NewValue, ''''<NULL>'''') + '''''''''''''''';
											RAISERROR(@message, 0, 1) WITH NOWAIT;
											RETURN -13;
										END;
			';
			SET @stmt += '
										--
										-- Rename job
										--
										BEGIN
											SET @message = ''''Renaming agent job to '''''''''''' + @NewValue + '''' from '''''''''''' + @Value + '''''''''''''''';
											EXEC dbo.fhsmSPLog @name = @thisTask, @version = @version, @task = @thisTask, @type = ''''Debug'''', @message = @message;

											EXEC msdb.dbo.sp_update_job @job_name = @Value, @new_name = @NewValue;

											SET @message = ''''Renamed agent job to '''''''''''' + @NewValue + '''' from '''''''''''' + @Value + '''''''''''''''';
											EXEC dbo.fhsmSPLog @name = @thisTask, @version = @version, @task = @thisTask, @type = ''''Info'''', @message = @message;
										END;

										--
										-- Register new name
										--
										BEGIN
											WITH
											cfg([Key], Value) AS(
												SELECT
													''''AgentJobName''''
													,@NewValue
											)
											MERGE dbo.fhsmConfigurations AS tgt
											USING cfg AS src ON (src.[Key] = tgt.[Key])
											WHEN MATCHED
												THEN UPDATE
													SET tgt.Value = src.Value
											WHEN NOT MATCHED BY TARGET
												THEN INSERT([Key], Value)
												VALUES(src.[Key], src.Value);
										END;

										--
										-- Rename schedule but only if job has one schedule
										--
										BEGIN
											IF ((
												SELECT COUNT(*)
												FROM msdb.dbo.sysjobs AS sj
												INNER JOIN msdb.dbo.sysjobschedules AS sjs ON (sjs.job_id = sj.job_id)
												WHERE (sj.name = @NewValue)
											) > 1)
											BEGIN
												SET @message = ''''Can not rename schedules for agent job as more than one schedule exists'''';
												RAISERROR(@message, 0, 1) WITH NOWAIT;
												RETURN -14;
											END
											ELSE BEGIN
												SET @scheduleId = (
													SELECT sjs.schedule_id
													FROM msdb.dbo.sysjobs AS sj
													INNER JOIN msdb.dbo.sysjobschedules AS sjs ON (sjs.job_id = sj.job_id)
													WHERE (sj.name = @NewValue)
												);

												SET @message = ''''Renaming agent job schedule to '''''''''''' + @NewValue + '''' for scheduleId:'''''''''''' + COALESCE(CAST(@scheduleId AS nvarchar), ''''<NULL>'''') + '''''''''''''''';
												EXEC dbo.fhsmSPLog @name = @thisTask, @version = @version, @task = @thisTask, @type = ''''Debug'''', @message = @message;

												EXEC msdb.dbo.sp_update_schedule @schedule_id = @scheduleId, @new_name = @NewValue;

												SET @message = ''''Renamed agent job schedule to '''''''''''' + @NewValue + '''' for scheduleId:'''''''''''' + COALESCE(CAST(@scheduleId AS nvarchar), ''''<NULL>'''') + '''''''''''''''';
												EXEC dbo.fhsmSPLog @name = @thisTask, @version = @version, @task = @thisTask, @type = ''''Info'''', @message = @message;
											END;
										END;
									END
									ELSE BEGIN
										SET @message = ''''Set is not allowed for Configuration @Key:'''''''''''' + COALESCE(@Key, ''''<NULL>'''') + '''''''''''''''';
										RAISERROR(@message, 0, 1) WITH NOWAIT;
										RETURN -15;
									END;
								END
			';
			SET @stmt += '
								ELSE IF (@Command = ''''set'''')
								BEGIN
									IF (@Key = ''''AgentJobName'''')
									BEGIN
										IF NOT EXISTS (
											SELECT *
											FROM msdb.dbo.sysjobs AS sj
											WHERE (sj.name = @Value)
										)
										BEGIN
											SET @message = ''''Agent job does not exists @Value:'''''''''''' + COALESCE(@Value, ''''<NULL>'''') + '''''''''''''''';
											RAISERROR(@message, 0, 1) WITH NOWAIT;
											RETURN -16;
										END;

										WITH
										cfg([Key], Value) AS(
											SELECT
												''''AgentJobName''''
												,@Value
										)
										MERGE dbo.fhsmConfigurations AS tgt
										USING cfg AS src ON (src.[Key] = tgt.[Key])
										WHEN MATCHED
											THEN UPDATE
												SET tgt.Value = src.Value
										WHEN NOT MATCHED BY TARGET
											THEN INSERT([Key], Value)
											VALUES(src.[Key], src.Value);

										SET @message = ''''Registered agent job name to '''''''''''' + @Value + '''''''''''''''';
										EXEC dbo.fhsmSPLog @name = @thisTask, @version = @version, @task = @thisTask, @type = ''''Info'''', @message = @message;
									END
									ELSE IF (@Key = ''''BlockedProcessThreshold'''')
									BEGIN
										EXEC dbo.fhsmSPControlBlocksAndDeadlocks @Type = @Type, @Command = @Command, @Key = @Key, @Value = @Value;
									END
									ELSE BEGIN
										SET @message = ''''Set is not allowed for Configuration @Key:'''''''''''' + COALESCE(@Key, ''''<NULL>'''') + '''''''''''''''';
										RAISERROR(@message, 0, 1) WITH NOWAIT;
										RETURN -17;
									END;
								END
								ELSE BEGIN
									RAISERROR(''''Internal error - @Command not processed'''', 0, 1) WITH NOWAIT;
									RETURN -19;
								END;
							END
			';
			SET @stmt += '
							ELSE IF (@Type = ''''parameter'''')
							BEGIN
								IF (@Command = ''''list'''')
								BEGIN
									SELECT
										s.Task,
										s.Name,
										s.Parameter
									FROM dbo.fhsmSchedules AS s
									WHERE (1 = 1)
										AND ((s.Name      LIKE ''''%'''' + @Name      + ''''%'''') OR (@Name = ''''''''))
										AND ((s.Parameter LIKE ''''%'''' + @Parameter + ''''%'''') OR (@Parameter = ''''''''))
										AND ((s.Task      LIKE ''''%'''' + @Task      + ''''%'''') OR (@Task = ''''''''))
									ORDER BY s.Task, s.Name;
								END
								ELSE IF (@Command = ''''set'''')
								BEGIN
									IF NOT EXISTS (
										SELECT *
										FROM dbo.fhsmSchedules AS s
										WHERE (s.Task = @Task) AND (s.Name = @Name) AND (s.DeploymentStatus <> -1)
									)
									BEGIN
										SET @message = ''''Invalid @Task:'''''''''''' + COALESCE(NULLIF(@Task, ''''''''), ''''<NULL>'''') + '''''''''''' and @Name:'''''''''''' + COALESCE(NULLIF(@Name, ''''''''), ''''<NULL>'''') + '''''''''''''''';
										RAISERROR(@message, 0, 1) WITH NOWAIT;
										RETURN -21;
									END;

									IF (CHARINDEX(''''fhsmSP'''', @Task) = 1)
									BEGIN
										SET @spControl = ''''dbo.fhsmSPControl'''' + SUBSTRING(@Task, LEN(''''fhsmSP'''') + 1, LEN(@Task));
										IF (OBJECT_ID(@spControl) IS NOT NULL)
										BEGIN
											SET @stmt = ''''
												EXEC '''' + @spControl + '''' @Type = '''''''''''' + @Type + '''''''''''', @Command = '''''''''''' + @Command + '''''''''''', @Task = '''''''''''' + @Task + '''''''''''', @Name = '''''''''''' + @Name + '''''''''''', @Parameter = '''''''''''' + @Parameter + '''''''''''';
											'''';
											EXEC(@stmt);
										END
										ELSE BEGIN
											SET @message = ''''Control procedure does not exists for @Task:'''''''''''' + COALESCE(NULLIF(@Task, ''''''''), ''''<NULL>'''') + '''''''''''''''';
											RAISERROR(@message, 0, 1) WITH NOWAIT;
											RETURN -22;
										END;
									END
									ELSE BEGIN
										SET @message = ''''Task name is not correct configured @Task:'''''''''''' + COALESCE(NULLIF(@Task, ''''''''), ''''<NULL>'''') + '''''''''''''''';
										RAISERROR(@message, 0, 1) WITH NOWAIT;
										RETURN -28;
									END;
								END
								ELSE BEGIN
									RAISERROR(''''Internal error - @Command not processed'''', 0, 1) WITH NOWAIT;
									RETURN -29;
								END;
							END
			';
			SET @stmt += '
							ELSE IF (@Type = ''''retention'''')
							BEGIN
								IF (@Command = ''''list'''')
								BEGIN
									SELECT
										r.TableName,
										r.Enabled,
										r.Sequence,
										r.TimeColumn,
										r.IsUtc,
										r.Days,
										r.Filter
									FROM dbo.fhsmRetentions AS r
									WHERE (1 = 1)
										AND ((r.Filter     LIKE ''''%'''' + @Filter     + ''''%'''') OR (@Filter = ''''''''))
										AND ((r.TableName  LIKE ''''%'''' + @TableName  + ''''%'''') OR (@TableName = ''''''''))
										AND ((r.TimeColumn LIKE ''''%'''' + @TimeColumn + ''''%'''') OR (@TimeColumn = ''''''''))
										AND ((r.Days    <= @Days)     OR (@Days     IS NULL))
										AND ((r.Enabled  = @Enabled)  OR (@Enabled  IS NULL))
										AND ((r.IsUtc    = @IsUtc)    OR (@IsUtc    IS NULL))
										AND ((r.Sequence = @Sequence) OR (@Sequence IS NULL))
									ORDER BY r.TableName;
								END
								ELSE IF (@Command = ''''set'''')
								BEGIN
									IF NOT EXISTS (
										SELECT *
										FROM dbo.fhsmRetentions AS r
										WHERE (r.TableName = @TableName) AND (r.Sequence = @Sequence)
									)
									BEGIN
										SET @message = ''''Invalid @TableName:'''''''''''' + COALESCE(NULLIF(@TableName, ''''''''), ''''<NULL>'''') + '''''''''''' and @Sequence:'''''''''''' + COALESCE(CAST(@Sequence AS nvarchar), ''''<NULL>'''') + '''''''''''''''';
										RAISERROR(@message, 0, 1) WITH NOWAIT;
										RETURN -31;
									END;

									--
									-- Register configuration changes
									--
									BEGIN
										WITH
										conf(Id, Days, Enabled) AS(
											SELECT
												r.Id,
												COALESCE(@Days,    r.Days)    AS Days,
												COALESCE(@Enabled, r.Enabled) AS Enabled
											FROM dbo.fhsmRetentions AS r
											WHERE (r.TableName = @TableName) AND (r.Sequence = @Sequence)
										)
										MERGE dbo.fhsmRetentions AS tgt
										USING conf AS src ON (src.Id = tgt.Id)
										-- Not testing for NULL as a NULL parameter is not allowed
										WHEN MATCHED AND ((tgt.Days <> src.Days) OR (tgt.Enabled <> src.Enabled))
											THEN UPDATE
												SET
													tgt.Days    = src.Days,
													tgt.Enabled = src.Enabled
										OUTPUT
											$action,
											deleted.Days,
											deleted.Enabled,
											inserted.Days,
											inserted.Enabled
										INTO @retentionChanges;

										IF (@@ROWCOUNT <> 0)
										BEGIN
											SET @message = (
												SELECT ''''Retention for @TableName:'''''''''''' + @TableName + '''''''''''' - @Sequence:'''''''''''' + CAST(@Sequence AS nvarchar) + '''''''''''' is ''
													+ ''@Days:'''''''''''' + CAST(src.InsertedDays AS nvarchar) + '''''''''''' and ''
													+ ''@Enabled:'''''''''''' + CAST(src.InsertedEnabled AS nvarchar) + '''''''''''' ''
													+ ''- changed from ''
													+ ''@Days:'''''''''''' + CAST(src.DeletedDays AS nvarchar) + '''''''''''' and ''
													+ ''@Enabled:'''''''''''' + CAST(src.DeletedEnabled AS nvarchar) + ''''''''''''''''
												FROM @retentionChanges AS src
											);
											IF (@message IS NOT NULL)
											BEGIN
												EXEC dbo.fhsmSPLog @name = @thisTask, @version = @version, @task = @thisTask, @type = ''''Info'''', @message = @message;
											END;
										END;
									END;
								END
								ELSE BEGIN
									RAISERROR(''''Internal error - @Command not processed'''', 0, 1) WITH NOWAIT;
									RETURN -39;
								END;
							END
			';
			SET @stmt += '
							ELSE IF (@Type = ''''schedule'''')
							BEGIN
								IF (@Command = ''''list'''')
								BEGIN
									SELECT
										s.Task,
										s.Name,
										s.Enabled,
										s.ExecutionDelaySec,
										s.FromTime,
										s.ToTime,
										s.Monday,
										s.Tuesday,
										s.Wednesday,
										s.Thursday,
										s.Friday,
										s.Saturday,
										s.Sunday
									FROM dbo.fhsmSchedules AS s
									WHERE (1 = 1)
										AND ((s.Name LIKE ''''%'''' + @Name + ''''%'''') OR (@Name = ''''''''))
										AND ((s.Task LIKE ''''%'''' + @Task + ''''%'''') OR (@Task = ''''''''))
										AND ((s.Enabled            = @Enabled)           OR (@Enabled           IS NULL))
										AND ((s.ExecutionDelaySec <= @ExecutionDelaySec) OR (@ExecutionDelaySec IS NULL))
										AND ((CONVERT(nvarchar, s.FromTime, 24) >= @FromTime) OR (@FromTime = ''''''''))
										AND ((CONVERT(nvarchar, s.ToTime,   24) <= @ToTime)   OR (@ToTime   = ''''''''))
										AND ((s.Monday    = @Monday)    OR (@Monday    IS NULL))
										AND ((s.Tuesday   = @Tuesday)   OR (@Tuesday   IS NULL))
										AND ((s.Wednesday = @Wednesday) OR (@Wednesday IS NULL))
										AND ((s.Thursday  = @Thursday)  OR (@Thursday  IS NULL))
										AND ((s.Friday    = @Friday)    OR (@Friday    IS NULL))
										AND ((s.Saturday  = @Saturday)  OR (@Saturday  IS NULL))
										AND ((s.Sunday    = @Sunday)    OR (@Sunday    IS NULL))
									ORDER BY s.Task, s.Name;
								END
			';
			SET @stmt += '
								ELSE IF (@Command = ''''set'''')
								BEGIN
									IF NOT EXISTS (
										SELECT *
										FROM dbo.fhsmSchedules AS s
										WHERE (s.Task = @Task) AND (s.Name = @Name) AND (s.DeploymentStatus <> -1)
									)
									BEGIN
										SET @message = ''''Invalid @Task:'''''''''''' + COALESCE(NULLIF(@Task, ''''''''), ''''<NULL>'''') + '''''''''''' and @Name:'''''''''''' + COALESCE(NULLIF(@Name, ''''''''), ''''<NULL>'''') + '''''''''''''''';
										RAISERROR(@message, 0, 1) WITH NOWAIT;
										RETURN -41;
									END;
			';
			SET @stmt += '
									--
									-- Register configuration changes
									--
									BEGIN
										WITH
										conf(Id, Enabled, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday) AS(
											SELECT
												s.Id,
												COALESCE(@Enabled,                    s.Enabled)           AS Enabled,
												COALESCE(@ExecutionDelaySec,          s.ExecutionDelaySec) AS ExecutionDelaySec,
												COALESCE(NULLIF(@FromTime, ''''''''), s.FromTime)          AS FromTime,
												COALESCE(NULLIF(@ToTime, ''''''''),   s.ToTime)            AS ToTime,
												COALESCE(@Monday,                     s.Monday)            AS Monday,
												COALESCE(@Tuesday,                    s.Tuesday)           AS Tuesday,
												COALESCE(@Wednesday,                  s.Wednesday)         AS Wednesday,
												COALESCE(@Thursday,                   s.Thursday)          AS Thursday,
												COALESCE(@Friday,                     s.Friday)            AS Friday,
												COALESCE(@Saturday,                   s.Saturday)          AS Saturday,
												COALESCE(@Sunday,                     s.Sunday)            AS Sunday
											FROM dbo.fhsmSchedules AS s
											WHERE (s.Task = @Task) AND (s.Name = @Name) AND (s.DeploymentStatus <> -1)
										)
										MERGE dbo.fhsmSchedules AS tgt
										USING conf AS src ON (src.Id = tgt.Id)
										-- Not testing for NULL as a NULL parameter is not allowed
										WHEN MATCHED AND (
											(tgt.Enabled              <> src.Enabled)
											OR (tgt.ExecutionDelaySec <> src.ExecutionDelaySec)
											OR (tgt.FromTime          <> src.FromTime)
											OR (tgt.ToTime            <> src.ToTime)
											OR (tgt.Monday            <> src.Monday)
											OR (tgt.Tuesday           <> src.Tuesday)
											OR (tgt.Wednesday         <> src.Wednesday)
											OR (tgt.Thursday          <> src.Thursday)
											OR (tgt.Friday            <> src.Friday)
											OR (tgt.Saturday          <> src.Saturday)
											OR (tgt.Sunday            <> src.Sunday)
										)
											THEN UPDATE
												SET
													tgt.Enabled           = src.Enabled,
													tgt.ExecutionDelaySec = src.ExecutionDelaySec,
													tgt.FromTime          = src.FromTime,
													tgt.ToTime            = src.ToTime,
													tgt.Monday            = src.Monday,
													tgt.Tuesday           = src.Tuesday,
													tgt.Wednesday         = src.Wednesday,
													tgt.Thursday          = src.Thursday,
													tgt.Friday            = src.Friday,
													tgt.Saturday          = src.Saturday,
													tgt.Sunday            = src.Sunday
			';
			SET @stmt += '
										OUTPUT
											$action,
											deleted.Enabled,
											deleted.ExecutionDelaySec,
											deleted.FromTime,
											deleted.ToTime,
											deleted.Monday,
											deleted.Tuesday,
											deleted.Wednesday,
											deleted.Thursday,
											deleted.Friday,
											deleted.Saturday,
											deleted.Sunday,
											inserted.Enabled,
											inserted.ExecutionDelaySec,
											inserted.FromTime,
											inserted.ToTime,
											inserted.Monday,
											inserted.Tuesday,
											inserted.Wednesday,
											inserted.Thursday,
											inserted.Friday,
											inserted.Saturday,
											inserted.Sunday
										INTO @scheduleChanges;

										IF (@@ROWCOUNT <> 0)
										BEGIN
											SET @message = (
												SELECT ''''Schedule for @Task:'''''''''''' + @Task + '''''''''''' - @Name:'''''''''''' + @Name + '''''''''''' is ''
													+ ''@Enabled:''''''''''''           + CAST(src.InsertedEnabled AS nvarchar)           + '''''''''''', ''
													+ ''@ExecutionDelaySec:'''''''''''' + CAST(src.InsertedExecutionDelaySec AS nvarchar) + '''''''''''', ''
													+ ''@FromTime:''''''''''''          + CAST(src.InsertedFromTime AS nvarchar)          + '''''''''''', ''
													+ ''@ToTime:''''''''''''            + CAST(src.InsertedToTime AS nvarchar)            + '''''''''''', ''
													+ ''@Monday:''''''''''''            + CAST(src.InsertedMonday AS nvarchar)            + '''''''''''', ''
													+ ''@Tuesday:''''''''''''           + CAST(src.InsertedTuesday AS nvarchar)           + '''''''''''', ''
													+ ''@Wednesday:''''''''''''         + CAST(src.InsertedWednesday AS nvarchar)         + '''''''''''', ''
													+ ''@Thursday:''''''''''''          + CAST(src.InsertedThursday AS nvarchar)          + '''''''''''', ''
													+ ''@Friday:''''''''''''            + CAST(src.InsertedFriday AS nvarchar)            + '''''''''''', ''
													+ ''@Saturday:''''''''''''          + CAST(src.InsertedSaturday AS nvarchar)          + '''''''''''', ''
													+ ''@Sunday:''''''''''''            + CAST(src.InsertedSunday AS nvarchar)            + '''''''''''', ''
													+ ''- changed from ''
													+ ''@Enabled:''''''''''''           + CAST(src.DeletedEnabled AS nvarchar)            + '''''''''''', ''
													+ ''@ExecutionDelaySec:'''''''''''' + CAST(src.DeletedExecutionDelaySec AS nvarchar)  + '''''''''''', ''
													+ ''@FromTime:''''''''''''          + CAST(src.DeletedFromTime AS nvarchar)           + '''''''''''', ''
													+ ''@ToTime:''''''''''''            + CAST(src.DeletedToTime AS nvarchar)             + '''''''''''', ''
													+ ''@Monday:''''''''''''            + CAST(src.DeletedMonday AS nvarchar)             + '''''''''''', ''
													+ ''@Tuesday:''''''''''''           + CAST(src.DeletedTuesday AS nvarchar)            + '''''''''''', ''
													+ ''@Wednesday:''''''''''''         + CAST(src.DeletedWednesday AS nvarchar)          + '''''''''''', ''
													+ ''@Thursday:''''''''''''          + CAST(src.DeletedThursday AS nvarchar)           + '''''''''''', ''
													+ ''@Friday:''''''''''''            + CAST(src.DeletedFriday AS nvarchar)             + '''''''''''', ''
													+ ''@Saturday:''''''''''''          + CAST(src.DeletedSaturday AS nvarchar)           + '''''''''''', ''
													+ ''@Sunday:''''''''''''            + CAST(src.DeletedSunday AS nvarchar)             + ''''''''''''''''
												FROM @scheduleChanges AS src
											);
											IF (@message IS NOT NULL)
											BEGIN
												EXEC dbo.fhsmSPLog @name = @thisTask, @version = @version, @task = @thisTask, @type = ''''Info'''', @message = @message;
											END;
										END;
									END;
								END
								ELSE BEGIN
									RAISERROR(''''Internal error - @Command not processed'''', 0, 1) WITH NOWAIT;
									RETURN -49;
								END;
							END
			';
			SET @stmt += '
							ELSE IF (@Type = ''''uninstall'''')
							BEGIN
								IF (@Task = ''''all'''')
								BEGIN
									DECLARE oCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
									SELECT o.name
									FROM sys.schemas AS sch 
									INNER JOIN sys.objects AS o ON (o.schema_id = sch.schema_id)
									WHERE (sch.name = ''''dbo'''') AND (o.type = ''''P'''') AND (o.name LIKE ''''fhsmSPControl%'''') AND (o.name <> ''''fhsmSPControl'''')
									ORDER BY o.name;

									OPEN oCur;

									WHILE (1 = 1)
									BEGIN
										FETCH NEXT FROM oCur
										INTO @spControl;

										IF (@@FETCH_STATUS <> 0)
										BEGIN
											BREAK;
										END;

										SET @spControl = ''''dbo.'''' + @spControl;

										PRINT @spControl;

										SET @stmt = ''''
											EXEC '''' + @spControl + '''' @Type = '''''''''''' + @Type + '''''''''''', @Command = '''''''''''' + @Command + '''''''''''', @Task = '''''''''''' + @Task + '''''''''''', @Name = '''''''''''' + @Name + '''''''''''', @Parameter = '''''''''''' + @Parameter + '''''''''''';
										'''';
										EXEC(@stmt);
									END;

									CLOSE oCur;
									DEALLOCATE oCur;
								END
								ELSE IF (CHARINDEX(''''fhsmSP'''', @Task) = 1)
								BEGIN
									IF NOT EXISTS (
										SELECT *
										FROM dbo.fhsmSchedules AS s
										WHERE (s.Task = @Task) AND (s.DeploymentStatus <> -1)
									)
									BEGIN
										SET @message = ''''Invalid @Task:'''''''''''' + COALESCE(NULLIF(@Task, ''''''''), ''''<NULL>'''') + '''''''''''''''';
										RAISERROR(@message, 0, 1) WITH NOWAIT;
										RETURN -51;
									END;

									SET @spControl = ''''dbo.fhsmSPControl'''' + SUBSTRING(@Task, LEN(''''fhsmSP'''') + 1, LEN(@Task));
									IF (OBJECT_ID(@spControl) IS NOT NULL)
									BEGIN
										SET @stmt = ''''
											EXEC '''' + @spControl + '''' @Type = '''''''''''' + @Type + '''''''''''', @Command = '''''''''''' + @Command + '''''''''''', @Task = '''''''''''' + @Task + '''''''''''', @Name = '''''''''''' + @Name + '''''''''''', @Parameter = '''''''''''' + @Parameter + '''''''''''';
										'''';
										EXEC(@stmt);
									END
									ELSE BEGIN
										SET @message = ''''Control procedure does not exists for @Task:'''''''''''' + COALESCE(NULLIF(@Task, ''''''''), ''''<NULL>'''') + '''''''''''''''';
										RAISERROR(@message, 0, 1) WITH NOWAIT;
										RETURN -52;
									END;
								END
								ELSE BEGIN
									SET @message = ''''Invalid task - @Task:'''''''''''' + COALESCE(NULLIF(@Task, ''''''''), ''''<NULL>'''') + '''''''''''''''';
									RAISERROR(@message, 0, 1) WITH NOWAIT;
									RETURN -59;
								END;
							END
			';
			SET @stmt += '
							ELSE BEGIN
								RAISERROR(''''Internal error - @Type not processed'''', 0, 1) WITH NOWAIT;
								RETURN -999;
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
		-- Register extended properties on the stored procedure dbo.fhsmSPControl
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPControl';

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
	END;

	--
	-- Create or alter stored procedure dbo.fhsmSPControlCleanup
	--
	BEGIN
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @stmt nvarchar(max);

				IF OBJECT_ID(''dbo.fhsmSPControlCleanup'', ''P'') IS NULL
				BEGIN
					RAISERROR(''Creating stub stored procedure dbo.fhsmSPControlCleanup'', 0, 1) WITH NOWAIT;

					EXEC(''CREATE PROC dbo.fhsmSPControlCleanup AS SELECT ''''dummy'''' AS Txt'');
				END;

				--
				-- Alter dbo.fhsmSPControlCleanup
				--
				BEGIN
					RAISERROR(''Alter stored procedure dbo.fhsmSPControlCleanup'', 0, 1) WITH NOWAIT;

					SET @stmt = ''
						ALTER PROC dbo.fhsmSPControlCleanup(
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
							SET @version = ''''' + @version + ''''';
			';
			SET @stmt += '
							IF (@Type = ''''Parameter'''')
							BEGIN
								IF (@Command = ''''set'''')
								BEGIN
									SET @Parameter = NULLIF(@Parameter, '''''''');

									IF NOT EXISTS (
										SELECT *
										FROM dbo.fhsmSchedules AS s
										WHERE (s.Task = @Task) AND (s.Name = @Name) AND (s.DeploymentStatus <> -1)
									)
									BEGIN
										SET @message = ''''Invalid @Task:'''''''''''' + COALESCE(NULLIF(@Task, ''''''''), ''''<NULL>'''') + '''''''''''' and @Name:'''''''''''' + COALESCE(NULLIF(@Name, ''''''''), ''''<NULL>'''') + '''''''''''''''';
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
												SELECT ''''Parameter is '''''''''''' + COALESCE(src.InsertedParameter, ''''<NULL>'''') + '''''''''''' - changed from '''''''''''' + COALESCE(src.DeletedParameter, ''''<NULL>'''') + ''''''''''''''''
												FROM @parameterChanges AS src
											);
											IF (@message IS NOT NULL)
											BEGIN
												EXEC dbo.fhsmSPLog @name = @Name, @version = @version, @task = @thisTask, @type = ''''Info'''', @message = @message;
											END;
										END;
									END;
			';
			SET @stmt += '
								END
								ELSE BEGIN
									SET @message = ''''Illegal Combination of @Type:'''''''''''' + COALESCE(@Type, ''''<NULL>'''') + '''''''''''' and @Command:'''''''''''' + COALESCE(@Command, ''''<NULL>'''') + '''''''''''''''';
									RAISERROR(@message, 0, 1) WITH NOWAIT;
									RETURN -19;
								END;
							END
			';
			SET @stmt += '
							ELSE IF (@Type = ''''Uninstall'''')
							BEGIN
								--
								-- Place holder
								--
								SET @Type = @Type;
							END
			';
			SET @stmt += '
							ELSE BEGIN
								SET @message = ''''Illegal @Type:'''''''''''' + COALESCE(@Type, ''''<NULL>'''') + '''''''''''''''';
								RAISERROR(@message, 0, 1) WITH NOWAIT;
								RETURN -999;
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
		-- Register extended properties on the stored procedure dbo.fhsmSPControlCleanup
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPControlCleanup';

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
	END;

	--
	-- Create or alter stored procedure dbo.fhsmSPLog
	--
	BEGIN
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
							,@id int = NULL OUTPUT
						)
						AS
						BEGIN
							SET NOCOUNT ON;

							DECLARE @printMessage nvarchar(max);

							SET @printMessage = @name + '''': '''' + COALESCE(@version, ''''N.A.'''') + '''': '''' + @task + '''': '''' + @type + '''': '''' + @message;
							PRINT @printMessage;

							IF (@id IS NULL)
							BEGIN
								INSERT INTO dbo.fhsmLog(Name, Version, Task, Type, Message)
								VALUES (@name, @version, @task, @type, @message);

								SET @id = SCOPE_IDENTITY();
							END
							ELSE BEGIN
								UPDATE l
								SET
									l.Version = @version
								FROM dbo.fhsmLog AS l
								WHERE (l.Id = @id);
							END;

							RETURN @id;
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
	END;

	--
	-- Create or alter stored procedure dbo.fhsmSPProcessing
	--
	BEGIN
		BEGIN
			SET @stmt = '
				USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

				DECLARE @stmt nvarchar(max);

				IF OBJECT_ID(''dbo.fhsmSPProcessing'', ''P'') IS NULL
				BEGIN
					RAISERROR(''Creating stub stored procedure dbo.fhsmSPProcessing'', 0, 1) WITH NOWAIT;

					EXEC(''CREATE PROC dbo.fhsmSPProcessing AS SELECT ''''dummy'''' AS Txt'');
				END;

				--
				-- Alter dbo.fhsmSPProcessing
				--
				BEGIN
					RAISERROR(''Alter stored procedure dbo.fhsmSPProcessing'', 0, 1) WITH NOWAIT;

					SET @stmt = ''
						ALTER PROC dbo.fhsmSPProcessing(
							@name nvarchar(128)
							,@task nvarchar(128)
							,@version nvarchar(128)
							,@type int
							,@timestampUTC datetime
							,@timestamp datetime
							,@id int = NULL OUTPUT
						)
						AS
						BEGIN
							SET NOCOUNT ON;

							IF (@id IS NULL)
							BEGIN
								INSERT INTO dbo.fhsmProcessing(Name, Task, Version, Type, StartedTimestampUTC, StartedTimestamp)
								SELECT @name, @task, @version, @type, @timestampUTC, @timestamp;

								SET @id = SCOPE_IDENTITY();
							END
							ELSE BEGIN
								UPDATE p
								SET
									p.Version           = @version,
									p.EndedTimestampUTC = @timestampUTC,
									p.EndedTimestamp    = @timestamp
								FROM dbo.fhsmProcessing AS p
								WHERE (p.Id = @id);
							END;

							RETURN @id;
						END;
					'';
					EXEC(@stmt);
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPProcessing
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPProcessing';

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
	END;

	--
	-- Create or alter stored procedure dbo.fhsmSPCleanup
	--
	BEGIN
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
							DECLARE @parameter nvarchar(max);
							DECLARE @parameterTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
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
							-- Get the parameter for the command
							--
							BEGIN
								SET @parameter = dbo.fhsmFNGetTaskParameter(@thisTask, @name);

								INSERT INTO @parameterTable([Key], Value)
								SELECT
									(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''''='''') AS s WHERE (s.Part = 1)) AS [Key]
									,(SELECT s.Txt FROM dbo.fhsmFNSplitString(p.Txt, ''''='''') AS s WHERE (s.Part = 2)) AS Value
								FROM dbo.fhsmFNSplitString(@parameter, '''';'''') AS p;

								SET @bulkSizeStr = (SELECT pt.Value FROM @parameterTable AS pt WHERE (pt.[Key] = ''''@BulkSize''''));
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
											+ CAST(@rowsDeleted AS nvarchar) + '''' records in table '''' + @tableName + '''' sequence '''' + CAST(@sequence AS nvarchar) + COALESCE('''' Filter:['''' + @filter + '''']'''', '''''''')
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
											+ CAST(@rowsDeletedTotal AS nvarchar) + '''' records in table '''' + @tableName + '''' sequence '''' + CAST(@sequence AS nvarchar) + COALESCE('''' Filter:['''' + @filter + '''']'''', '''''''')
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
				schedules(Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameter) AS(
					SELECT
						1													AS Enabled
						,0													AS DeploymentStatus
						,''Cleanup data''									AS Name
						,PARSENAME(''dbo.fhsmSPCleanup'', 1)				AS Task
						,12 * 60 * 60										AS ExecutionDelaySec
						,CAST(''1900-1-1T23:00:00.0000'' AS datetime2(0))	AS FromTime
						,CAST(''1900-1-1T23:59:59.0000'' AS datetime2(0))	AS ToTime
						,1, 1, 1, 1, 1, 1, 1								-- Monday..Sunday
						,''@BulkSize = 5000''								AS Parameter
				)
				MERGE dbo.fhsmSchedules AS tgt
				USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
				WHEN NOT MATCHED BY TARGET
					THEN INSERT(Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameter)
					VALUES(src.Enabled, src.DeploymentStatus, src.Name, src.Task, src.ExecutionDelaySec, src.FromTime, src.ToTime, src.Monday, src.Tuesday, src.Wednesday, src.Thursday, src.Friday, src.Saturday, src.Sunday, src.Parameter);
			';
			EXEC(@stmt);
		END;
	END;

	--
	-- Create or alter stored procedure dbo.fhsmSPSchedules
	--
	BEGIN
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
							DECLARE @logId int;
							DECLARE @message nvarchar(max);
							DECLARE @monday bit, @tuesday bit, @wednesday bit, @thursday bit, @friday bit, @saturday bit, @sunday bit;
							DECLARE @name nvarchar(128);
							DECLARE @now datetime;
							DECLARE @nowUTC datetime;
							DECLARE @parameter nvarchar(max);
							DECLARE @processingEnded datetime;
							DECLARE @processingEndedUTC datetime;
							DECLARE @processingId int;
							DECLARE @stmt nvarchar(max);
							DECLARE @task nvarchar(128);
							DECLARE @thisTask nvarchar(128);
							DECLARE @timeNow time(0);
							DECLARE @toTime time(0);
							DECLARE @version nvarchar(128);

							SET @thisTask = OBJECT_NAME(@@PROCID);

							DECLARE sCur CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
							SELECT s.Enabled, s.Id, s.Name, s.Task, s.Parameter, s.ExecutionDelaySec, s.FromTime, s.ToTime, s.Monday, s.Tuesday, s.Wednesday, s.Thursday, s.Friday, s.Saturday, s.Sunday, s.LastStartedUTC, s.LastExecutedUTC
							FROM dbo.fhsmSchedules AS s
							WHERE (s.DeploymentStatus = 0)
							ORDER BY s.Task, s.Name;

							OPEN sCur;
			';
			SET @stmt += '

							WHILE (1 = 1)
							BEGIN
								FETCH NEXT FROM sCur
								INTO @enabled, @id, @name, @task, @parameter, @executionDelaySec, @fromTime, @toTime, @monday, @tuesday, @wednesday, @thursday, @friday, @saturday, @sunday, @lastStartedUTC, @lastExecutedUTC;

								IF (@@FETCH_STATUS <> 0)
								BEGIN
									BREAK;
								END;

								--
								-- NULL parameter if it is an empty string. Makes the log nicer
								--
								SET @parameter = NULLIF(@parameter, '''''''');

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
			';
			SET @stmt += '
									BEGIN TRY;
										UPDATE s
										SET s.LastStartedUTC = @nowUTC
										FROM dbo.fhsmSchedules AS s
										WHERE (s.Id = @id);

										--
										-- Insert Processing record and remember the @id in the variable @processingId
										--
										SET @processingId = NULL;
										EXEC dbo.fhsmSPProcessing @name = @name, @task = @task, @version = NULL, @type = 0, @timestampUTC = @nowUTC, @timestamp = @now, @id = @processingId OUTPUT;

										--
										-- Insert Debug message and remember the @id in the variable @logId
										--
										SET @logId = NULL;
										SET @message = @thisTask + CASE WHEN (@test = 1) THEN '''' TEST'''' ELSE '''''''' END + '''' executing '''' + @task + '''' - '''' + @name + COALESCE('''' - '''' + @parameter, '''''''');
										EXEC dbo.fhsmSPLog @name = @name, @version = NULL, @task = @task, @type = ''''Debug'''', @message = @message, @id = @logId OUTPUT;

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

										--
										-- Update Processing record from before execution with @version, @processingEndedUTC and @processingEnded
										--
										SELECT
											@processingEndedUTC = SYSUTCDATETIME()
											,@processingEnded = SYSDATETIME();
										EXEC dbo.fhsmSPProcessing @name = @name, @task = @task, @version = @version, @type = 0, @timestampUTC = @processingEndedUTC, @timestamp = @processingEnded, @id = @processingId OUTPUT;

										--
										-- Update Debug log from before execution with @version
										--
										SET @message = @thisTask + CASE WHEN (@test = 1) THEN '''' TEST'''' ELSE '''''''' END + '''' executing '''' + @task + '''' - '''' + @name + COALESCE('''' - '''' + @parameter, '''''''');
										EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @task, @type = ''''Debug'''', @message = @message, @id = @logId OUTPUT;

										--
										-- Insert Info message
										--
										SET @message = @thisTask + CASE WHEN (@test = 1) THEN '''' TEST'''' ELSE '''''''' END + '''' executed '''' + @task + '''' - '''' + @name + COALESCE('''' - '''' + @parameter, '''''''');
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
	END;

	--
	-- Create or alter stored procedure dbo.fhsmSPUpdateDimensions
	--
	BEGIN
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
							SET @productVersion1 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));
							SET @productStartPos = @productEndPos + 1;
							SET @productEndPos = CHARINDEX(''''.'''', @productVersion, @productStartPos);
							SET @productVersion2 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));
							SET @productStartPos = @productEndPos + 1;
							SET @productEndPos = CHARINDEX(''''.'''', @productVersion, @productStartPos);
							SET @productVersion3 = dbo.fhsmFNTryParseAsInt(SUBSTRING(@productVersion, @productStartPos, @productEndPos - @productStartPos));

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
								SELECT DISTINCT
									d.SrcTable
									,d.SrcColumn1, NULLIF(d.SrcColumn2, '''''''') AS SrcColumn2, NULLIF(d.SrcColumn3, '''''''') AS SrcColumn3
									,NULLIF(d.SrcColumn4, '''''''') AS SrcColumn4, NULLIF(d.SrcColumn5, '''''''') AS SrcColumn5, NULLIF(d.SrcColumn6, '''''''') AS SrcColumn6
								FROM dbo.fhsmDimensions AS d
								INNER JOIN (
									SELECT DISTINCT d.DimensionName
									FROM dbo.fhsmDimensions AS d
								) AS modifiedSrcTables ON (modifiedSrcTables.DimensionName = d.DimensionName)
								WHERE (COALESCE(d.CreateAutoIndex, 1) = 1)
								ORDER BY d.SrcTable, SrcColumn6 DESC, SrcColumn5 DESC, SrcColumn4 DESC, SrcColumn3 DESC, SrcColumn2 DESC, d.SrcColumn1 DESC;

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
									END;

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
										,RawTime AS (
											SELECT
												Nums.n - 1 AS TimeKey
												,(Nums.n - 1) / (60 * 60) AS Hour
												,((Nums.n - 1) / 60) % 60 AS Minute
												,(Nums.n - 1) % 60 AS Second
											FROM Nums
											WHERE Nums.n <= (24 * 60 * 60)
										)
										SELECT
											rt.TimeKey
											,rt.Hour
											,rt.Minute
											,rt.Second
											,RIGHT(''''''''''''''''0'''''''''''''''' + CAST(rt.Hour AS nvarchar), 2)
												+ '''''''''''''''':''''''''''''''''
												+ RIGHT(''''''''''''''''0'''''''''''''''' + CAST(rt.Minute AS nvarchar), 2)
												+ '''''''''''''''':''''''''''''''''
												+ RIGHT(''''''''''''''''0'''''''''''''''' + CAST(rt.Second AS nvarchar), 2)
											AS Time
										FROM RawTime AS rt
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
												+ COALESCE('''', '''' + CASE @srcColumn2 WHEN '''''''' THEN '''''''''''''''''''''''' ELSE @srcColumn2 END + '''' COLLATE DATABASE_DEFAULT AS '''' + QUOTENAME(@outputColumn2), '''''''')
												+ COALESCE('''', '''' + CASE @srcColumn3 WHEN '''''''' THEN '''''''''''''''''''''''' ELSE @srcColumn3 END + '''' COLLATE DATABASE_DEFAULT AS '''' + QUOTENAME(@outputColumn3), '''''''')
												+ COALESCE('''', '''' + CASE @srcColumn4 WHEN '''''''' THEN '''''''''''''''''''''''' ELSE @srcColumn4 END + '''' COLLATE DATABASE_DEFAULT AS '''' + QUOTENAME(@outputColumn4), '''''''')
												+ COALESCE('''', '''' + CASE @srcColumn5 WHEN '''''''' THEN '''''''''''''''''''''''' ELSE @srcColumn5 END + '''' COLLATE DATABASE_DEFAULT AS '''' + QUOTENAME(@outputColumn5), '''''''')
												+ COALESCE('''', '''' + CASE @srcColumn6 WHEN '''''''' THEN '''''''''''''''''''''''' ELSE @srcColumn6 END + '''' COLLATE DATABASE_DEFAULT AS '''' + QUOTENAME(@outputColumn6), '''''''') + ''''
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
	END;

	--
	-- Create views
	--
	BEGIN
		--
		-- Create view @pbiSchema.[Configurations]
		--
		BEGIN
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
		END;

		--
		-- Create view @pbiSchema.[Log]
		--
		BEGIN
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
							,l.TimestampUTC, l.Timestamp
							,CAST(l.Timestamp AS date) AS Date
							,(DATEPART(HOUR, l.Timestamp) * 60 * 60) + (DATEPART(MINUTE, l.Timestamp) * 60) + (DATEPART(SECOND, l.Timestamp)) AS TimeKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(l.Task, l.Name, l.Version, DEFAULT, DEFAULT, DEFAULT) AS k) AS TaskNameVersionKey
						FROM dbo.fhsmLog AS l
						WHERE (1 = 1)
							AND (l.TimestampUTC > DATEADD(DAY, -1, (SELECT MAX(lMax.TimestampUTC) FROM dbo.fhsmLog AS lMax)))
							AND (
								(l.Type <> ''''Debug'''')
								OR (
									(l.Type = ''''Debug'''')
									AND (l.Version IS NOT NULL)
								)
							);
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
		END;

		--
		-- Create view @pbiSchema.[Processing]
		--
		BEGIN
			BEGIN
				SET @stmt = '
					USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';
			
					IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Processing') + ''', ''V'') IS NULL
					BEGIN
						RAISERROR(''Creating stub view ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Processing') + ''', 0, 1) WITH NOWAIT;

						EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Processing') + ' AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

					DECLARE @stmt nvarchar(max);

					RAISERROR(''Alter view ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Processing') + ''', 0, 1) WITH NOWAIT;

					SET @stmt = ''
						ALTER VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Processing') + '
						AS
						SELECT
							p.Id
							,p.Type
							,DATEDIFF(MILLISECOND, p.StartedTimestampUTC, p.EndedTimestampUTC) AS DurationInMSec
							,CAST(p.StartedTimestamp AS date) AS Date
							,(DATEPART(HOUR, p.StartedTimestamp) * 60 * 60) + (DATEPART(MINUTE, p.StartedTimestamp) * 60) + (DATEPART(SECOND, p.StartedTimestamp)) AS TimeKey
							,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(p.Task, p.Name, p.Version, DEFAULT, DEFAULT, DEFAULT) AS k) AS TaskNameVersionKey
						FROM dbo.fhsmProcessing AS p
						WHERE (p.EndedTimestampUTC IS NOT NULL);
					'';
					EXEC(@stmt);
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on fact view @pbiSchema.[Processing]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Processing');

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
		-- Create view @pbiSchema.[Retentions]
		--
		BEGIN
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
							,CASE r.Enabled
								WHEN 0 THEN ''''No''''
								WHEN 1 THEN ''''Yes''''
							END AS EnabledTxt
							,r.TableName AS [Table]
							,r.Filter
							,r.TimeColumn
							,r.IsUtc AS [IsUTC]
							,r.Days
							,r.LastStartedUTC
							,r.LastExecutedUTC
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
		END;

		--
		-- Create view @pbiSchema.[Schedules]
		--
		BEGIN
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
							,CASE s.Enabled
								WHEN 0 THEN ''''No''''
								WHEN 1 THEN ''''Yes''''
							END AS EnabledTxt
							,s.Name
							,s.Task
							,s.Parameter
							,s.ExecutionDelaySec
							,s.FromTime
							,s.ToTime
							,s.Monday
							,CASE s.Monday
								WHEN 0 THEN ''''No''''
								WHEN 1 THEN ''''Yes''''
							END AS MondayTxt
							,s.Tuesday
							,CASE s.Tuesday
								WHEN 0 THEN ''''No''''
								WHEN 1 THEN ''''Yes''''
							END AS TuesdayTxt
							,s.Wednesday
							,CASE s.Wednesday
								WHEN 0 THEN ''''No''''
								WHEN 1 THEN ''''Yes''''
							END AS WednesdayTxt
							,s.Thursday
							,CASE s.Thursday
								WHEN 0 THEN ''''No''''
								WHEN 1 THEN ''''Yes''''
							END AS ThursdayTxt
							,s.Friday
							,CASE s.Friday
								WHEN 0 THEN ''''No''''
								WHEN 1 THEN ''''Yes''''
							END AS FridayTxt
							,s.Saturday
							,CASE s.Saturday
								WHEN 0 THEN ''''No''''
								WHEN 1 THEN ''''Yes''''
							END AS SaturdayTxt
							,s.Sunday
							,CASE s.Sunday
								WHEN 0 THEN ''''No''''
								WHEN 1 THEN ''''Yes''''
							END AS SundayTxt
							,s.LastStartedUTC
							,s.LastExecutedUTC
							,s.LastErrorMessage
						FROM dbo.fhsmSchedules AS s
						WHERE (s.DeploymentStatus = 0);
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
		END;

		--
		-- Create view @pbiSchema.[Junk dimensions]
		--
		BEGIN
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
	END;

	--
	-- Create SQL agent job if it not already exists
	--
	IF (@createSQLAgentJob = 1)
		AND NOT EXISTS (
			SELECT *
			FROM msdb.dbo.sysjobs AS sj
			WHERE (sj.name = @fhsqlAgentJobName)
		)
	BEGIN
		SET @stmt = '
			RAISERROR(''Creating SQL agent job ' + @fhSQLMonitorDatabase + ''', 0, 1) WITH NOWAIT;

			EXEC msdb.dbo.sp_add_job
				@job_name = N''' + @fhsqlAgentJobName + '''
				,@enabled = 0
				,@notify_level_eventlog = 0
				,@notify_level_email = 2
				,@notify_level_page = 2
				,@delete_level = 0;

			EXEC msdb.dbo.sp_add_jobserver
				@job_name=N''' + @fhsqlAgentJobName + '''
				,@server_name = N''' + @@SERVERNAME + ''';

			EXEC msdb.dbo.sp_add_jobstep
				@job_name = N''' + @fhsqlAgentJobName + '''
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
				@job_name = N''' + @fhsqlAgentJobName + '''
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
				@job_name = N''' + @fhsqlAgentJobName + '''
				,@name = N''' + @fhsqlAgentJobName + '''
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

	--
	-- Register the agent job name in dbo.fhsmConfigurations
	--
	BEGIN
		SET @stmt = '
			USE ' + QUOTENAME(@fhSQLMonitorDatabase) + ';

			WITH
			cfg([Key], Value) AS(
				SELECT
					''AgentJobName''
					,''' + @fhsqlAgentJobName + '''
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
END;
