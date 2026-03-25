SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableWhoIsActive bit;
	DECLARE @ignoreAutoIndex bit;

	SET @enableWhoIsActive = 0;
	SET @ignoreAutoIndex = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing WhoIsActive-002', 0, 1) WITH NOWAIT;
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
		SET @version = '2.12.0';

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
	-- Variables used in view to control the statement output
	--
	BEGIN
		DECLARE @maxSQLTextLength int;

		SET @maxSQLTextLength = 1024;
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
		-- Create dbo.fhsmWhoIsActive
		--
		IF OBJECT_ID('dbo.fhsmWhoIsActive', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmWhoIsActive', 0, 1) WITH NOWAIT;

			EXEC dbo.sp_WhoIsActive
				@format_output = 0
				,@get_transaction_info = 1
				,@get_outer_command = 1
				,@get_plans = 1
				,@return_schema = 1
				,@schema = @stmt OUTPUT;

			SET @stmt = REPLACE(@stmt, '<table_name>', QUOTENAME(DB_NAME()) + '.dbo.fhsmWhoIsActive');
			EXEC(@stmt);
		END;

		--
		-- Create index on dbo.fhsmWhoIsActive
		--
		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmWhoIsActive')) AND (i.name = 'CL_fhsmWhoIsActive_collection_time'))
		BEGIN
			SET @stmt = '
				CREATE CLUSTERED INDEX CL_fhsmWhoIsActive_collection_time ON dbo.fhsmWhoIsActive(collection_time ASC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmWhoIsActive
		--
		BEGIN
			SET @objectName = 'dbo.fhsmWhoIsActive';
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
	-- Create stored procedures
	--
	BEGIN
		--
		-- Create stored procedure dbo.fhsmSPWhoIsActive
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPWhoIsActive'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPWhoIsActive AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPWhoIsActive(
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @parameter nvarchar(max);
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);
					SET @version = ''' + @version + ''';

					SET @parameter = dbo.fhsmFNGetTaskParameter(@thisTask, @name);

					SET @parameter = REPLACE(@parameter, ''<FHSQLMonitorDatabase>'', QUOTENAME(DB_NAME()));

					SET @stmt = ''EXEC dbo.sp_WhoIsActive '' + @parameter;
					EXEC(@stmt);

					RETURN 0;
				END;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPWhoIsActive
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPWhoIsActive';
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
		-- Create stored procedure dbo.fhsmSPControlWhoIsActive
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPControlWhoIsActive'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPControlWhoIsActive AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPControlWhoIsActive (
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
					IF (@Type = ''parameter'')
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
					ELSE IF (@Type = ''uninstall'')
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
			-- Register extended properties on the stored procedure dbo.fhsmSPControlWhoIsActive
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPControlWhoIsActive';
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
		-- Create stored procedure dbo.fhsmSPViewsWhoIsActive
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPViewsWhoIsActive'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPViewsWhoIsActive AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPViewsWhoIsActive (
					@view nvarchar(128),
					@version sql_variant,
					@nowUTC datetime
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @defaultViewWhoIsActiveHours int;
					DECLARE @defaultViewWhoIsActiveRows int;
					DECLARE @hours int;
					DECLARE @message nvarchar(max);
					DECLARE @myUserName nvarchar(128);
					DECLARE @noOfRows int;
					DECLARE @nowUTCStr nvarchar(128);
					DECLARE @objectName nvarchar(128);
					DECLARE @pbiSchema nvarchar(128);
					DECLARE @stmt nvarchar(max);

					SET @myUserName = SUSER_NAME();

					SET @nowUTCStr = CONVERT(nvarchar(128), @nowUTC, 126);

					SET @defaultViewWhoIsActiveHours = 24;
					SET @defaultViewWhoIsActiveRows = 1000;

					SET @pbiSchema = (
						SELECT c.Value
						FROM dbo.fhsmConfigurations AS c
						WHERE (c.[Key] = ''PBISchema'')
					);
					IF (@pbiSchema IS NULL)
					BEGIN
						RAISERROR(''The configuration key ''''PBISchema'''' could not be found'', 0, 1) WITH NOWAIT;
						RETURN -1;
					END;
			';
			SET @stmt += '
					IF (@view = ''WhoIsActive'')
					BEGIN
						SET @hours = (
							SELECT c.Value
							FROM dbo.fhsmConfigurations AS c
							WHERE (c.[Key] = ''View.WhoIsActive.Hours'')
						);
						IF (@hours IS NULL)
						BEGIN
							INSERT INTO dbo.fhsmConfigurations([Key], Value)
							VALUES(''View.WhoIsActive.Hours'', @defaultViewWhoIsActiveHours);

							SET @hours = @defaultViewWhoIsActiveHours;
						END;
						SET @hours = ABS(@hours);

						SET @noOfRows = (
							SELECT c.Value
							FROM dbo.fhsmConfigurations AS c
							WHERE (c.[Key] = ''View.WhoIsActive.Rows'')
						);
						IF (@noOfRows IS NULL)
						BEGIN
							INSERT INTO dbo.fhsmConfigurations([Key], Value)
							VALUES(''View.WhoIsActive.Rows'', @defaultViewWhoIsActiveRows);

							SET @noOfRows = @defaultViewWhoIsActiveRows;
						END;
						SET @noOfRows = ABS(@noOfRows);
			';
			SET @stmt += '
						--
						-- Create fact view @pbiSchema.[Who is active]
						--
						BEGIN
							BEGIN
								SET @stmt = ''
									IF OBJECT_ID('''''' + QUOTENAME(@pbiSchema) + ''.'' + QUOTENAME(''Who is active'') + '''''', ''''V'''') IS NULL
									BEGIN
										RAISERROR(''''Creating stub view '' + QUOTENAME(@pbiSchema) + ''.'' + QUOTENAME(''Who is active'') + '''''', 0, 1) WITH NOWAIT;

										EXEC(''''CREATE VIEW '' + QUOTENAME(@pbiSchema) + ''.'' + QUOTENAME(''Who is active'') + '' AS SELECT ''''''''dummy'''''''' AS Txt'''');
									END;
								'';
								EXEC(@stmt);
			';
			SET @stmt += '
								SET @message = ''Alter view '' + QUOTENAME(@pbiSchema) + ''.'' + QUOTENAME(''Who is active'') + '''';
								RAISERROR(@message, 0, 1) WITH NOWAIT;

								SET @stmt = ''
									ALTER VIEW  '' + QUOTENAME(@pbiSchema) + ''.'' + QUOTENAME(''Who is active'') + ''
									AS
									SELECT
										TOP ('' + CAST(@noOfRows AS nvarchar) + '')
										DATEDIFF(SECOND, a.collection_time, lastExecuted.Timestamp) AS SecondsSinceLastSeen
										,a.collection_time AS CollectionTime
										,a.login_time AS LoginTime
										,DATEDIFF(MILLISECOND, a.start_time, a.collection_time) AS ElapsedTimeMS
										,a.session_id AS SessionId
										,CASE
											WHEN LEN(a.sql_text) > ' + CAST(@maxSQLTextLength AS nvarchar) + ' THEN LEFT(a.sql_text, ' + CAST(@maxSQLTextLength AS nvarchar) + ') + CHAR(10) + ''''...Statement truncated''''
											ELSE a.sql_text
										END AS SQLText
										,a.sql_command AS SQLCommand
										,a.login_name AS LoginName
										,a.wait_info AS WaitInfo
										,a.tran_log_writes AS TransLogWrite
										,a.CPU - a.FirstCPU AS CPU
										,a.tempdb_allocations - a.FirstTempdbAllocations AS TempdbAllocations
										,a.blocking_session_id AS BlockingSessionId
										,a.reads - a.FirstReads AS Reads
										,a.writes - a.FirstWrites AS Writes
										,a.physical_reads - a.FirstPhysicalReads AS PhysicalReads
										,a.used_memory AS UsedMemory
										,a.status AS Status
										,a.tran_start_time AS TranStartTime
										,a.implicit_tran AS ImplicitTran
										,a.open_tran_count AS OpenTranCount
										,a.percent_complete AS PercentComplete
										,a.host_name AS HostName
										,a.program_name AS ProgramName
										,ROW_NUMBER() OVER(ORDER BY a.collection_time, (a.reads - a.FirstReads), a.session_id DESC) AS SortOrder
										,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.database_name, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
									FROM (
										SELECT
											ROW_NUMBER() OVER(PARTITION BY wia.session_id, wia.login_time, wia.start_time ORDER BY wia.collection_time DESC) AS _Rnk_
											,wia.*
											,firstWia.CPU AS FirstCPU
											,firstWia.tempdb_allocations AS FirstTempdbAllocations
											,firstWia.reads AS FirstReads
											,firstWia.writes AS FirstWrites
											,firstWia.physical_reads AS FirstPhysicalReads
										FROM dbo.fhsmWhoIsActive AS wia
										CROSS APPLY (
											SELECT TOP (1)
												fWia.CPU
												,fWia.tempdb_allocations
												,fWia.reads
												,fWia.writes
												,fWia.physical_reads
											FROM dbo.fhsmWhoIsActive AS fWia
											WHERE
												(fWia.session_id = wia.session_id)
												AND (fWia.login_time = wia.login_time)
												AND (fWia.start_time = wia.start_time)
											ORDER BY fWia.collection_time
										) AS firstWia
										WHERE (DATEDIFF(HOUR, wia.collection_time, (SELECT MAX(wia2.collection_time) FROM dbo.fhsmWhoIsActive AS wia2)) < '' + CAST(@hours AS nvarchar) + '')
											AND (wia.sql_text <> ''''sp_server_diagnostics'''')
											AND (wia.sql_text NOT LIKE ''''WAITFOR DELAY %'''')
									) AS a
									CROSS APPLY (
										SELECT TOP 1 l.Timestamp
										FROM dbo.fhsmLog AS l
										WHERE (l.Name = ''''Who is active'''')
										ORDER BY l.TimestampUTC DESC
									) AS lastExecuted
									WHERE (a._Rnk_ = 1)
									ORDER BY a.collection_time DESC;
								'';
								EXEC(@stmt);
							END;
			';
			SET @stmt += '
							--
							-- Register extended properties on fact view @pbiSchema.[Who is active]
							--
							BEGIN
								SET @objectName = QUOTENAME(@pbiSchema) + ''.'' + QUOTENAME(''Who is active'');

								SET @stmt = ''
									DECLARE @objName nvarchar(128);
									DECLARE @schName nvarchar(128);

									SET @objName = PARSENAME(@objectName, 1);
									SET @schName = PARSENAME(@objectName, 2);

									EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''''FHSMVersion'''', @propertyValue = @version;
									EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''''FHSMCreated'''', @propertyValue = @nowUTCStr;
									EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = ''''FHSMCreatedBy'''', @propertyValue = @myUserName;
									EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''''FHSMModified'''', @propertyValue = @nowUTCStr;
									EXEC dbo.fhsmSPExtendedProperties @objectType = ''''View'''', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = ''''FHSMModifiedBy'''', @propertyValue = @myUserName;
								'';
								EXEC sp_executesql
									@stmt
									,N''@objectName nvarchar(128), @version sql_variant, @nowUTCStr sql_variant, @myUserName sql_variant''
									,@objectName = @objectName
									,@version = @version
									,@nowUTCStr = @nowUTCStr
									,@myUserName = @myUserName;
							END;
						END;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPViewsWhoIsActive
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPViewsWhoIsActive';
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
	-- Create views
	--
	BEGIN
		--
		-- Create fact view @pbiSchema.[Who is active]
		--
		BEGIN
			EXEC dbo.fhsmSPViewsWhoIsActive @view = 'WhoIsActive', @version = @version, @nowUTC = @nowUTC;
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
				,'dbo.fhsmWhoIsActive'
				,1
				,'collection_time'
				,0
				,7
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
		schedules(Type, Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameter) AS(
			SELECT
				1												AS Type
				,@enableWhoIsActive								AS Enabled
				,0												AS DeploymentStatus
				,'Who is active'								AS Name
				,PARSENAME('dbo.fhsmSPWhoIsActive', 1)			AS Task
				,60												AS ExecutionDelaySec
				,CAST('1900-1-1T00:00:00.0000' AS datetime2(0))	AS FromTime
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))	AS ToTime
				,1, 1, 1, 1, 1, 1, 1							-- Monday..Sunday
				,'@format_output = 0, @get_transaction_info = 1, @get_outer_command = 1, @get_plans = 1, @destination_table = ''<FHSQLMonitorDatabase>.dbo.fhsmWhoIsActive'''
		)
		MERGE dbo.fhsmSchedules AS tgt
		USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(Type, Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameter)
			VALUES(src.Type, src.Enabled, src.DeploymentStatus, src.Name, src.Task, src.ExecutionDelaySec, src.FromTime, src.ToTime, src.Monday, src.Tuesday, src.Wednesday, src.Thursday, src.Friday, src.Saturday, src.Sunday, src.Parameter);
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
				,'dbo.fhsmWhoIsActive' AS SrcTable
				,'src' AS SrcAlias
				,NULL AS SrcWhere
				,'src.[collection_time]' AS SrcDateColumn
				,'src.[database_name]'
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
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmWhoIsActive', @ignoreAutoIndex = @ignoreAutoIndex;
	END;
END;
