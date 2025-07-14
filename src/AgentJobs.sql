SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableAgentJobs bit;

	SET @enableAgentJobs = 0;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing AgentJobs', 0, 1) WITH NOWAIT;
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
		SET @version = '2.8';

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
		-- Create table dbo.fhsmAgentJobs and indexes if they not already exists
		--
		IF OBJECT_ID('dbo.fhsmAgentJobs', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmAgentJobs', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE TABLE dbo.fhsmAgentJobs(
					Id int identity(1,1) NOT NULL
					,JobName nvarchar(128) NOT NULL
					,JobId uniqueidentifier NOT NULL
					,JobEnabled tinyint NOT NULL
					,JobDescription nvarchar(512) NULL
					,ScheduleName nvarchar(128) NULL
					,ScheduleId int NULL
					,ScheduleEnabled int NULL
					,FreqType int NULL
					,FreqInterval int NULL
					,FreqSubdayType int NULL
					,FreqSubdayInterval int NULL
					,FreqRelativeInterval int NULL
					,FreqRecurrenceFactor int NULL
					,ActiveStartDate int NULL
					,ActiveEndDate int NULL
					,ActiveStartTime int NULL
					,ActiveEndTime int NULL
					,NextRunDate int NULL
					,NextRunTime int NULL
					,TimestampUTC datetime NOT NULL
					,Timestamp datetime NOT NULL
					,CONSTRAINT PK_fhsmAgentJobs PRIMARY KEY(Id)' + @tableCompressionStmt + '
				);
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobs')) AND (i.name = 'NC_fhsmAgentJobs_TimestampUTC'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmAgentJobs_TimestampUTC] to table dbo.fhsmAgentJobs', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmAgentJobs_TimestampUTC ON dbo.fhsmAgentJobs(TimestampUTC)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmAgentJobs')) AND (i.name = 'NC_fhsmAgentJobs_Timestamp'))
		BEGIN
			RAISERROR('Adding index [NC_fhsmAgentJobs_Timestamp] to table dbo.fhsmAgentJobs', 0, 1) WITH NOWAIT;

			SET @stmt = '
				CREATE NONCLUSTERED INDEX NC_fhsmAgentJobs_Timestamp ON dbo.fhsmAgentJobs(Timestamp)' + @tableCompressionStmt + ';
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the table dbo.fhsmAgentJobs
		--
		BEGIN
			SET @objectName = 'dbo.fhsmAgentJobs';
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
		-- Create fact view @pbiSchema.[Agent jobs - grid]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs - grid') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs - grid') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs - grid') + '
				AS
				WITH
				L0   AS (SELECT 1 AS c UNION ALL SELECT 1),
				L1   AS (SELECT 1 AS c FROM L0 AS A CROSS JOIN L0 AS B),
				L2   AS (SELECT 1 AS c FROM L1 AS A CROSS JOIN L1 AS B),
				L3   AS (SELECT 1 AS c FROM L2 AS A CROSS JOIN L2 AS B),
				Nums AS (
					SELECT
						ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1 AS n
					FROM L3
				)
				SELECT
					p.JobName
					,p.JobEnabled
					,p.ScheduleId
					,p.ScheduleEnabled
					, p.[0],  p.[1],  p.[2],  p.[3],  p.[4],  p.[5],  p.[6],  p.[7],  p.[8],  p.[9]
					,p.[10], p.[11], p.[12], p.[13], p.[14], p.[15], p.[16], p.[17], p.[18], p.[19]
					,p.[20], p.[21], p.[22], p.[23]
					,p.WhenDesc
					,p.WhenDetailsDesc
					,p.ActiveDesc
					,p.Timestamp
				FROM (
			';
			SET @stmt += '
					SELECT
						a.JobName,
						n.n AS HourSlot,
						a.JobEnabled,
						a.ScheduleId,
						a.ScheduleEnabled,
						CASE a.FreqType
							WHEN   1 THEN ''Once on '' + CAST(a.ActiveStartDate AS nvarchar) + '':'' + CAST(a.ActiveStartTime AS nvarchar)
							WHEN   4 THEN ''Every '' + CASE WHEN a.FreqInterval = 1 THEN ''day'' ELSE CAST(a.FreqInterval AS nvarchar) + '' days'' END
							WHEN   8 THEN ''Every '' + CASE WHEN a.FreqRecurrenceFactor = 1 THEN ''week'' ELSE CAST(a.FreqRecurrenceFactor AS nvarchar) + '' weeks'' END
						END
						AS WhenDesc,
						CASE
							WHEN (a.FreqSubdayType = 0)          THEN ''''
							WHEN (a.FreqSubdayType = 1)          THEN ''At '' + CAST(a.ActiveStartTime AS nvarchar)
							WHEN (a.FreqSubdayType IN (2, 4, 8)) THEN ''Every '' + CAST(a.FreqSubdayInterval AS nvarchar) + '' ''
								+ CASE a.FreqSubdayType
									WHEN 2 THEN ''second''
									WHEN 4 THEN ''minute''
									WHEN 8 THEN ''hour''
								END
								+ CASE WHEN a.FreqSubdayInterval > 1 THEN ''s'' ELSE '''' END
								+ '' between '' + CAST(a.ActiveStartTime AS nvarchar) + '' and '' + CAST(a.ActiveEndTime AS nvarchar)
						END
						AS WhenDetailsDesc,
						CASE
							WHEN (a.FreqType IN (4, 8, 16, 32))
							THEN
								CASE
									WHEN (a.ActiveEndDate = CAST(''9999-12-31'' AS date)) THEN ''Starting on '' + CAST(a.ActiveStartDate AS nvarchar)
									ELSE ''Between '' + CAST(a.ActiveStartDate AS nvarchar) + '' and '' + CAST(a.ActiveEndDate AS nvarchar)
								END
							ELSE ''''
						END
						AS ActiveDesc,
						CASE a.FreqType
							WHEN 8 THEN
								SUBSTRING(
									(
										CASE WHEN (a.FreqInterval &  2) =  2 THEN CHAR(10) + ''Mon'' ELSE '''' END +
										CASE WHEN (a.FreqInterval &  4) =  4 THEN CHAR(10) + ''Tue'' ELSE '''' END +
										CASE WHEN (a.FreqInterval &  8) =  8 THEN CHAR(10) + ''Wed'' ELSE '''' END +
										CASE WHEN (a.FreqInterval & 16) = 16 THEN CHAR(10) + ''Thu'' ELSE '''' END +
										CASE WHEN (a.FreqInterval & 32) = 32 THEN CHAR(10) + ''Fri'' ELSE '''' END +
										CASE WHEN (a.FreqInterval & 64) = 64 THEN CHAR(10) + ''Sat'' ELSE '''' END +
										CASE WHEN (a.FreqInterval &  1) =  1 THEN CHAR(10) + ''Sun'' ELSE '''' END
									)
									,2
									,128
								)
							ELSE ''X''
						END
						AS DayDesc,
						a.Timestamp
					FROM (
			';
			SET @stmt += '
						SELECT
							aj.JobName
							,CAST(aj.JobEnabled AS bit)				AS JobEnabled
							,aj.ScheduleId
							,CAST(aj.ScheduleEnabled AS bit)		AS ScheduleEnabled
							,aj.FreqType
							,aj.FreqInterval
							,aj.FreqSubdayType
							,aj.FreqSubdayInterval
							,aj.FreqRecurrenceFactor
							,CONVERT(
								date,
									CAST(aj.ActiveStartDate / 10000 AS nvarchar)
									+ ''-'' + CAST((aj.ActiveStartDate / 100) % 100 AS nvarchar)
									+ ''-'' + CAST((aj.ActiveStartDate % 100) AS nvarchar),
								102
							)										AS ActiveStartDate
							,CONVERT(
								date,
									CAST(aj.ActiveEndDate / 10000 AS nvarchar)
									+ ''-'' + CAST((aj.ActiveEndDate / 100) % 100 AS nvarchar)
									+ ''-'' + CAST((aj.ActiveEndDate % 100) AS nvarchar),
								102
							)										AS ActiveEndDate
							,CONVERT(
								time(0),
									CAST(aj.ActiveStartTime / 10000 AS nvarchar)
									+ '':'' + CAST((aj.ActiveStartTime / 100) % 100 AS nvarchar)
									+ '':'' + CAST((aj.ActiveStartTime % 100) AS nvarchar),
								108
							)										AS ActiveStartTime
							,CONVERT(
								time(0),
									CAST(aj.ActiveEndTime / 10000 AS nvarchar)
									+ '':'' + CAST((aj.ActiveEndTime / 100) % 100 AS nvarchar)
									+ '':'' + CAST((aj.ActiveEndTime % 100) AS nvarchar),
								108
							)										AS ActiveEndTime
							,aj.Timestamp
						FROM dbo.fhsmAgentJobs AS aj
						WHERE (aj.TimestampUTC = (
							SELECT TOP (1) aj2.TimestampUTC
							FROM dbo.fhsmAgentJobs AS aj2
							ORDER BY aj2.TimestampUTC DESC
						))
					) AS a
					CROSS JOIN Nums AS n
					WHERE (1 = 1)
						AND (a.FreqType IN (4, 8))
						AND (CAST(GETDATE() AS date) <= a.ActiveEndDate)
						AND (n.n <= 23)
						AND (
							(
								(a.FreqSubdayType = 1)			-- At the specified time
								AND (n.n = DATEPART(HOUR, a.ActiveStartTime))
							)
							OR (
								(a.FreqSubdayType IN (2, 4))	-- Seconds and minutes
								AND (n.n BETWEEN DATEPART(HOUR, a.ActiveStartTime) AND DATEPART(HOUR, a.ActiveEndTime))
							)
							OR (
								(a.FreqSubdayType = 8)	-- Hours
								AND (n.n BETWEEN DATEPART(HOUR, a.ActiveStartTime) AND DATEPART(HOUR, a.ActiveEndTime))
								AND (((n.n - DATEPART(HOUR, a.ActiveStartTime)) % NULLIF(a.FreqSubdayInterval, 0)) = 0)
							)
						)
				) AS b
				PIVOT (
					MAX(b.DayDesc)
					FOR b.HourSlot IN (
						  [0],  [1],  [2],  [3],  [4],  [5],  [6],  [7],  [8],  [9]
						,[10], [11], [12], [13], [14], [15], [16], [17], [18], [19]
						,[20], [21], [22], [23]
					)
				) AS p
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Agent jobs - grid]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs - grid');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Agent jobs - list]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs - list') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs - list') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs - list') + '
				AS
				SELECT
					a.JobName,
					a.JobEnabled,
					a.ScheduleEnabled,
					CASE a.FreqType
						WHEN   1 THEN ''Once on '' + CAST(a.ActiveStartDate AS nvarchar) + '':'' + CAST(a.ActiveStartTime AS nvarchar)
						WHEN   4 THEN ''Every '' + CASE WHEN a.FreqInterval = 1 THEN ''day'' ELSE CAST(a.FreqInterval AS nvarchar) + '' days'' END
						WHEN   8 THEN ''Every '' + CASE WHEN a.FreqRecurrenceFactor = 1 THEN ''week'' ELSE CAST(a.FreqRecurrenceFactor AS nvarchar) + '' weeks'' END
							+ '' on ''
							+ SUBSTRING(
								(
									CASE WHEN (a.FreqInterval &  2) =  2 THEN '', Monday''    ELSE '''' END +
									CASE WHEN (a.FreqInterval &  4) =  4 THEN '', Tuesday''   ELSE '''' END +
									CASE WHEN (a.FreqInterval &  8) =  8 THEN '', Wednesday'' ELSE '''' END +
									CASE WHEN (a.FreqInterval & 16) = 16 THEN '', Thursday''  ELSE '''' END +
									CASE WHEN (a.FreqInterval & 32) = 32 THEN '', Friday''    ELSE '''' END +
									CASE WHEN (a.FreqInterval & 64) = 64 THEN '', Saturday''  ELSE '''' END +
									CASE WHEN (a.FreqInterval &  1) =  1 THEN '', Sunday''    ELSE '''' END
								)
								,3
								,128
							)
						WHEN  16 THEN ''Every '' + CASE WHEN a.FreqRecurrenceFactor = 1 THEN ''month'' ELSE CAST(a.FreqRecurrenceFactor AS nvarchar) + '' months'' END
							+ '' on day '' + CAST(a.FreqInterval AS nvarchar) + '' of that month''
						WHEN  32 THEN ''Every ''
							+ CASE a.FreqRelativeInterval
								WHEN  1 THEN ''first''
								WHEN  2 THEN ''second''
								WHEN  4 THEN ''third''
								WHEN  8 THEN ''fourth''
								WHEN 16 THEN ''last''
							END
							+ '' ''
							+ CASE a.FreqInterval
								WHEN  1 THEN ''Sunday''
								WHEN  2 THEN ''Monday''
								WHEN  3 THEN ''Tuesday''
								WHEN  4 THEN ''Wednesday''
								WHEN  5 THEN ''Thursday''
								WHEN  6 THEN ''Friday''
								WHEN  7 THEN ''Saturday''
								WHEN  8 THEN ''Day''
								WHEN  9 THEN ''Weekday''
								WHEN 10 THEN ''Weekend day''
							END
							+ '' of every '' + CASE WHEN a.FreqRecurrenceFactor = 1 THEN ''month'' ELSE CAST(a.FreqRecurrenceFactor AS nvarchar) + '' months'' END

						WHEN  64 THEN ''When SQL Server Agent starts''
						WHEN 128 THEN ''Whenever the CPUs become idle''
					END
					+ CASE
						WHEN (a.FreqSubdayType = 0)          THEN ''''
						WHEN (a.FreqSubdayType = 1)          THEN '' at '' + CAST(a.ActiveStartTime AS nvarchar)
						WHEN (a.FreqSubdayType IN (2, 4, 8)) THEN '' every '' + CAST(a.FreqSubdayInterval AS nvarchar) + '' ''
							+ CASE a.FreqSubdayType
								WHEN 2 THEN ''second''
								WHEN 4 THEN ''minute''
								WHEN 8 THEN ''hour''
							END
							+ CASE WHEN a.FreqSubdayInterval > 1 THEN ''s'' ELSE '''' END
							+ '' between '' + CAST(a.ActiveStartTime AS nvarchar) + '' and '' + CAST(a.ActiveEndTime AS nvarchar)
					END
					+ CASE
						WHEN (a.FreqType IN (4, 8, 16, 32)) THEN ''. Schedule will be used ''
							+ CASE
								WHEN (a.ActiveEndDate = CAST(''9999-12-31'' AS date)) THEN ''starting on '' + CAST(a.ActiveStartDate AS nvarchar)
								ELSE ''between '' + CAST(a.ActiveStartDate AS nvarchar) + '' and '' + CAST(a.ActiveEndDate AS nvarchar)
							END
						ELSE ''''
					END
					AS TotalDesc,
					a.Timestamp
				FROM (
			';
			SET @stmt += '
					SELECT
						aj.JobName
						,CAST(aj.JobEnabled AS bit)				AS JobEnabled
						,CAST(aj.ScheduleEnabled AS bit)		AS ScheduleEnabled
						,aj.FreqType
						,aj.FreqInterval
						,aj.FreqSubdayType
						,aj.FreqSubdayInterval
						,aj.FreqRelativeInterval
						,aj.FreqRecurrenceFactor

						,CONVERT(
							date,
								CAST(aj.ActiveStartDate / 10000 AS nvarchar)
								+ ''-'' + CAST((aj.ActiveStartDate / 100) % 100 AS nvarchar)
								+ ''-'' + CAST((aj.ActiveStartDate % 100) AS nvarchar),
							102
						)										AS ActiveStartDate
						,CONVERT(
							date,
								CAST(aj.ActiveEndDate / 10000 AS nvarchar)
								+ ''-'' + CAST((aj.ActiveEndDate / 100) % 100 AS nvarchar)
								+ ''-'' + CAST((aj.ActiveEndDate % 100) AS nvarchar),
							102
						)										AS ActiveEndDate
						,CONVERT(
							time(0),
								CAST(aj.ActiveStartTime / 10000 AS nvarchar)
								+ '':'' + CAST((aj.ActiveStartTime / 100) % 100 AS nvarchar)
								+ '':'' + CAST((aj.ActiveStartTime % 100) AS nvarchar),
							108
						)										AS ActiveStartTime
						,CONVERT(
							time(0),
								CAST(aj.ActiveEndTime / 10000 AS nvarchar)
								+ '':'' + CAST((aj.ActiveEndTime / 100) % 100 AS nvarchar)
								+ '':'' + CAST((aj.ActiveEndTime % 100) AS nvarchar),
							108
						)										AS ActiveEndTime
						,aj.Timestamp
					FROM dbo.fhsmAgentJobs AS aj
					WHERE (aj.TimestampUTC = (
						SELECT TOP (1) aj2.TimestampUTC
						FROM dbo.fhsmAgentJobs AS aj2
						ORDER BY aj2.TimestampUTC DESC
					))
				) AS a
				WHERE (1 = 1)
					AND (a.FreqType NOT IN (4, 8))
					AND (CAST(GETDATE() AS date) <= a.ActiveEndDate)
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Agent jobs - list]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs - list');
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
		-- Create stored procedure dbo.fhsmSPAgentJobs
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPAgentJobs'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPAgentJobs AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPAgentJobs (
					@name nvarchar(128)
					,@version nvarchar(128) OUTPUT
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
					SET @version = ''' + @version + ''';

					--
					-- Get the parameters for the command
					--
					BEGIN
						SET @parameters = dbo.fhsmFNGetTaskParameter(@thisTask, @name);
					END;
			';
			SET @stmt += '

					--
					-- Collect data
					--
					BEGIN
						SELECT
							@now = SYSDATETIME()
							,@nowUTC = SYSUTCDATETIME();

						INSERT INTO dbo.fhsmAgentJobs(
							JobName, JobId, JobEnabled, JobDescription
							,ScheduleName, ScheduleId, ScheduleEnabled
							,FreqType, FreqInterval, FreqSubdayType, FreqSubdayInterval, FreqRelativeInterval, FreqRecurrenceFactor
							,ActiveStartDate, ActiveEndDate, ActiveStartTime, ActiveEndTime
							,NextRunDate, NextRunTime
							,TimestampUTC, Timestamp
						)
						SELECT
							sj.name						AS JobName
							,sj.job_id					AS JobId
							,sj.enabled					AS JobEnabled
							,sj.description				AS JobDescription
							,s.name						AS ScheduleName
							,s.schedule_id				AS ScheduleId
							,s.enabled					AS ScheduleEnabled
							,s.freq_type				AS FreqType
							,s.freq_interval			AS FreqInterval
							,s.freq_subday_type			AS FreqSubdayType
							,s.freq_subday_interval		AS FreqSubdayInterval
							,s.freq_relative_interval	AS FreqRelativeInterval
							,s.freq_recurrence_factor	AS FreqRecurrenceFactor
							,s.active_start_date		AS ActiveStartDate
							,s.active_end_date			AS ActiveEndDate
							,s.active_start_time		AS ActiveStartTime
							,s.active_end_time			AS ActiveEndTime
							,js.next_run_date			AS NextRunDate
							,js.next_run_time			AS NextRunTime
							,@nowUTC, @now
						FROM msdb.dbo.sysjobs AS sj WITH (NOLOCK)
						LEFT OUTER JOIN msdb.dbo.sysjobschedules AS js WITH (NOLOCK) ON (js.job_id = sj.job_id)
						LEFT OUTER JOIN msdb.dbo.sysschedules AS s WITH (NOLOCK) ON (js.schedule_id = s.schedule_id)
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPAgentJobs
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPAgentJobs';
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
				,'dbo.fhsmAgentJobs'
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
		schedules(Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters) AS(
			SELECT
				@enableAgentJobs								AS Enabled
				,0												AS DeploymentStatus
				,'Agent jobs'									AS Name
				,PARSENAME('dbo.fhsmSPAgentJobs', 1)			AS Task
				,12 * 60 * 60									AS ExecutionDelaySec
				,CAST('1900-1-1T06:00:00.0000' AS datetime2(0))	AS FromTime
				,CAST('1900-1-1T07:00:00.0000' AS datetime2(0))	AS ToTime
				,1, 1, 1, 1, 1, 1, 1							-- Monday..Sunday
				,NULL											AS Parameters
		)
		MERGE dbo.fhsmSchedules AS tgt
		USING schedules AS src ON (src.Name = tgt.Name COLLATE SQL_Latin1_General_CP1_CI_AS)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT(Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters)
			VALUES(src.Enabled, src.DeploymentStatus, src.Name, src.Task, src.ExecutionDelaySec, src.FromTime, src.ToTime, src.Monday, src.Tuesday, src.Wednesday, src.Thursday, src.Friday, src.Saturday, src.Sunday, src.Parameters);
	END;

	--
	-- Register dimensions
	--

	--
	-- Update dimensions based upon the fact tables
	--
	BEGIN
		EXEC dbo.fhsmSPUpdateDimensions @table = 'dbo.fhsmAgentJobs';
	END;
END;
