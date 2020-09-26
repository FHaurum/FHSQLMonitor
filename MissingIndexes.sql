SET NOCOUNT ON;

--
-- Test if we are in a database with FHSM registered
--
IF (dbo.fhsmFNIsValidInstallation() = 0)
BEGIN
	RAISERROR('Can not install as it appears the database is not correct installed', 0, 1) WITH NOWAIT;
END
ELSE BEGIN
	--
	-- Declare variables
	--
	BEGIN
		DECLARE @myUserName nvarchar(128);
		DECLARE @nowUTC datetime;
		DECLARE @nowUTCStr nvarchar(128);
		DECLARE @objectName nvarchar(128);
		DECLARE @objName nvarchar(128);
		DECLARE @pbiSchema nvarchar(128);
		DECLARE @schName nvarchar(128);
		DECLARE @stmt nvarchar(max);
		DECLARE @version nvarchar(128);

		SET @myUserName = SUSER_NAME();
		SET @nowUTC = SYSUTCDATETIME();
		SET @nowUTCStr = CONVERT(nvarchar(128), @nowUTC, 126);
		SET @pbiSchema = dbo.fhsmFNGetConfiguration('PBISchema');
		SET @version = '1.0';
	END;

	--
	-- Create tables
	--
	BEGIN
		--
		-- Create table dbo.fhsmMissingIndexes if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmMissingIndexes', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmMissingIndexes', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmMissingIndexes(
				Id int identity(1,1) NOT NULL
				,DatabaseName nvarchar(128) NOT NULL
				,SchemaName nvarchar(128) NOT NULL
				,ObjectName nvarchar(128) NOT NULL
				,EqualityColumns nvarchar(4000) NULL
				,InequalityColumns nvarchar(4000) NULL
				,IncludedColumns nvarchar(4000) NULL
				,UniqueCompiles bigint NULL
				,UserSeeks bigint NOT NULL
				,UserScans bigint NOT NULL
				,LastUserSeek datetime NULL
				,LastUserScan datetime NULL
				,AvgTotalUserCost float NOT NULL
				,AvgUserImpact float NOT NULL
				,SystemSeeks bigint NOT NULL
				,SystemScans bigint NOT NULL
				,LastSystemSeek datetime NULL
				,LastSystemScan datetime NULL
				,AvgTotalSystemCost float NOT NULL
				,AvgSystemImpact float NOT NULL
				,LastSQLServiceRestart datetime NOT NULL
				,TimestampUTC datetime NOT NULL
				,Timestamp datetime NOT NULL
				,CONSTRAINT PK_fhsmMissingIndexes PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexes_TimestampUTC ON dbo.fhsmMissingIndexes(TimestampUTC);
			CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexes_Timestamp ON dbo.fhsmMissingIndexes(Timestamp);
			CREATE NONCLUSTERED INDEX NC_fhsmMissingIndexes_DatabaseName_SchemaName_ObjectName_IndexName ON dbo.fhsmMissingIndexes(DatabaseName, SchemaName, ObjectName);
		END;

		--
		-- Register extended properties on the table dbo.fhsmMissingIndexes
		--
		BEGIN
			SET @objectName = 'dbo.fhsmMissingIndexes';
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
		-- Create fact view @pbiSchema.[Missing indexes]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Missing indexes') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Missing indexes') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Missing indexes') + '
				AS
				SELECT
					a.EqualityColumns
					,a.InequalityColumns
					,a.IncludedColumns
					,a.UniqueCompiles
					,a.UserSeeks
					,a.UserScans
					,a.LastUserSeek
					,a.LastUserScan
					,a.AvgTotalUserCost
					,a.AvgUserImpact
					,a.SystemSeeks
					,a.SystemScans
					,a.LastSystemSeek
					,a.LastSystemScan
					,a.AvgTotalSystemCost
					,a.AvgSystemImpact
					,a.Date
					,a.TimeKey
					,a.DatabaseKey
					,a.SchemaKey
					,a.ObjectKey
				FROM (
					SELECT
						mi.EqualityColumns
						,mi.InequalityColumns
						,mi.IncludedColumns
						,mi.UniqueCompiles
						,mi.UserSeeks
						,mi.UserScans
						,mi.LastUserSeek
						,mi.LastUserScan
						,mi.AvgTotalUserCost
						,mi.AvgUserImpact
						,mi.SystemSeeks
						,mi.SystemScans
						,mi.LastSystemSeek
						,mi.LastSystemScan
						,mi.AvgTotalSystemCost
						,mi.AvgSystemImpact
						,CAST(mi.Timestamp AS date) AS Date
						,(DATEPART(HOUR, mi.Timestamp) * 60 * 60) + (DATEPART(MINUTE, mi.Timestamp) * 60) + (DATEPART(SECOND, mi.Timestamp)) AS TimeKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(mi.DatabaseName, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(mi.DatabaseName, mi.SchemaName, DEFAULT, DEFAULT) AS k) AS SchemaKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(mi.DatabaseName, mi.SchemaName, mi.ObjectName, DEFAULT) AS k) AS ObjectKey
						,rankedUTC.Rnk
						,LEAD(rankedUTC.Rnk) OVER(PARTITION BY mi.DatabaseName, mi.SchemaName, mi.ObjectName, mi.EqualityColumns, mi.InequalityColumns, mi.IncludedColumns ORDER BY mi.TimestampUTC) AS NextRnk
					FROM dbo.fhsmMissingIndexes AS mi
					CROSS APPLY (
						SELECT
							distUTC.TimestampUTC
							,ROW_NUMBER() OVER(ORDER BY distUTC.TimestampUTC) AS Rnk
						FROM (
							SELECT DISTINCT mi2.TimestampUTC
							FROM dbo.fhsmMissingIndexes AS mi2
						) distUTC
					) AS rankedUTC
					WHERE (
							(mi.DatabaseName <> ''<HeartBeat>'')
							OR (mi.SchemaName <> ''<HeartBeat>'')
							OR (mi.ObjectName <> ''<HeartBeat>'')
						)
						AND (mi.TimestampUTC = rankedUTC.TimestampUTC)
				) AS a
				WHERE
					((a.Rnk + 1) <> a.NextRnk)
					OR (a.NextRnk IS NULL);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Missing indexes]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Missing indexes');
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
		-- Create stored procedure dbo.fhsmSPMissingIndexes
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPMissingIndexes'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPMissingIndexes AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPMissingIndexes (
					@name nvarchar(128)
				)
				AS
				BEGIN
					SET NOCOUNT ON;

					DECLARE @now datetime;
					DECLARE @nowUTC datetime;
					DECLARE @parameters nvarchar(max);
					DECLARE @stmt nvarchar(max);
					DECLARE @thisTask nvarchar(128);

					SET @thisTask = OBJECT_NAME(@@PROCID);

					--
					-- Get the parametrs for the command
					--
					BEGIN
						SET @parameters = dbo.fhsmFNGetTaskParameter(@thisTask, @name);
					END;

					--
					-- Collect data
					--
					BEGIN
						SET @now = SYSDATETIME();
						SET @nowUTC = SYSUTCDATETIME();

						SET @stmt = ''
							SELECT
								PARSENAME(mid.statement, 3) AS DatabaseName
								,PARSENAME(mid.statement, 2) AS SchemaName
								,PARSENAME(mid.statement, 1) AS ObjectName
								,mid.equality_columns AS EqualityColumns
								,mid.inequality_columns AS InequalityColumns
								,mid.included_columns AS IncludedColumns
								,migs.unique_compiles AS UniqueCompiles
								,migs.user_seeks AS UserSeeks
								,migs.user_scans AS UserScans
								,migs.last_user_seek AS LastUserSeek
								,migs.last_user_scan AS LastUserScan
								,migs.avg_total_user_cost AS AvgTotalUserCost
								,migs.avg_user_impact AS AvgUserImpact
								,migs.system_seeks AS SystemSeeks
								,migs.system_scans AS SystemScans
								,migs.last_system_seek AS LastSystemSeek
								,migs.last_system_scan AS LastSystemScan
								,migs.avg_total_system_cost AS AvgTotalSystemCost
								,migs.avg_system_impact AS AvgSystemImpact
								,(SELECT d.create_date FROM sys.databases AS d WITH (NOLOCK) WHERE (d.name = ''''tempdb'''')) AS LastSQLServiceRestart
								,@nowUTC, @now
							FROM sys.dm_db_missing_index_group_stats AS migs WITH (NOLOCK)
							INNER JOIN sys.dm_db_missing_index_groups AS mig WITH (NOLOCK) ON (mig.index_group_handle = migs.group_handle)
							INNER JOIN sys.dm_db_missing_index_details AS mid WITH (NOLOCK) ON (mid.index_handle = mig.index_handle)

							UNION ALL

							SELECT
								''''<HeartBeat>'''' AS DatabaseName
								,''''<HeartBeat>'''' AS SchemaName
								,''''<HeartBeat>'''' AS ObjectName
								,NULL AS EqualityColumns
								,NULL AS InequalityColumns
								,NULL AS IncludedColumns
								,NULL AS UniqueCompiles
								,-1 AS UserSeeks
								,-1 AS UserScans
								,NULL AS LastUserSeek
								,NULL AS LastUserScan
								,-1 AS AvgTotalUserCost
								,-1 AS AvgUserImpact
								,-1 AS SystemSeeks
								,-1 AS SystemScans
								,NULL AS LastSystemSeek
								,NULL AS LastSystemScan
								,-1 AS AvgTotalSystemCost
								,-1 AS AvgSystemImpact
								,(SELECT d.create_date FROM sys.databases AS d WITH (NOLOCK) WHERE (d.name = ''''tempdb'''')) AS LastSQLServiceRestart
								,@nowUTC, @now
						'';
						INSERT INTO dbo.fhsmMissingIndexes(
							DatabaseName, SchemaName, ObjectName
							,EqualityColumns, InequalityColumns, IncludedColumns
							,UniqueCompiles
							,UserSeeks, UserScans
							,LastUserSeek, LastUserScan
							,AvgTotalUserCost, AvgUserImpact
							,SystemSeeks, SystemScans
							,LastSystemSeek, LastSystemScan
							,AvgTotalSystemCost, AvgSystemImpact
							,LastSQLServiceRestart
							,TimestampUTC, Timestamp
						)
						EXEC sp_executesql
							@stmt
							,N''@now datetime, @nowUTC datetime''
							,@now = @now, @nowUTC = @nowUTC;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPMissingIndexes
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPMissingIndexes';
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
		retention(Enabled, TableName, TimeColumn, IsUtc, Days) AS(
			SELECT
				1
				,'dbo.fhsmMissingIndexes'
				,'TimestampUTC'
				,1
				,90
		)
		MERGE dbo.fhsmRetentions AS tgt
		USING retention AS src ON (src.TableName = tgt.TableName)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(Enabled, TableName, TimeColumn, IsUtc, Days)
			VALUES(src.Enabled, src.TableName, src.TimeColumn, src.IsUtc, src.Days);
	END;

	--
	-- Register schedules
	--
	BEGIN
		WITH
		schedules(Enabled, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters) AS(
			SELECT
				1
				,'Missing indexes'
				,PARSENAME('dbo.fhsmSPMissingIndexes', 1)
				,1 * 60 * 60
				,TIMEFROMPARTS(0, 0, 0, 0, 0)
				,TIMEFROMPARTS(23, 59, 59, 0, 0)
				,1, 1, 1, 1, 1, 1, 1
				,NULL
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
		dimensions(DimensionName, DimensionKey, SrcTable, SrcAlias, SrcWhere, SrcDateColumn, SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4, OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4) AS(
			SELECT
				'Database' AS DimensionName
				,'DatabaseKey' AS DimensionKey
				,'dbo.fhsmMissingIndexes' AS SrcTable
				,'src' AS SrcAlias
				,'WHERE ((src.DatabaseName <> ''<HeartBeat>'') OR (src.SchemaName <> ''<HeartBeat>'') OR (src.ObjectName <> ''<HeartBeat>''))' AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', NULL, NULL, NULL
				,'Database', NULL, NULL, NULL

			UNION ALL

			SELECT
				'Schema' AS DimensionName
				,'SchemaKey' AS DimensionKey
				,'dbo.fhsmMissingIndexes' AS SrcTable
				,'src' AS SrcAlias
				,'WHERE ((src.DatabaseName <> ''<HeartBeat>'') OR (src.SchemaName <> ''<HeartBeat>'') OR (src.ObjectName <> ''<HeartBeat>''))' AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', NULL, NULL
				,'Database', 'Schema', NULL, NULL

			UNION ALL

			SELECT
				'Object' AS DimensionName
				,'ObjectKey' AS DimensionKey
				,'dbo.fhsmMissingIndexes' AS SrcTable
				,'src' AS SrcAlias
				,'WHERE ((src.DatabaseName <> ''<HeartBeat>'') OR (src.SchemaName <> ''<HeartBeat>'') OR (src.ObjectName <> ''<HeartBeat>''))' AS SrcWhere
				,'src.[Timestamp]' AS SrcDateColumn
				,'src.[DatabaseName]', 'src.[SchemaName]', 'src.[ObjectName]', NULL
				,'Database', 'Schema', 'Object', NULL
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
			THEN INSERT(DimensionName, DimensionKey, SrcTable, SrcAlias, SrcWhere, SrcDateColumn, SrcColumn1, SrcColumn2, SrcColumn3, SrcColumn4, OutputColumn1, OutputColumn2, OutputColumn3, OutputColumn4)
			VALUES(src.DimensionName, src.DimensionKey, src.SrcTable, src.SrcAlias, src.SrcWhere, src.SrcDateColumn, src.SrcColumn1, src.SrcColumn2, src.SrcColumn3, src.SrcColumn4, src.OutputColumn1, src.OutputColumn2, src.OutputColumn3, src.OutputColumn4);
	END;

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmMissingIndexes';
	END;
END;
