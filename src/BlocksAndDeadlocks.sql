SET NOCOUNT ON;

--
-- Set service to be disabled by default
--
BEGIN
	DECLARE @enableBlocksAndDeadlocks bit;

	SET @enableBlocksAndDeadlocks = 0;
END;

--
-- Specify where the event files are located
--
BEGIN
	DECLARE @blocksAndDeadlocksFilePath nvarchar(260);

	SET @blocksAndDeadlocksFilePath = NULL;
END;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing BlocksAndDeadlocks', 0, 1) WITH NOWAIT;
END;

--
-- Declare variables
--
BEGIN
	DECLARE @blockedProcessThreshold int;
	DECLARE @blockedProcessThresholdChanges TABLE(
		Action nvarchar(10),
		DeletedKey nvarchar(128),
		DeletedValue nvarchar(128),
		InsertedKey nvarchar(128),
		InsertedValue nvarchar(128)
	);
	DECLARE @edition nvarchar(128);
	DECLARE @message nvarchar(max);
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
	-- Check if SQL is 2012 or higher
	--
	IF (@productVersion1 < 11)
	BEGIN
		RAISERROR('!!!', 0, 1) WITH NOWAIT;
		RAISERROR('!!! Can not install BlocksAndDeadlocks on SQL versions lower than SQL2012', 0, 1) WITH NOWAIT;
		RAISERROR('!!!', 0, 1) WITH NOWAIT;

		--
		-- We have to install empty PBI views in order to satisfy the Power BI report
		--
		BEGIN
			--
			-- Create fact view @pbiSchema.[Blocked process]
			--
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocked process') + ''', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocked process') + ' AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocked process') + '
					AS
					SELECT
						TOP (0)
						CAST(NULL AS nvarchar(16)) AS Type
						,CAST(NULL AS int) AS SPID
						,CAST(NULL AS nvarchar(max)) AS Statement
						,CAST(NULL AS int) AS DataSet
						,CAST(NULL AS datetime2(3)) AS EventTimestampUTC
						,CAST(NULL AS date) AS Date
						,CAST(NULL AS int) AS TimeKey
						,CAST(NULL AS bigint) AS BlocksAndDeadlocksKey
						,CAST(NULL AS bigint) AS DatabaseKey;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on fact view @pbiSchema.[Blocked process]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocked process');
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;

			--
			-- Create fact view @pbiSchema.[Deadlock]
			--
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Deadlock') + ''', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Deadlock') + ' AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Deadlock') + '
					AS
					SELECT
						TOP (0)
						CAST(NULL AS int) AS SPID
						,CAST(NULL AS nvarchar(max)) AS InputbufStatement
						,CAST(NULL AS nvarchar(max)) AS FrameStatement
						,CAST(NULL AS int) AS DataSet
						,CAST(NULL AS datetime2(3)) AS EventTimestampUTC
						,CAST(NULL AS date) AS Date
						,CAST(NULL AS int) AS TimeKey
						,CAST(NULL AS bigint) AS BlocksAndDeadlocksKey
						,CAST(NULL AS bigint) AS DatabaseKey;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on fact view @pbiSchema.[Deadlock]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Deadlock');
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;

			--
			-- Create fact view @pbiSchema.[Blocks and deadlocks]
			--
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocks and deadlocks') + ''', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocks and deadlocks') + ' AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocks and deadlocks') + '
					AS
					SELECT
						TOP (0)
						CAST(NULL AS nvarchar(max)) AS ClientApp
						,CAST(NULL AS nvarchar(max)) AS HostName
						,CAST(NULL AS nvarchar(max)) AS LoginName
						,CAST(NULL AS bigint) AS BlocksAndDeadlocksKey;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on fact view @pbiSchema.[Blocks and deadlocks]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocks and deadlocks');
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
		-- We have to install empty Info views in order to satisfy the documentation
		--
		BEGIN
			--
			-- Create info view dbo.fhsmInfoBlocks
			--
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''dbo.fhsmInfoBlocks'', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW dbo.fhsmInfoBlocks AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW dbo.fhsmInfoBlocks
					AS
					SELECT
						TOP (0)
						CAST(NULL AS XML) AS BlockXML,
						CAST(NULL AS datetime2(3)) AS EventTimestampUTC,
						CAST(NULL AS datetime) AS Timestamp,
						CAST(NULL AS datetime) AS TimestampUTC,
						CAST(NULL AS nvarchar(260)) AS FileName,
						CAST(NULL AS bigint) AS FileOffset,
						CAST(NULL AS int) AS Id;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on info view dbo.fhsmInfoBlocks
			--
			BEGIN
				SET @objectName = 'dbo.fhsmInfoBlocks';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;

			--
			-- Create info view dbo.fhsmInfoDeadlocks
			--
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''dbo.fhsmInfoDeadlocks'', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW dbo.fhsmInfoDeadlocks AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW dbo.fhsmInfoDeadlocks
					AS
					SELECT
						TOP (0)
						CAST(NULL AS XML) AS DeadlockXML,
						CAST(NULL AS XML) AS DeadlockGraph,
						CAST(NULL AS datetime2(3)) AS EventTimestampUTC,
						CAST(NULL AS datetime) AS Timestamp,
						CAST(NULL AS datetime) AS TimestampUTC,
						CAST(NULL AS nvarchar(260)) AS FileName,
						CAST(NULL AS bigint) AS FileOffset,
						CAST(NULL AS int) AS Id;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on info view dbo.fhsmInfoDeadlocks
			--
			BEGIN
				SET @objectName = 'dbo.fhsmInfoDeadlocks';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;
		END;
	END
	ELSE BEGIN
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
		-- Print message if Blocked process reporting threshold is not set and with valid value
		--
		BEGIN
			SET @blockedProcessThreshold = (
				SELECT CAST(c.value_in_use AS int)
				FROM sys.configurations AS c
				WHERE (c.configuration_id = 1569)
			);

			IF (@blockedProcessThreshold = 0)
			BEGIN
				RAISERROR('!!!', 0, 1) WITH NOWAIT;
				RAISERROR('!!! Blocked process reporting threshold is not set', 0, 1) WITH NOWAIT;
				RAISERROR('!!!', 0, 1) WITH NOWAIT;
			END
			ELSE IF (@blockedProcessThreshold < 5)
			BEGIN
				RAISERROR('!!!', 0, 1) WITH NOWAIT;
				RAISERROR('!!! Blocked process reporting threshold is set to lower than 5 seconds', 0, 1) WITH NOWAIT;
				RAISERROR('!!!', 0, 1) WITH NOWAIT;
			END;

			WITH
			conf([Key], Value) AS(
				SELECT
					'BlockedProcessThreshold' AS [Key]
					,CAST(@blockedProcessThreshold AS nvarchar) AS Value
			)
			MERGE dbo.fhsmConfigurations AS tgt
			USING conf AS src ON (src.[Key] = tgt.[Key] COLLATE SQL_Latin1_General_CP1_CI_AS)
			WHEN MATCHED AND (tgt.Value <> src.Value)
				THEN UPDATE
					SET tgt.Value = src.Value
			WHEN NOT MATCHED BY TARGET
				THEN INSERT([Key], Value)
				VALUES(src.[Key], src.Value)
			OUTPUT
		        $action,
				deleted.[Key],
				deleted.Value,
				inserted.[Key],
				inserted.Value
			INTO @blockedProcessThresholdChanges;

			SET @message = (
				SELECT 'Blocked process reporting threshold is ''' + src.InsertedValue + '''' + COALESCE(' - changed from ''' + src.DeletedValue + '''', '')
				FROM @blockedProcessThresholdChanges AS src
			);
			IF (@message IS NOT NULL)
			BEGIN
				RAISERROR(@message, 0, 1) WITH NOWAIT;
				EXEC dbo.fhsmSPLog @name = 'Blocks and deadlocks - installation', @version = @version, @task = 'BlocksAndDeadlocks', @type = 'Info', @message = @message;
			END;
		END;

		--
		-- Create tables
		--
		BEGIN
			--
			-- Create XML schema collection if it not already exists
			--
			IF NOT EXISTS(
				SELECT *
				FROM sys.xml_schema_collections AS xsc
				WHERE (xsc.schema_id = SCHEMA_ID('dbo')) AND (xsc.name = 'fhsmBlocksAndDeadlocksXMLSchemaCollection')
			)
			BEGIN
				RAISERROR('Creating XML schema collection dbo.fhsmBlocksAndDeadlocksXMLSchemaCollection', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE XML SCHEMA COLLECTION dbo.fhsmBlocksAndDeadlocksXMLSchemaCollection
					AS N''
					<xs:schema attributeFormDefault="unqualified" elementFormDefault="qualified" xmlns:xs="http://www.w3.org/2001/XMLSchema">
						<xs:element name="event">
							<xs:complexType>
								<xs:sequence>
									<xs:element name="data" maxOccurs="unbounded" minOccurs="0">
										<xs:complexType>
											<xs:sequence>
												<xs:element name="value"/>
												<xs:element type="xs:string" name="text" minOccurs="0"/>
											</xs:sequence>
											<xs:attribute type="xs:string" name="name" use="optional"/>
										</xs:complexType>
									</xs:element>
									<xs:element name="action" maxOccurs="unbounded" minOccurs="0">
										<xs:complexType>
											<xs:sequence>
												<xs:element type="xs:string" name="value"/>
											</xs:sequence>
											<xs:attribute type="xs:string" name="name" use="optional"/>
											<xs:attribute type="xs:string" name="package" use="optional"/>
										</xs:complexType>
									</xs:element>
								</xs:sequence>
								<xs:attribute type="xs:string" name="name"/>
								<xs:attribute type="xs:string" name="package"/>
								<xs:attribute type="xs:dateTime" name="timestamp"/>
							</xs:complexType>
						</xs:element>
					</xs:schema>'';
				';
				EXEC(@stmt);
			END;

			--
			-- Create table dbo.fhsmBlocksAndDeadlocks and indexes if they not already exists
			--
			IF OBJECT_ID('dbo.fhsmBlocksAndDeadlocks', 'U') IS NULL
			BEGIN
				RAISERROR('Creating table dbo.fhsmBlocksAndDeadlocks', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE TABLE dbo.fhsmBlocksAndDeadlocks(
						Id int identity(1,1) NOT NULL
						,EventTimestampUTC datetime2(3) NOT NULL
						,FileName nvarchar(260) NOT NULL
						,FileOffset bigint NOT NULL
						,EventData XML(dbo.fhsmBlocksAndDeadlocksXMLSchemaCollection) NOT NULL
						,TimestampUTC datetime NOT NULL
						,Timestamp datetime NOT NULL
						,CONSTRAINT PK_fhsmBlocksAndDeadlocks PRIMARY KEY(Id)' + @tableCompressionStmt + '
					);
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmBlocksAndDeadlocks')) AND (i.name = 'NC_fhsmBlocksAndDeadlocks_EventTimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmBlocksAndDeadlocks_EventTimestampUTC] to table dbo.fhsmBlocksAndDeadlocks', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmBlocksAndDeadlocks_EventTimestampUTC ON dbo.fhsmBlocksAndDeadlocks(EventTimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmBlocksAndDeadlocks')) AND (i.name = 'NC_fhsmBlocksAndDeadlocks_TimestampUTC'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmBlocksAndDeadlocks_TimestampUTC] to table dbo.fhsmBlocksAndDeadlocks', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmBlocksAndDeadlocks_TimestampUTC ON dbo.fhsmBlocksAndDeadlocks(TimestampUTC)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			IF NOT EXISTS (SELECT * FROM sys.indexes AS i WHERE (i.object_id = OBJECT_ID('dbo.fhsmBlocksAndDeadlocks')) AND (i.name = 'NC_fhsmBlocksAndDeadlocks_Timestamp'))
			BEGIN
				RAISERROR('Adding index [NC_fhsmBlocksAndDeadlocks_Timestamp] to table dbo.fhsmBlocksAndDeadlocks', 0, 1) WITH NOWAIT;

				SET @stmt = '
					CREATE NONCLUSTERED INDEX NC_fhsmBlocksAndDeadlocks_Timestamp ON dbo.fhsmBlocksAndDeadlocks(Timestamp)' + @tableCompressionStmt + ';
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the table dbo.fhsmBlocksAndDeadlocks
			--
			BEGIN
				SET @objectName = 'dbo.fhsmBlocksAndDeadlocks';
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
		-- Create PBI views
		--
		BEGIN
			--
			-- Create fact view @pbiSchema.[Blocked process]
			--
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocked process') + ''', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocked process') + ' AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocked process') + '
					AS
					SELECT
						CAST(a.Type AS nvarchar(16)) AS Type
						,a.SPID
						,CASE WHEN ASCII(LEFT(a.Statement, 1)) = 10 THEN SUBSTRING(a.Statement, 2, LEN(a.Statement)) ELSE a.Statement END AS Statement
						,a.Id AS DataSet
						,a.EventTimestampUTC
						,CAST(a.EventTimestampUTC AS date) AS Date
						,(DATEPART(HOUR, a.EventTimestampUTC) * 60 * 60) + (DATEPART(MINUTE, a.EventTimestampUTC) * 60) + (DATEPART(SECOND, a.EventTimestampUTC)) AS TimeKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.ClientApp, a.HostName, a.LoginName, DEFAULT, DEFAULT, DEFAULT) AS k) AS BlocksAndDeadlocksKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.CurrentDBName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					FROM (
						SELECT
							CASE b.rootData.value(''local-name(/*[1])'', ''nvarchar(max)'')
								WHEN ''blocking-process'' THEN ''Blocking''
								WHEN ''blocked-process'' THEN ''Blocked''
							END AS Type
							,b.rootData.value(''(*/process/@hostname)[1]'', ''nvarchar(max)'') AS HostName
							,b.rootData.value(''(*/process/@clientapp)[1]'', ''nvarchar(max)'') AS ClientApp
							,b.rootData.value(''(*/process/@loginname)[1]'', ''nvarchar(max)'') AS LoginName
							,b.rootData.value(''(*/process/@currentdbname)[1]'', ''nvarchar(max)'') AS CurrentDBName
							,CAST(b.rootData.value(''(*/process/@spid)[1]'', ''nvarchar(max)'') AS int) AS SPID
							,b.rootData.value(''(*/process/inputbuf/text())[1]'', ''nvarchar(max)'') AS Statement
							,b.Id
							,b.EventTimestampUTC
						FROM (
							SELECT
								t.c.query(''(.)[1]'') AS rootData
								,f.Id
								,f.EventTimestampUTC
							FROM (
								SELECT
									b.EventTimestampUTC
									,b.EventData
									,b.Id
								FROM dbo.fhsmBlocksAndDeadlocks AS b
								WHERE (b.EventData.value(''(event/@name)[1]'', ''nvarchar(max)'') = ''blocked_process_report'')
									AND (
										b.EventData.query(''(event/data[@name="blocked_process"]/value/blocked-process-report/blocked-process/process)[1]'').value(''(process/@spid)[1]'', ''nvarchar(max)'')
										<>
										b.EventData.query(''(event/data[@name="blocked_process"]/value/blocked-process-report/blocking-process/process)[1]'').value(''(process/@spid)[1]'', ''nvarchar(max)'')
									)
							) AS f
							CROSS APPLY f.EventData.nodes(''/event/data[@name="blocked_process"]/value/blocked-process-report/*'') AS t(c)
						) AS b
					) AS a
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on fact view @pbiSchema.[Blocked process]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocked process');
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;

			--
			-- Create fact view @pbiSchema.[Deadlock]
			--
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Deadlock') + ''', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Deadlock') + ' AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Deadlock') + '
					AS
					SELECT
						a.SPID
						,CASE WHEN ASCII(LEFT(a.InputbufStatement, 1)) = 10 THEN SUBSTRING(a.InputbufStatement, 2, LEN(a.InputbufStatement)) ELSE a.InputbufStatement END AS InputbufStatement
						,CASE WHEN ASCII(LEFT(a.FrameStatement,    1)) = 10 THEN SUBSTRING(a.FrameStatement,    2, LEN(a.FrameStatement))    ELSE a.FrameStatement    END AS FrameStatement
						,a.Id AS DataSet
						,a.EventTimestampUTC
						,CAST(a.EventTimestampUTC AS date) AS Date
						,(DATEPART(HOUR, a.EventTimestampUTC) * 60 * 60) + (DATEPART(MINUTE, a.EventTimestampUTC) * 60) + (DATEPART(SECOND, a.EventTimestampUTC)) AS TimeKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.ClientApp, a.HostName, a.LoginName, DEFAULT, DEFAULT, DEFAULT) AS k) AS BlocksAndDeadlocksKey
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.CurrentDBName, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) AS k) AS DatabaseKey
					FROM (
						SELECT
							b.rootData.value(''(process/@hostname)[1]'', ''nvarchar(max)'') AS HostName
							,b.rootData.value(''(process/@clientapp)[1]'', ''nvarchar(max)'') AS ClientApp
							,b.rootData.value(''(process/@loginname)[1]'', ''nvarchar(max)'') AS LoginName
							,b.rootData.value(''(process/@currentdbname)[1]'', ''nvarchar(max)'') AS CurrentDBName
							,CAST(b.rootData.value(''(process/@spid)[1]'', ''nvarchar(max)'') AS int) AS SPID
							,b.inputbufData.value(''(inputbuf/text())[1]'', ''nvarchar(max)'') AS InputbufStatement
							,b.frameData.value(''(frame/text())[1]'', ''nvarchar(max)'') AS FrameStatement
							,b.Id
							,b.EventTimestampUTC
						FROM (
							SELECT
								t.c.query(''(.)[1]'') AS rootData
								,t.c.query(''(inputbuf)[1]'') AS inputbufData
								,t.c.query(''(executionStack/frame)[1]'') AS frameData
								,f.Id
								,f.EventTimestampUTC
							FROM (
								SELECT
									dl.EventTimestampUTC
									,dl.FileName
									,dl.FileOffset
									,dl.EventData
									,dl.Id
								FROM dbo.fhsmBlocksAndDeadlocks AS dl
								WHERE (dl.EventData.value(''(event/@name)[1]'', ''nvarchar(max)'') = ''xml_deadlock_report'')
							) AS f
							CROSS APPLY f.EventData.nodes(''/event/data/value/deadlock/process-list/process'') AS t(c)
						) AS b
					) AS a;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on fact view @pbiSchema.[Deadlock]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Deadlock');
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;

			--
			-- Create dimension view @pbiSchema.[Blocks and deadlocks]
			--
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocks and deadlocks') + ''', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocks and deadlocks') + ' AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocks and deadlocks') + '
					AS
					SELECT
						a.ClientApp
						,a.HostName
						,a.LoginName
						,(SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(a.ClientApp, a.HostName, a.LoginName, DEFAULT, DEFAULT, DEFAULT) AS k) AS BlocksAndDeadlocksKey
					FROM (
						SELECT
							DISTINCT
							b.blockedProcessData.value(''(process/@hostname)[1]'', ''nvarchar(max)'') AS HostName
							,b.blockedProcessData.value(''(process/@clientapp)[1]'', ''nvarchar(max)'') AS ClientApp
							,b.blockedProcessData.value(''(process/@loginname)[1]'', ''nvarchar(max)'') AS LoginName
						FROM (
							SELECT
								f.EventData.query(''(event/data[@name="blocked_process"]/value/blocked-process-report/blocked-process/process)[1]'') AS blockedProcessData
								,f.EventData.query(''(event/data[@name="blocked_process"]/value/blocked-process-report/blocking-process/process)[1]'') AS blockingProcessData
							FROM dbo.fhsmBlocksAndDeadlocks AS f
							WHERE (f.EventData.value(''(event/@name)[1]'', ''nvarchar(max)'') = ''blocked_process_report'')
						) AS b
						WHERE CAST(b.blockedProcessData.value(''(process/@spid)[1]'', ''nvarchar(max)'') AS int) <> CAST(b.blockingProcessData.value(''(process/@spid)[1]'', ''nvarchar(max)'') AS int)

						UNION

						SELECT
							DISTINCT
							b.rootData.value(''(process/@hostname)[1]'', ''nvarchar(max)'') AS HostName
							,b.rootData.value(''(process/@clientapp)[1]'', ''nvarchar(max)'') AS ClientApp
							,b.rootData.value(''(process/@loginname)[1]'', ''nvarchar(max)'') AS LoginName
						FROM (
							SELECT
								t.c.query(''(.)[1]'') AS rootData
							FROM (
								SELECT dl.EventData
								FROM dbo.fhsmBlocksAndDeadlocks AS dl
								WHERE (dl.EventData.value(''(event/@name)[1]'', ''nvarchar(max)'') = ''xml_deadlock_report'')
							) AS f
							CROSS APPLY f.EventData.nodes(''/event/data/value/deadlock/process-list/process'') AS t(c)
						) AS b
					) AS a;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on dimension view @pbiSchema.[Blocks and deadlocks]
			--
			BEGIN
				SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Blocks and deadlocks');
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
		-- Create Info views
		--
		BEGIN
			--
			-- Create info view dbo.fhsmInfoBlocks
			--
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''dbo.fhsmInfoBlocks'', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW dbo.fhsmInfoBlocks AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW dbo.fhsmInfoBlocks
					AS
					SELECT
						EventData AS BlockXML,
						EventTimestampUTC,
						Timestamp,
						TimestampUTC,
						FileName,
						FileOffset,
						Id
					FROM dbo.fhsmBlocksAndDeadlocks
					WHERE (EventData.value(''(event/@name)[1]'', ''nvarchar(max)'') = ''blocked_process_report'');
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on info view dbo.fhsmInfoBlocks
			--
			BEGIN
				SET @objectName = 'dbo.fhsmInfoBlocks';
				SET @objName = PARSENAME(@objectName, 1);
				SET @schName = PARSENAME(@objectName, 2);

				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
				EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
			END;

			--
			-- Create info view dbo.fhsmInfoDeadlocks
			--
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''dbo.fhsmInfoDeadlocks'', ''V'') IS NULL
					BEGIN
						EXEC(''CREATE VIEW dbo.fhsmInfoDeadlocks AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER VIEW dbo.fhsmInfoDeadlocks
					AS
					SELECT
						EventData AS DeadlockXML,
						EventData.query(''(event/data/value/deadlock)[1]'') AS DeadlockGraph,
						EventTimestampUTC,
						Timestamp,
						TimestampUTC,
						FileName,
						FileOffset,
						Id
					FROM dbo.fhsmBlocksAndDeadlocks
					WHERE (EventData.value(''(event/@name)[1]'', ''nvarchar(max)'') = ''xml_deadlock_report'');
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on info view dbo.fhsmInfoDeadlocks
			--
			BEGIN
				SET @objectName = 'dbo.fhsmInfoDeadlocks';
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
			-- Create stored procedure dbo.fhsmSPBlocksAndDeadlocks
			--
			BEGIN
				SET @stmt = '
					IF OBJECT_ID(''dbo.fhsmSPBlocksAndDeadlocks'', ''P'') IS NULL
					BEGIN
						EXEC(''CREATE PROC dbo.fhsmSPBlocksAndDeadlocks AS SELECT ''''dummy'''' AS Txt'');
					END;
				';
				EXEC(@stmt);

				SET @stmt = '
					ALTER PROC dbo.fhsmSPBlocksAndDeadlocks (
						@name nvarchar(128)
						,@version nvarchar(128) OUTPUT
					)
					AS
					BEGIN
						SET NOCOUNT ON;

						DECLARE @blockedProcessThreshold int;
						DECLARE @blockedProcessThresholdChanges TABLE(
							Action nvarchar(10),
							DeletedKey nvarchar(128),
							DeletedValue nvarchar(128),
							InsertedKey nvarchar(128),
							InsertedValue nvarchar(128)
						);
						DECLARE @errorMsg nvarchar(max);
						DECLARE @fileName nvarchar(260);
						DECLARE @fileOffset bigint;
						DECLARE @filePath nvarchar(260);
						DECLARE @filePathEvent nvarchar(260);
						DECLARE @message nvarchar(max);
						DECLARE @now datetime;
						DECLARE @nowUTC datetime;
						DECLARE @parameters nvarchar(max);
						DECLARE @parametersTable TABLE([Key] nvarchar(128) NOT NULL, Value nvarchar(128) NULL);
						DECLARE @runningFilePath nvarchar(260);
						DECLARE @sessionName nvarchar(128);
						DECLARE @stmt nvarchar(max);
						DECLARE @testFileName nvarchar(260);
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

							SET @filePath = (SELECT pt.Value FROM @parametersTable AS pt WHERE (pt.[Key] = ''@FilePath''));
							SET @filePath = NULLIF(REPLACE(@filePath, '''''''', ''''), '''');
						END;

						--
						-- Initialize variables
						--
						BEGIN
							SET @sessionName = ''FHSMBlocksAndDeadlocks'';
							SET @filePathEvent = COALESCE(@filePath + ''\'', '''') + @sessionName + ''.xel'';
							SET @filePath = REPLACE(@filePathEvent, ''.xel'', ''*.xel'');
						END;
				';
				SET @stmt += '
						--
						-- Register configuration changes
						--
						BEGIN
							SET @blockedProcessThreshold = (
								SELECT CAST(c.value_in_use AS int)
								FROM sys.configurations AS c
								WHERE (c.configuration_id = 1569)
							);

							WITH
							conf([Key], Value) AS(
								SELECT
									''BlockedProcessThreshold'' AS [Key]
									,CAST(@blockedProcessThreshold AS nvarchar) AS Value
							)
							MERGE dbo.fhsmConfigurations AS tgt
							USING conf AS src ON (src.[Key] = tgt.[Key] COLLATE SQL_Latin1_General_CP1_CI_AS)
							WHEN MATCHED AND (tgt.Value <> src.Value)
								THEN UPDATE
									SET tgt.Value = src.Value
							WHEN NOT MATCHED BY TARGET
								THEN INSERT([Key], Value)
								VALUES(src.[Key], src.Value)
							OUTPUT
								$action,
								deleted.[Key],
								deleted.Value,
								inserted.[Key],
								inserted.Value
							INTO @blockedProcessThresholdChanges;

							SET @message = (
								SELECT ''Blocked process reporting threshold is '''''' + src.InsertedValue + '''''''' + COALESCE('' - changed from '''''' + src.DeletedValue + '''''''', '''')
								FROM @blockedProcessThresholdChanges AS src
							);
							IF (@message IS NOT NULL)
							BEGIN
								EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Info'', @message = @message;
							END;
						END;
				';
				SET @stmt += '
						--
						-- Setup or change event session if @filePath is not configured or the same
						--
						BEGIN
							SET @runningFilePath = (
								SELECT CAST(sesf.value AS nvarchar(260))
								FROM sys.server_event_sessions AS ses
								INNER JOIN sys.server_event_session_fields AS sesf ON (sesf.event_session_id = ses.event_session_id)
								WHERE (ses.name = @sessionName) AND (sesf.name = ''FILENAME'')
							);

							IF (@runningFilePath <> @filePathEvent) OR (@runningFilePath IS NULL)
							BEGIN
								IF EXISTS(
									SELECT *
									FROM sys.server_event_sessions AS ses
									WHERE (ses.name = @sessionName)
								)
								BEGIN
									SET @stmt = ''DROP EVENT SESSION '' + QUOTENAME(@sessionName) + '' ON SERVER;'';
									EXEC(@stmt);
								END;

								SET @stmt = ''
									CREATE EVENT SESSION '' + QUOTENAME(@sessionName) + '' ON SERVER
									ADD EVENT sqlserver.blocked_process_report(
										ACTION(
											sqlserver.client_app_name,
											sqlserver.client_hostname,
											sqlserver.database_name
										)
									),
									ADD EVENT sqlserver.xml_deadlock_report(
										ACTION(
											sqlserver.client_app_name,
											sqlserver.client_hostname,
											sqlserver.database_name
										)
									)
									ADD TARGET package0.asynchronous_file_target(
										SET
										filename = N''''<FILENAME>'''',
										max_file_size = (10),
										max_rollover_files = 2
									)
									WITH (
										EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
										MAX_DISPATCH_LATENCY = 15 SECONDS,
										STARTUP_STATE = ON
									);
								'';

								SET @stmt = REPLACE(@stmt, ''<FILENAME>'', @filePathEvent);
								EXEC(@stmt);

								SET @stmt = ''ALTER EVENT SESSION '' + QUOTENAME(@sessionName) + '' ON SERVER STATE = START;'';
								EXEC(@stmt);
							END;
						END;
				';
				SET @stmt += '
						--
						-- Get latest file name and offset
						--
						BEGIN
							SELECT TOP (1)
								@fileName = f.FileName
								,@fileOffset = f.FileOffset
							FROM dbo.fhsmBlocksAndDeadlocks AS f
							ORDER BY f.Id DESC;

							BEGIN TRY
								SET @testFileName = (
									SELECT TOP (1) f.file_name
									FROM sys.fn_xe_file_target_read_file(@filePath, NULL, @fileName, @fileOffset) AS f
								);
							END TRY
							BEGIN CATCH
								SET @fileName = NULL;
								SET @fileOffset = NULL;
							END CATCH;
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

							BEGIN TRY
								INSERT INTO dbo.fhsmBlocksAndDeadlocks(EventTimestampUTC, FileName, FileOffset, EventData, TimestampUTC, Timestamp)
								SELECT a.EventTimestampUTC, a.FileName, a.FileOffset, a.EventData, a.TimestampUTC, a.Timestamp
								FROM (
									SELECT
										' + CASE WHEN (@productVersion1 <= 13) THEN '@nowUTC' ELSE 'f.timestamp_utc' END + ' AS EventTimestampUTC
										,f.file_name AS FileName
										,f.file_offset AS FileOffset
										,CAST(f.event_data AS varchar(max)) AS EventData
										,@nowUTC AS TimestampUTC
										,@now AS Timestamp
									FROM sys.fn_xe_file_target_read_file(@filePath, NULL, @fileName, @fileOffset) AS f
								) AS a
								WHERE NOT EXISTS(
									SELECT *
									FROM dbo.fhsmBlocksAndDeadlocks AS t
									WHERE (t.EventTimestampUTC = a.EventTimestampUTC)
								)
								ORDER BY
									' + CASE WHEN (@productVersion1 <= 13) THEN '' ELSE 'a.EventTimestampUTC,' END + '
									a.FileName,
									a.FileOffset;
							END TRY
							BEGIN CATCH
								SET @errorMsg = ERROR_MESSAGE();

								SET @message = ''Failed due to - '' + @errorMsg;
								EXEC dbo.fhsmSPLog @name = @name, @version = @version, @task = @thisTask, @type = ''Warning'', @message = @message;
							END CATCH;
						END;

						RETURN 0;
					END;
				';
				EXEC(@stmt);
			END;

			--
			-- Register extended properties on the stored procedure dbo.fhsmSPBlocksAndDeadlocks
			--
			BEGIN
				SET @objectName = 'dbo.fhsmSPBlocksAndDeadlocks';
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
					,'dbo.fhsmBlocksAndDeadlocks'
					,1
					,'TimestampUTC'
					,1
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
			schedules(Enabled, DeploymentStatus, Name, Task, ExecutionDelaySec, FromTime, ToTime, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Parameters) AS(
				SELECT
					@enableBlocksAndDeadlocks												AS Enabled
					,0																		AS DeploymentStatus
					,'Blocks and deadlocks'													AS Name
					,PARSENAME('dbo.fhsmSPBlocksAndDeadlocks', 1)							AS Task
					,5 * 60																	AS ExecutionDelaySec
					,CAST('1900-1-1T00:00:00.0000' AS datetime2(0))							AS FromTime
					,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))							AS ToTime
					,1, 1, 1, 1, 1, 1, 1													-- Monday..Sunday
					,'@FilePath = ''' + COALESCE(@blocksAndDeadlocksFilePath, '') + ''''	AS Parameters
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
	END;
END;
