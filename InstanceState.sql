SET NOCOUNT ON;

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
	DECLARE @productEndPos int;
	DECLARE @productStartPos int;
	DECLARE @productVersion nvarchar(128);
	DECLARE @productVersion1 int;
	DECLARE @productVersion2 int;
	DECLARE @productVersion3 int;
	DECLARE @returnValue int;
	DECLARE @schName nvarchar(128);
	DECLARE @stmt nvarchar(max);
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
		SET @version = '1.9';

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
	-- Create tables
	--
	BEGIN
		--
		-- Create table dbo.fhsmAgentAlerts if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmAgentAlerts', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmAgentAlerts', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmAgentAlerts(
				Id int identity(1,1) NOT NULL
				,MessageId int NOT NULL
				,Severity int NOT NULL
				,Description nvarchar(128) NOT NULL
				,CONSTRAINT PK_fhsmAgentAlerts PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmAgentAlerts_MessageId_Severity ON dbo.fhsmAgentAlerts(MessageId, Severity);
		END;

		--
		-- Register extended properties on the table dbo.fhsmAgentAlerts
		--
		BEGIN
			SET @objectName = 'dbo.fhsmAgentAlerts';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create table dbo.fhsmInstanceConfigurations if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmInstanceConfigurations', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmInstanceConfigurations', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmInstanceConfigurations(
				Id int identity(1,1) NOT NULL
				,ProductMajorVersion int NOT NULL
				,ProductMinorVersion int NOT NULL
				,ConfigurationId int NOT NULL
				,Minimum int NOT NULL
				,Maximum int NOT NULL
				,CONSTRAINT PK_fhsmInstanceConfigurations PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmInstanceConfigurations_ConfigurationId_ProductMajorVersion_ProductMinorVersion ON dbo.fhsmInstanceConfigurations(ConfigurationId, ProductMajorVersion, ProductMinorVersion);
		END;

		--
		-- Register extended properties on the table dbo.fhsmInstanceConfigurations
		--
		BEGIN
			SET @objectName = 'dbo.fhsmInstanceConfigurations';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create table dbo.fhsmInstanceState if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmInstanceState', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmInstanceState', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmInstanceState(
				Id int identity(1,1) NOT NULL
				,Query int NOT NULL
				,Category nvarchar(128) NOT NULL
				,[Key] nvarchar(128) NOT NULL
				,Value nvarchar(max) NOT NULL
				,ValidFrom datetime NOT NULL
				,ValidTo datetime NOT NULL
				,TimestampUTC datetime NOT NULL
				,Timestamp datetime NOT NULL
				,CONSTRAINT PK_fhsmInstanceState PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmInstanceState_TimestampUTC ON dbo.fhsmInstanceState(TimestampUTC);
			CREATE NONCLUSTERED INDEX NC_fhsmInstanceState_Timestamp ON dbo.fhsmInstanceState(Timestamp);
			CREATE NONCLUSTERED INDEX NC_fhsmInstanceState_Query_Category_Key_ValidTo ON dbo.fhsmInstanceState(Query, Category, [Key], ValidTo) INCLUDE(Value);
			CREATE NONCLUSTERED INDEX NC_fhsmInstanceState_ValidTo_Query_Category_key ON dbo.fhsmInstanceState(ValidTo, Query, Category, [Key]) INCLUDE(Value);
		END;

		--
		-- Register extended properties on the table dbo.fhsmInstanceState
		--
		BEGIN
			SET @objectName = 'dbo.fhsmInstanceState';
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'Table', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create table dbo.fhsmTraceFlags if it not already exists
		--
		IF OBJECT_ID('dbo.fhsmTraceFlags', 'U') IS NULL
		BEGIN
			RAISERROR('Creating table dbo.fhsmTraceFlags', 0, 1) WITH NOWAIT;

			CREATE TABLE dbo.fhsmTraceFlags(
				Id int identity(1,1) NOT NULL
				,ProductMajorVersion int NOT NULL
				,ProductMinorVersion int NOT NULL
				,TraceFlag int NOT NULL
				,Description nvarchar(max) NOT NULL
				,URL nvarchar(max) NULL
				,CONSTRAINT PK_fhsmTraceFlags PRIMARY KEY(Id)
			);

			CREATE NONCLUSTERED INDEX NC_fhsmTraceFlags_TraceFlag_ProductMajorVersion_ProductMinorVersion ON dbo.fhsmTraceFlags(TraceFlag, ProductMajorVersion, ProductMinorVersion);
		END;

		--
		-- Register extended properties on the table dbo.fhsmTraceFlags
		--
		BEGIN
			SET @objectName = 'dbo.fhsmTraceFlags';
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
	-- Create default agent alert recommendations
	--
	BEGIN
		MERGE dbo.fhsmAgentAlerts AS tgt
		USING (
			SELECT 823 AS MessageId,  0 AS Severity, 'The operating system returned an error'                                         AS Description UNION ALL
			SELECT 824 AS MessageId,  0 AS Severity, 'Logical consistency-based I/O error'                                            AS Description UNION ALL
			SELECT 825 AS MessageId,  0 AS Severity, 'Read-Retry Required'                                                            AS Description UNION ALL
			SELECT 832 AS MessageId,  0 AS Severity, 'Constant page has changed'                                                      AS Description UNION ALL
			SELECT 855 AS MessageId,  0 AS Severity, 'Uncorrectable hardware memory corruption detected'                              AS Description UNION ALL
			SELECT 856 AS MessageId,  0 AS Severity, 'SQL Server has detected hardware memory corruption, but has recovered the page' AS Description UNION ALL
			SELECT   0 AS MessageId, 19 AS Severity, 'Fatal Error in Resource'                                                        AS Description UNION ALL
			SELECT   0 AS MessageId, 20 AS Severity, 'Fatal Error in Current Process'                                                 AS Description UNION ALL
			SELECT   0 AS MessageId, 21 AS Severity, 'Fatal Error in Database Processes'                                              AS Description UNION ALL
			SELECT   0 AS MessageId, 22 AS Severity, 'Fatal Error: Table Integrity Suspect'                                           AS Description UNION ALL
			SELECT   0 AS MessageId, 23 AS Severity, 'Fatal Error: Database Integrity Suspect'                                        AS Description UNION ALL
			SELECT   0 AS MessageId, 24 AS Severity, 'Fatal Error: Hardware Error'                                                    AS Description UNION ALL
			SELECT   0 AS MessageId, 25 AS Severity, 'Fatal Error'                                                                    AS Description
		) AS src
		ON (tgt.MessageId = src.MessageId) AND (tgt.Severity = src.Severity)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT (MessageId, Severity, Description)
				VALUES(src.MessageId, src.Severity, src.Description);
	END;

	--
	-- Create default configuration recommendations
	--
	BEGIN
		MERGE dbo.fhsmInstanceConfigurations AS tgt
		USING (
			--SQL2019
			SELECT '15' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1585 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--automatic soft-NUMA disabled
			SELECT '15' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1584 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--backup checksum default
			SELECT '15' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1579 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--backup compression default
			SELECT '15' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1562 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--clr enabled
			SELECT '15' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1538 AS ConfigurationId,    6 AS Minimum,  32767 AS Maximum UNION ALL	--cost threshold for parallelism
			SELECT '15' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1546 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--lightweight pooling
			SELECT '15' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1539 AS ConfigurationId,    0 AS Minimum,  32767 AS Maximum UNION ALL	--max degree of parallelism
			SELECT '15' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1544 AS ConfigurationId, 2048 AS Minimum, 524288 AS Maximum UNION ALL	--max server memory (MB)
			SELECT '15' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1581 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--optimize for ad hoc workloads
			SELECT '15' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1517 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--priority boost
			SELECT '15' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1576 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--remote admin connections
			SELECT '15' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1589 AS ConfigurationId,    0 AS Minimum,      1 AS Maximum UNION ALL	--tempdb metadata memory-optimized
			--SQL2017
			SELECT '14' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1585 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--automatic soft-NUMA disabled
			SELECT '14' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1584 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--backup checksum default
			SELECT '14' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1579 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--backup compression default
			SELECT '14' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1562 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--clr enabled
			SELECT '14' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1538 AS ConfigurationId,    6 AS Minimum,  32767 AS Maximum UNION ALL	--cost threshold for parallelism
			SELECT '14' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1546 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--lightweight pooling
			SELECT '14' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1539 AS ConfigurationId,    0 AS Minimum,  32767 AS Maximum UNION ALL	--max degree of parallelism
			SELECT '14' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1544 AS ConfigurationId, 2048 AS Minimum, 524288 AS Maximum UNION ALL	--max server memory (MB)
			SELECT '14' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1581 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--optimize for ad hoc workloads
			SELECT '14' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1517 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--priority boost
			SELECT '14' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1576 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--remote admin connections
			--SQL2016
			SELECT '13' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1585 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--automatic soft-NUMA disabled
			SELECT '13' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1584 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--backup checksum default
			SELECT '13' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1579 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--backup compression default
			SELECT '13' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1562 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--clr enabled
			SELECT '13' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1538 AS ConfigurationId,    6 AS Minimum,  32767 AS Maximum UNION ALL	--cost threshold for parallelism
			SELECT '13' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1546 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--lightweight pooling
			SELECT '13' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1539 AS ConfigurationId,    0 AS Minimum,  32767 AS Maximum UNION ALL	--max degree of parallelism
			SELECT '13' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1544 AS ConfigurationId, 2048 AS Minimum, 524288 AS Maximum UNION ALL	--max server memory (MB)
			SELECT '13' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1581 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--optimize for ad hoc workloads
			SELECT '13' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1517 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--priority boost
			SELECT '13' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1576 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--remote admin connections
			--SQL2014
			SELECT '12' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1584 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--backup checksum default
			SELECT '12' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1579 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--backup compression default
			SELECT '12' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1562 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--clr enabled
			SELECT '12' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1538 AS ConfigurationId,    6 AS Minimum,  32767 AS Maximum UNION ALL	--cost threshold for parallelism
			SELECT '12' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1546 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--lightweight pooling
			SELECT '12' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1539 AS ConfigurationId,    0 AS Minimum,  32767 AS Maximum UNION ALL	--max degree of parallelism
			SELECT '12' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1544 AS ConfigurationId, 2048 AS Minimum, 524288 AS Maximum UNION ALL	--max server memory (MB)
			SELECT '12' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1581 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--optimize for ad hoc workloads
			SELECT '12' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1517 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--priority boost
			SELECT '12' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1576 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--remote admin connections
			--SQL2012
			SELECT '11' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1579 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--backup compression default
			SELECT '11' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1562 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--clr enabled
			SELECT '11' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1538 AS ConfigurationId,    6 AS Minimum,  32767 AS Maximum UNION ALL	--cost threshold for parallelism
			SELECT '11' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1546 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--lightweight pooling
			SELECT '11' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1539 AS ConfigurationId,    0 AS Minimum,  32767 AS Maximum UNION ALL	--max degree of parallelism
			SELECT '11' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1544 AS ConfigurationId, 2048 AS Minimum, 524288 AS Maximum UNION ALL	--max server memory (MB)
			SELECT '11' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1581 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--optimize for ad hoc workloads
			SELECT '11' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1517 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--priority boost
			SELECT '11' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1576 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--remote admin connections
			--SQL2008R2
			SELECT '10' AS ProductMajorVersion, 50 AS ProductMinorVersion, 1579 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--backup compression default
			SELECT '10' AS ProductMajorVersion, 50 AS ProductMinorVersion, 1562 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--clr enabled
			SELECT '10' AS ProductMajorVersion, 50 AS ProductMinorVersion, 1538 AS ConfigurationId,    6 AS Minimum,  32767 AS Maximum UNION ALL	--cost threshold for parallelism
			SELECT '10' AS ProductMajorVersion, 50 AS ProductMinorVersion, 1546 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--lightweight pooling
			SELECT '10' AS ProductMajorVersion, 50 AS ProductMinorVersion, 1539 AS ConfigurationId,    0 AS Minimum,  32767 AS Maximum UNION ALL	--max degree of parallelism
			SELECT '10' AS ProductMajorVersion, 50 AS ProductMinorVersion, 1544 AS ConfigurationId, 2048 AS Minimum, 524288 AS Maximum UNION ALL	--max server memory (MB)
			SELECT '10' AS ProductMajorVersion, 50 AS ProductMinorVersion, 1581 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--optimize for ad hoc workloads
			SELECT '10' AS ProductMajorVersion, 50 AS ProductMinorVersion, 1517 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--priority boost
			SELECT '10' AS ProductMajorVersion, 50 AS ProductMinorVersion, 1576 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--remote admin connections
			--SQL2008
			SELECT '10' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1579 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--backup compression default
			SELECT '10' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1562 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--clr enabled
			SELECT '10' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1538 AS ConfigurationId,    6 AS Minimum,  32767 AS Maximum UNION ALL	--cost threshold for parallelism
			SELECT '10' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1546 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--lightweight pooling
			SELECT '10' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1539 AS ConfigurationId,    0 AS Minimum,  32767 AS Maximum UNION ALL	--max degree of parallelism
			SELECT '10' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1544 AS ConfigurationId, 2048 AS Minimum, 524288 AS Maximum UNION ALL	--max server memory (MB)
			SELECT '10' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1581 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum UNION ALL	--optimize for ad hoc workloads
			SELECT '10' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1517 AS ConfigurationId,    0 AS Minimum,      0 AS Maximum UNION ALL	--priority boost
			SELECT '10' AS ProductMajorVersion,  0 AS ProductMinorVersion, 1576 AS ConfigurationId,    1 AS Minimum,      1 AS Maximum				--remote admin connections
		) AS src
		ON (tgt.ProductMajorVersion = src.ProductMajorVersion) AND
			(tgt.ProductMinorVersion = src.ProductMinorVersion) AND
			(tgt.ConfigurationId = src.ConfigurationId)
		WHEN NOT MATCHED BY TARGET
			THEN INSERT (ProductMajorVersion, ProductMinorVersion, ConfigurationId, Minimum, Maximum)
				VALUES(src.ProductMajorVersion, src.ProductMinorVersion, src.ConfigurationId, src.Minimum, src.Maximum);
	END;

	--
	-- Create default trace flag recommendations
	--
	BEGIN
		MERGE dbo.fhsmTraceFlags AS tgt
		USING (
			--SQL2019
			SELECT '15' AS ProductMajorVersion, 0 AS ProductMinorVersion, 3226 AS TraceFlag, 'Supresses logging of successful database backup messages to the SQL Server Error Log' AS Description
				,'https://bit.ly/38zDNAK' AS URL UNION ALL
			SELECT '15' AS ProductMajorVersion, 0 AS ProductMinorVersion, 7745 AS TraceFlag, 'Prevents Query Store data from being written to disk in case of a failover or shutdown command' AS Description
				,'https://bit.ly/2GU69Km' AS URL UNION ALL
			--SQL2017
			SELECT '14' AS ProductMajorVersion, 0 AS ProductMinorVersion,  460 AS TraceFlag, 'Improvement: Optional replacement for "String or binary data would be truncated" message with extended information (added in CU12)' AS Description
				,'https://bit.ly/2sboMli' AS URL UNION ALL
			SELECT '14' AS ProductMajorVersion, 0 AS ProductMinorVersion, 3226 AS TraceFlag, 'Supresses logging of successful database backup messages to the SQL Server Error Log' AS Description
				,'https://bit.ly/38zDNAK' AS URL UNION ALL
			SELECT '14' AS ProductMajorVersion, 0 AS ProductMinorVersion, 7745 AS TraceFlag, 'Prevents Query Store data from being written to disk in case of a failover or shutdown command' AS Description
				,'https://bit.ly/2GU69Km' AS URL UNION ALL
			SELECT '14' AS ProductMajorVersion, 0 AS ProductMinorVersion, 7752 AS TraceFlag, 'Enables asynchronous load of Query Store' AS Description
				,'https://bit.ly/2GU69Km' AS URL UNION ALL
			--SQL2016
			SELECT '13' AS ProductMajorVersion, 0 AS ProductMinorVersion,  460 AS TraceFlag, 'Improvement: Optional replacement for "String or binary data would be truncated" message with extended information (added in SP2 CU6)' AS Description
				,'https://bit.ly/2sboMli' AS URL UNION ALL
			SELECT '13' AS ProductMajorVersion, 0 AS ProductMinorVersion, 3226 AS TraceFlag, 'Supresses logging of successful database backup messages to the SQL Server Error Log' AS Description
				,'https://bit.ly/38zDNAK' AS URL UNION ALL
			SELECT '13' AS ProductMajorVersion, 0 AS ProductMinorVersion, 7745 AS TraceFlag, 'Prevents Query Store data from being written to disk in case of a failover or shutdown command' AS Description
				,'https://bit.ly/2GU69Km' AS URL UNION ALL
			SELECT '13' AS ProductMajorVersion, 0 AS ProductMinorVersion, 7752 AS TraceFlag, 'Enables asynchronous load of Query Store' AS Description
				,'https://bit.ly/2GU69Km' AS URL UNION ALL
			--SQL2014
			SELECT '12' AS ProductMajorVersion, 0 AS ProductMinorVersion, 1117 AS TraceFlag, 'When growing a data file, grow all files at the same time so they remain the same size, reducing allocation contention points' AS Description
				,NULL AS URL UNION ALL
			SELECT '12' AS ProductMajorVersion, 0 AS ProductMinorVersion, 1118 AS TraceFlag, 'Helps alleviate allocation contention in tempdb, SQL Server allocates full extents to each database object, thereby eliminating the contention on SGAM pages' AS Description
				,NULL AS URL UNION ALL
			SELECT '12' AS ProductMajorVersion, 0 AS ProductMinorVersion, 2371 AS TraceFlag, 'Lowers auto update statistics threshold for large tables (on tables with more than 25,000 rows)' AS Description
				,'https://bit.ly/30KO4Hh' AS URL UNION ALL
			SELECT '12' AS ProductMajorVersion, 0 AS ProductMinorVersion, 3226 AS TraceFlag, 'Supresses logging of successful database backup messages to the SQL Server Error Log' AS Description
				,'https://bit.ly/38zDNAK' AS URL UNION ALL
			SELECT '12' AS ProductMajorVersion, 0 AS ProductMinorVersion, 3449 AS TraceFlag, 'Enables use of dirty page manager (SQL Server 2014 SP1 CU7 and later)' AS Description
				,'https://bit.ly/2uj0h5M' AS URL UNION ALL
			SELECT '12' AS ProductMajorVersion, 0 AS ProductMinorVersion, 8079 AS TraceFlag, 'Enables automatic soft-NUMA on systems with eight or more physical cores per NUMA node (with SQL Server 2014 SP2)' AS Description
				,'https://bit.ly/29B7oR8' AS URL UNION ALL
			--SQL2012
			SELECT '11' AS ProductMajorVersion, 0 AS ProductMinorVersion, 1117 AS TraceFlag, 'When growing a data file, grow all files at the same time so they remain the same size, reducing allocation contention points' AS Description
				,NULL AS URL UNION ALL
			SELECT '11' AS ProductMajorVersion, 0 AS ProductMinorVersion, 1118 AS TraceFlag, 'Helps alleviate allocation contention in tempdb, SQL Server allocates full extents to each database object, thereby eliminating the contention on SGAM pages' AS Description
				,NULL AS URL UNION ALL
			SELECT '11' AS ProductMajorVersion, 0 AS ProductMinorVersion, 2371 AS TraceFlag, 'Lowers auto update statistics threshold for large tables (on tables with more than 25,000 rows)' AS Description
				,'https://bit.ly/30KO4Hh' AS URL UNION ALL
			SELECT '11' AS ProductMajorVersion, 0 AS ProductMinorVersion, 3023 AS TraceFlag, 'Enables backup checksum default' AS Description
				,'https://bit.ly/2vtjqqc' AS URL UNION ALL
			SELECT '11' AS ProductMajorVersion, 0 AS ProductMinorVersion, 3226 AS TraceFlag, 'Supresses logging of successful database backup messages to the SQL Server Error Log' AS Description
				,'https://bit.ly/38zDNAK' AS URL UNION ALL
			SELECT '11' AS ProductMajorVersion, 0 AS ProductMinorVersion, 3449 AS TraceFlag, 'Enables use of dirty page manager (SQL Server 2012 SP3 CU3 and later)' AS Description
				,'https://bit.ly/2uj0h5M' AS URL UNION ALL
			SELECT '11' AS ProductMajorVersion, 0 AS ProductMinorVersion, 8079 AS TraceFlag, 'Enables automatic soft-NUMA on systems with eight or more physical cores per NUMA node (with SQL Server 2012 SP4)' AS Description
				,'https://bit.ly/2qN8kr3' AS URL UNION ALL
			--SQL2008R2
			SELECT '10' AS ProductMajorVersion, 50 AS ProductMinorVersion, 1117 AS TraceFlag, 'When growing a data file, grow all files at the same time so they remain the same size, reducing allocation contention points' AS Description
				,NULL AS URL UNION ALL
			SELECT '10' AS ProductMajorVersion, 50 AS ProductMinorVersion, 1118 AS TraceFlag, 'Helps alleviate allocation contention in tempdb, SQL Server allocates full extents to each database object, thereby eliminating the contention on SGAM pages' AS Description
				,NULL AS URL UNION ALL
			SELECT '10' AS ProductMajorVersion, 50 AS ProductMinorVersion, 2371 AS TraceFlag, 'Lowers auto update statistics threshold for large tables (on tables with more than 25,000 rows)' AS Description
				,'https://bit.ly/30KO4Hh' AS URL UNION ALL
			SELECT '10' AS ProductMajorVersion, 50 AS ProductMinorVersion, 3226 AS TraceFlag, 'Supresses logging of successful database backup messages to the SQL Server Error Log' AS Description
				,'https://bit.ly/38zDNAK' AS URL UNION ALL
			--SQL2008
			SELECT '10' AS ProductMajorVersion, 0 AS ProductMinorVersion, 1117 AS TraceFlag, 'When growing a data file, grow all files at the same time so they remain the same size, reducing allocation contention points' AS Description
				,NULL AS URL UNION ALL
			SELECT '10' AS ProductMajorVersion, 0 AS ProductMinorVersion, 1118 AS TraceFlag, 'Helps alleviate allocation contention in tempdb, SQL Server allocates full extents to each database object, thereby eliminating the contention on SGAM pages' AS Description
				,NULL AS URL UNION ALL
			SELECT '10' AS ProductMajorVersion, 0 AS ProductMinorVersion, 2371 AS TraceFlag, 'Lowers auto update statistics threshold for large tables (on tables with more than 25,000 rows)' AS Description
				,'https://bit.ly/30KO4Hh' AS URL UNION ALL
			SELECT '10' AS ProductMajorVersion, 0 AS ProductMinorVersion, 3226 AS TraceFlag, 'Supresses logging of successful database backup messages to the SQL Server Error Log' AS Description
				,'https://bit.ly/38zDNAK' AS URL
		) AS src
		ON (tgt.ProductMajorVersion = src.ProductMajorVersion) AND
			(tgt.ProductMinorVersion = src.ProductMinorVersion) AND
			(tgt.TraceFlag = src.TraceFlag)
		WHEN MATCHED AND (tgt.Description <> src.Description) OR ((tgt.URL <> src.URL) OR (tgt.URL IS NULL AND src.URL IS NOT NULL) OR (tgt.URL IS NOT NULL AND src.URL IS NULL))
			THEN UPDATE SET tgt.Description = src.Description, tgt.URL = src.URL
		WHEN NOT MATCHED BY TARGET
			THEN INSERT (ProductMajorVersion, ProductMinorVersion, TraceFlag, Description, URL)
				VALUES(src.ProductMajorVersion, src.ProductMinorVersion, src.TraceFlag, src.Description, src.URL);
	END;

	--
	-- Create functions
	--

	--
	-- Create views
	--
	BEGIN
		--
		-- Create fact view @pbiSchema.[Agent alerts]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent alerts') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent alerts') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent alerts') + '
				AS
					SELECT
						aa.Description
						,aa.MessageId
						,aa.Severity
						,alertsDetected.AlertName
						,CASE WHEN alertsDetected.MessageId IS NULL THEN 0 ELSE 1 END AS AlertExists	-- 0: Warning; 1: OK
					FROM dbo.fhsmAgentAlerts AS aa
					LEFT OUTER JOIN (
						SELECT
							pvt.Category AS AlertName
							,CAST(pvt.message_id AS int) AS MessageId
							,CAST(pvt.severity AS int) AS Severity
						FROM (
							SELECT iState.Category, iState.[Key], iState.Value AS _Value_
							FROM (
								SELECT DISTINCT iState.Category
								FROM dbo.fhsmInstanceState AS iState
								WHERE
									(iState.Query = 10)
									AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
							) AS toCheck
							INNER JOIN dbo.fhsmInstanceState AS iState ON (iState.Category = toCheck.Category)
							WHERE (iState.Query = 10) AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS p
						PIVOT (
							MAX(_Value_)
							FOR [Key] IN ([message_id], [severity])
						) AS pvt
					) AS alertsDetected ON (alertsDetected.MessageId = aa.MessageId) AND (alertsDetected.Severity = aa.Severity);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Agent alerts]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent alerts');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Agent jobs]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs') + '
				AS
					SELECT
						pvt.Category AS JobName
						,CAST(pvt.job_enabled AS bit) AS JobEnabled
						,CAST(pvt.number_of_enabled_schedules AS int) AS NumberOfEnabledSchedules
						,pvt.job_owner AS JobOwner
						,CAST(pvt.notify_email_operator_id AS int) AS NotifyEmailOperatorId
						,CAST(pvt.notify_level_email AS int) AS NotifyLevelEmail
					FROM (
						SELECT iState.Category, iState.[Key], iState.Value AS _Value_
						FROM (
							SELECT DISTINCT iState.Category
							FROM dbo.fhsmInstanceState AS iState
							WHERE
								(iState.Query = 9)
								AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS toCheck
						INNER JOIN dbo.fhsmInstanceState AS iState ON (iState.Category = toCheck.Category)
						WHERE (iState.Query = 9) AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([job_enabled], [number_of_enabled_schedules], [job_owner], [notify_email_operator_id], [notify_level_email])
					) AS pvt;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Agent jobs]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Agent jobs');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Instance configurations]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance configurations') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance configurations') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance configurations') + '
				AS
					SELECT
						c.ConfigurationId
						,configurationsDetected.name AS Name
						,configurationsDetected.value_in_use AS Value
						,CASE WHEN (configurationsDetected.value_in_use < c.Minimum) OR (configurationsDetected.value_in_use > c.Maximum) THEN 0 ELSE 1 END AS State	-- 0: Warning; 1: OK
					FROM dbo.fhsmInstanceConfigurations AS c
					CROSS APPLY (
						SELECT CAST(iState.Value AS int) AS Value
						FROM dbo.fhsmInstanceState AS iState
						WHERE (iState.Query = 3) AND (iState.[Key] = ''ProductMajorVersion'') AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS productMajorVersion
					CROSS APPLY (
						SELECT CAST(iState.Value AS int) AS Value
						FROM dbo.fhsmInstanceState AS iState
						WHERE (iState.Query = 3) AND (iState.[Key] = ''ProductMinorVersion'') AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS productMinorVersion
					INNER JOIN (
						SELECT pvt.Category, pvt.name, CAST(pvt.value AS int) AS value, CAST(pvt.minimum AS int) AS minimum, CAST(pvt.maximum AS int) AS maximum, CAST(pvt.value_in_use AS int) AS value_in_use, pvt.description, pvt.is_dynamic, pvt.is_advanced
						FROM (
							SELECT iState.Category, iState.[Key], iState.Value AS _Value_
							FROM (
								SELECT DISTINCT iState.Category
								FROM dbo.fhsmInstanceState AS iState
								WHERE
									(iState.Query = 4)
									AND (iState.Category IN (1517, 1538, 1539, 1544, 1546, 1562, 1576, 1579, 1581, 1584, 1585, 1589))
									AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
							) AS toCheck
							INNER JOIN dbo.fhsmInstanceState AS iState ON (iState.Category = toCheck.Category)
							WHERE (iState.Query = 4) AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS p
						PIVOT (
							MAX(_Value_)
							FOR [Key] IN ([name], [value], [minimum], [maximum], [value_in_use], [description], [is_dynamic], [is_advanced])
						) AS pvt
					) AS configurationsDetected ON (configurationsDetected.Category = c.ConfigurationId)
					WHERE (c.ProductMajorVersion = productMajorVersion.Value) AND (c.ProductMinorVersion = productMinorVersion.Value);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Instance configurations]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance configurations');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Instance configurations history]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance configurations history') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance configurations history') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance configurations history') + '
				AS
					SELECT
						c.ConfigurationId
						,configurationsDetected.ValidFrom
						,configurationsDetected.ValidTo
						,latestName.Value AS Name
						,configurationsDetected.value_in_use AS Value
					FROM dbo.fhsmInstanceConfigurations AS c
					CROSS APPLY (
						SELECT CAST(iState.Value AS int) AS Value
						FROM dbo.fhsmInstanceState AS iState
						WHERE (iState.Query = 3) AND (iState.[Key] = ''ProductMajorVersion'') AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS productMajorVersion
					CROSS APPLY (
						SELECT CAST(iState.Value AS int) AS Value
						FROM dbo.fhsmInstanceState AS iState
						WHERE (iState.Query = 3) AND (iState.[Key] = ''ProductMinorVersion'') AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS productMinorVersion
					INNER JOIN (
						SELECT pvt.ValidFrom, pvt.ValidTo, pvt.Category, CAST(pvt.value AS int) AS value, CAST(pvt.value_in_use AS int) AS value_in_use
						FROM (
							SELECT iState.ValidFrom, iState.ValidTo, iState.Category, iState.[Key], iState.Value AS _Value_
							FROM dbo.fhsmInstanceState AS iState
							WHERE
								(iState.Query = 4)
								AND (iState.Category IN (1517, 1538, 1539, 1544, 1546, 1562, 1576, 1579, 1581, 1584, 1585, 1589))
								AND (iState.ValidTo <> ''9999-12-31 23:59:59.000'')
						) AS p
						PIVOT (
							MAX(_Value_)
							FOR [Key] IN ([value], [value_in_use])
						) AS pvt
					) AS configurationsDetected ON (configurationsDetected.Category = c.ConfigurationId)
					INNER JOIN (
						SELECT iState.Category, iState.Value
						FROM dbo.fhsmInstanceState AS iState
						WHERE
							(iState.Query = 4)
							AND (iState.[Key] = ''name'')
							AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS latestName ON (latestName.Category = c.ConfigurationId)
					WHERE (c.ProductMajorVersion = productMajorVersion.Value) AND (c.ProductMinorVersion = productMinorVersion.Value);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Instance configurations history]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance configurations history');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Instance dump files]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance dump files') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance dump files') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance dump files') + '
				AS
					SELECT
						pvt.Category AS Sequence
						,pvt.creation_time AS CreationTime
						,pvt.filename AS Filename
						,CAST(pvt.size_in_bytes AS int) AS SizeInBytes
					FROM (
						SELECT iState.Category, iState.[Key], iState.Value AS _Value_
						FROM dbo.fhsmInstanceState AS iState
						WHERE (iState.Query = 21) AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([creation_time], [filename], [size_in_bytes])
					) AS pvt;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Instance dump files]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance dump files');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Instance hardware]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance hardware') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance hardware') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance hardware') + '
				AS
					SELECT
						CASE iState.[Key]
							WHEN ''cores_per_socket'' THEN ''Cores per socket''
							WHEN ''cpu_count'' THEN ''CPU count''
							WHEN ''max_workers_count'' THEN ''Max workers count''
							WHEN ''numa_node_count'' THEN ''NUMA node count''
							WHEN ''physical_memory_kb'' THEN ''Physical memory MB''
							WHEN ''ProcessorNameString'' THEN ''Processor''
							WHEN ''scheduler_count'' THEN ''Scheduler count''
							WHEN ''socket_count'' THEN ''Socket count''
							WHEN ''sql_memory_model'' THEN ''SQL memory model''
							WHEN ''SQL Server and OS Version Info'' THEN ''SQL Server and OS Version Info''
							WHEN ''sqlserver_start_time'' THEN ''SQL server start time''
							WHEN ''virtual_machine_type'' THEN ''Virtual machine type''
							ELSE ''?:'' + iState.[Key]
						END AS [Key]
						,CASE iState.[Key]
							WHEN ''physical_memory_kb'' THEN CAST((CAST(iState.Value AS int) / 1024) AS nvarchar(max))
							WHEN ''sql_memory_model'' THEN
								CASE iState.Value
									WHEN 1 THEN ''CONVENTIONAL''
									WHEN 2 THEN ''LOCK_PAGES''
									WHEN 3 THEN ''LARGE_PAGES''
									ELSE ''?:'' + CAST(iState.Value AS nvarchar)
								END
							WHEN ''sqlserver_start_time'' THEN CONVERT(nvarchar(max), CAST(iState.Value AS datetime), 126)
							WHEN ''virtual_machine_type'' THEN
								CASE iState.Value
									WHEN 0 THEN ''NONE''
									WHEN 1 THEN ''HYPERVISOR''
									WHEN 2 THEN ''OTHER''
									ELSE ''?:'' + CAST(iState.Value AS nvarchar)
								END
							ELSE iState.Value
						END AS Value
					FROM (
						SELECT iState.[Key], iState.Value
						FROM dbo.fhsmInstanceState AS iState
						WHERE
							(
								(
									(iState.Query = 1)
									AND (iState.[Key] = ''SQL Server and OS Version Info'')
								)
								OR (
									(iState.Query = 17)
									AND (iState.[Key] IN (
										''cores_per_socket''
										,''cpu_count''
										,''max_workers_count''
										,''numa_node_count''
										,''physical_memory_kb''
										,''scheduler_count''
										,''socket_count''
										,''sql_memory_model''
										,''sqlserver_start_time''
										,''virtual_machine_type''
									))
								)
								OR (
									(iState.Query = 20)
								)
							)
							AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS iState;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Instance hardware]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance hardware');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Instance hardware history]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance hardware history') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance hardware history') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance hardware history') + '
				AS
					SELECT
						CASE iState.[Key]
							WHEN ''cores_per_socket'' THEN ''Cores per socket''
							WHEN ''cpu_count'' THEN ''CPU count''
							WHEN ''max_workers_count'' THEN ''Max workers count''
							WHEN ''numa_node_count'' THEN ''NUMA node count''
							WHEN ''physical_memory_kb'' THEN ''Physical memory MB''
							WHEN ''ProcessorNameString'' THEN ''Processor''
							WHEN ''scheduler_count'' THEN ''Scheduler count''
							WHEN ''socket_count'' THEN ''Socket count''
							WHEN ''sql_memory_model'' THEN ''SQL memory model''
							WHEN ''sqlserver_start_time'' THEN ''SQL server start time''
							WHEN ''virtual_machine_type'' THEN ''Virtual machine type''
							ELSE ''?:'' + iState.[Key]
						END AS [Key]
						,iState.ValidFrom
						,iState.ValidTo
						,CASE iState.[Key]
							WHEN ''physical_memory_kb'' THEN CAST((CAST(iState.Value AS int) / 1024) AS nvarchar(max))
							WHEN ''sql_memory_model'' THEN
								CASE iState.Value
									WHEN 1 THEN ''CONVENTIONAL''
									WHEN 2 THEN ''LOCK_PAGES''
									WHEN 3 THEN ''LARGE_PAGES''
									ELSE ''?:'' + CAST(iState.Value AS nvarchar)
								END
							WHEN ''sqlserver_start_time'' THEN CONVERT(nvarchar(max), CAST(iState.Value AS datetime), 126)
							WHEN ''virtual_machine_type'' THEN
								CASE iState.Value
									WHEN 0 THEN ''NONE''
									WHEN 1 THEN ''HYPERVISOR''
									WHEN 2 THEN ''OTHER''
									ELSE ''?:'' + CAST(iState.Value AS nvarchar)
								END
							ELSE iState.Value
						END AS Value
					FROM (
						SELECT iState.ValidFrom, iState.ValidTo, iState.[Key], iState.Value
						FROM dbo.fhsmInstanceState AS iState
						WHERE
							(
								(
									(iState.Query = 17)
									AND (iState.[Key] IN (
										''cores_per_socket''
										,''cpu_count''
										,''max_workers_count''
										,''numa_node_count''
										,''physical_memory_kb''
										,''scheduler_count''
										,''socket_count''
										,''sql_memory_model''
										,''sqlserver_start_time''
										,''virtual_machine_type''
									))
								)
								OR (
									(iState.Query = 20)
								)
							)
							AND (iState.ValidTo <> ''9999-12-31 23:59:59.000'')
					) AS iState;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Instance hardware history]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance hardware history');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Instance services]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance services') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance services') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance services') + '
				AS
					SELECT
						pvt.Category AS Name
						,CASE pvt.startup_type
							WHEN 0 THEN ''Other''
							WHEN 1 THEN ''Other''
							WHEN 2 THEN ''Automatic''
							WHEN 3 THEN ''Manual''
							WHEN 4 THEN ''Disabled''
							ELSE ''?:'' + CAST(pvt.startup_type AS nvarchar)
						END AS StartupType
						,CASE pvt.status
							WHEN 1 THEN ''Stopped''
							WHEN 2 THEN ''Other (start pending)''
							WHEN 3 THEN ''Other (stop pending)''
							WHEN 4 THEN ''Running''
							WHEN 5 THEN ''Other (continue pending)''
							WHEN 6 THEN ''Other (pause pending)''
							WHEN 7 THEN ''Paused''
							ELSE ''?:'' + CAST(pvt.status AS nvarchar)
						END AS Status
						,pvt.service_account AS ServiceAccount
						,CASE pvt.instant_file_initialization_enabled WHEN ''Y'' THEN 1 WHEN ''N'' THEN 0 ELSE -1 END AS InstantFileInitializationEnabled
					FROM (
						SELECT iState.Category, iState.[Key], iState.Value AS _Value_
						FROM (
							SELECT DISTINCT iState.Category
							FROM dbo.fhsmInstanceState AS iState
							WHERE
								(iState.Query = 7)
								AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS toCheck
						INNER JOIN dbo.fhsmInstanceState AS iState ON (iState.Category = toCheck.Category)
						WHERE (iState.Query = 7) AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([startup_type], [status], [service_account], [instant_file_initialization_enabled])
					) AS pvt;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Instance services]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance services');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Instance suspect pages]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance suspect pages') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance suspect pages') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance suspect pages') + '
				AS
					SELECT
						SUBSTRING(pvt.Category, 1, CHARINDEX('':'', pvt.Category) - 1) AS DatabaseName
						,CAST(SUBSTRING(pvt.Category, CHARINDEX('':'', pvt.Category) + 1, LEN(pvt.Category) - CHARINDEX('':'', REVERSE(pvt.Category)) - (CHARINDEX('':'', pvt.Category))) AS int) AS FileId
						,CAST(SUBSTRING(pvt.Category, LEN(pvt.Category) - CHARINDEX('':'', REVERSE(pvt.Category)) + 2, LEN(pvt.Category)) AS bigint) AS PageId
						,CASE pvt.event_type
							WHEN 1 THEN ''An 823 error that causes a suspect page (such as a disk error) or an 824 error other than a bad checksum or a torn page (such as a bad page ID)''
							WHEN 2 THEN ''Bad checksum''
							WHEN 3 THEN ''Torn page''
							WHEN 4 THEN ''Restored (page was restored after it was marked bad)''
							WHEN 5 THEN ''Repaired (DBCC repaired the page)''
							WHEN 7 THEN ''Deallocated by DBCC''
							ELSE ''?:'' + CAST(pvt.event_type AS nvarchar)
						END AS EventType
						,CAST(pvt.error_count AS int) AS ErrorCount
						,pvt.last_update_date AS LastUpdateDate
					FROM (
						SELECT iState.Category, iState.[Key], iState.Value AS _Value_
						FROM dbo.fhsmInstanceState AS iState
						WHERE (iState.Query = 22) AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([event_type], [error_count], [last_update_date])
					) AS pvt;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Instance suspect pages]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Instance suspect pages');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Trace flags]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Trace flags') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Trace flags') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Trace flags') + '
				AS
					SELECT
						tf.TraceFlag
						,tf.Description
						,tf.URL
						,CASE WHEN traceFlagsDetected.TraceFlag IS NULL THEN 0 ELSE 1 END AS TraceFlagExists	-- 0: Warning; 1: OK
					FROM dbo.fhsmTraceFlags AS tf
					CROSS APPLY (
						SELECT CAST(iState.Value AS int) AS Value
						FROM dbo.fhsmInstanceState AS iState
						WHERE (iState.Query = 3) AND (iState.[Key] = ''ProductMajorVersion'') AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS productMajorVersion
					CROSS APPLY (
						SELECT CAST(iState.Value AS int) AS Value
						FROM dbo.fhsmInstanceState AS iState
						WHERE (iState.Query = 3) AND (iState.[Key] = ''ProductMinorVersion'') AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS productMinorVersion
					LEFT OUTER JOIN (
						SELECT CAST(iState.Category AS int) AS TraceFlag
						FROM dbo.fhsmInstanceState AS iState
						WHERE (iState.Query = 5) AND (iState.[Key] = ''Global'') AND (dbo.fhsmFNTryParseAsInt(iState.Value) = 1) AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS traceFlagsDetected ON (traceFlagsDetected.TraceFlag = tf.TraceFlag)
					WHERE (tf.ProductMajorVersion = productMajorVersion.Value) AND (tf.ProductMinorVersion = productMinorVersion.Value);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Trace flags]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Trace flags');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Resource governor configuration]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor configuration') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor configuration') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor configuration') + '
				AS
					SELECT
						pvt.is_enabled AS IsEnabled
						,pvt.max_outstanding_io_per_volume AS MaxOutstandingIOperVolume
						,pvt.ClassifierFunction
						,pvt.ClassifierFunctionDefinition
					FROM (
						SELECT iState.Category, iState.[Key], iState.Value AS _Value_
						FROM (
							SELECT DISTINCT iState.Category
							FROM dbo.fhsmInstanceState AS iState
							WHERE
								(iState.Query = 23)
								AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS toCheck
						INNER JOIN dbo.fhsmInstanceState AS iState ON (iState.Category = toCheck.Category)
						WHERE (iState.Query = 23) AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([is_enabled], [max_outstanding_io_per_volume], [ClassifierFunction], [ClassifierFunctionDefinition])
					) AS pvt;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Resource governor configuration]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor configuration');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Resource governor resource pool affinity]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor resource pool affinity') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor resource pool affinity') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor resource pool affinity') + '
				AS
					SELECT
						pvt.Category AS PoolName
						,pvt.processor_group AS ProcessorGroup
						,pvt.scheduler_mask AS SchedulerMask
					FROM (
						SELECT iState.Category, iState.[Key], iState.Value AS _Value_
						FROM (
							SELECT DISTINCT iState.Category
							FROM dbo.fhsmInstanceState AS iState
							WHERE
								(iState.Query = 24)
								AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS toCheck
						INNER JOIN dbo.fhsmInstanceState AS iState ON (iState.Category = toCheck.Category)
						WHERE (iState.Query = 24) AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([processor_group], [scheduler_mask])
					) AS pvt;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Resource governor resource pool affinity]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor resource pool affinity');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Resource governor resource pools]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor resource pools') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor resource pools') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor resource pools') + '
				AS
					SELECT
						pvt.Category AS PoolName
						,pvt.min_cpu_percent AS MinCPUpercent
						,pvt.max_cpu_percent AS MaxCPUpercent
						,pvt.min_memory_percent AS MinMemoryPercent
						,pvt.max_memory_percent AS MaxMemoryPercent
						,pvt.cap_cpu_percent AS CapCPUpercent
						,pvt.min_iops_per_volume AS MinIOPSperVolume
						,pvt.max_iops_per_volume AS MaxIOPSperVolume
					FROM (
						SELECT iState.Category, iState.[Key], iState.Value AS _Value_
						FROM (
							SELECT DISTINCT iState.Category
							FROM dbo.fhsmInstanceState AS iState
							WHERE
								(iState.Query = 25)
								AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS toCheck
						INNER JOIN dbo.fhsmInstanceState AS iState ON (iState.Category = toCheck.Category)
						WHERE (iState.Query = 25) AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([min_cpu_percent], [max_cpu_percent], [min_memory_percent], [max_memory_percent], [cap_cpu_percent], [min_iops_per_volume], [max_iops_per_volume])
					) AS pvt;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Resource governor resource pools]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor resource pools');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Resource governor workload groups]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor workload groups') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor workload groups') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor workload groups') + '
				AS
					SELECT
						PARSENAME(pvt.Category, 2) AS PoolName
						,PARSENAME(pvt.Category, 1) AS WorkloadGroupName
						,pvt.importance AS Importance
						,pvt.request_max_memory_grant_percent AS RequestMaxMemoryGrantPercent
						,pvt.request_max_cpu_time_sec AS RequestMaxCPUtimeSec
						,pvt.request_memory_grant_timeout_sec AS RequestMemoryGrantTimeoutSec
						,pvt.max_dop AS MaxDOP
						,pvt.group_max_requests AS GroupMaxRequests
						,pvt.request_max_memory_grant_percent_numeric AS RequestMaxMemoryGrantPercentNumeric
					FROM (
						SELECT iState.Category, iState.[Key], iState.Value AS _Value_
						FROM (
							SELECT DISTINCT iState.Category
							FROM dbo.fhsmInstanceState AS iState
							WHERE
								(iState.Query = 26)
								AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS toCheck
						INNER JOIN dbo.fhsmInstanceState AS iState ON (iState.Category = toCheck.Category)
						WHERE (iState.Query = 26) AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([importance], [request_max_memory_grant_percent], [request_max_cpu_time_sec], [request_memory_grant_timeout_sec], [max_dop], [group_max_requests], [request_max_memory_grant_percent_numeric])
					) AS pvt;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Resource governor workload groups]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor workload groups');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Resource governor external resource pool affinity]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor external resource pool affinity') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor external resource pool affinity') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor external resource pool affinity') + '
				AS
					SELECT
						pvt.Category AS PoolName
						,pvt.processor_group AS ProcessorGroup
						,pvt.cpu_mask AS CPUmask
					FROM (
						SELECT iState.Category, iState.[Key], iState.Value AS _Value_
						FROM (
							SELECT DISTINCT iState.Category
							FROM dbo.fhsmInstanceState AS iState
							WHERE
								(iState.Query = 27)
								AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS toCheck
						INNER JOIN dbo.fhsmInstanceState AS iState ON (iState.Category = toCheck.Category)
						WHERE (iState.Query = 27) AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([processor_group], [cpu_mask])
					) AS pvt;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Resource governor external resource pool affinity]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor external resource pool affinity');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Resource governor external resource pools]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor external resource pools') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor external resource pools') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor external resource pools') + '
				AS
					SELECT
						pvt.Category AS PoolName
						,pvt.max_cpu_percent AS MaxCPUpercent
						,pvt.max_memory_percent AS MaxMemoryPercent
						,pvt.max_processes AS MaxProcesses
						,pvt.version AS Version
					FROM (
						SELECT iState.Category, iState.[Key], iState.Value AS _Value_
						FROM (
							SELECT DISTINCT iState.Category
							FROM dbo.fhsmInstanceState AS iState
							WHERE
								(iState.Query = 28)
								AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
						) AS toCheck
						INNER JOIN dbo.fhsmInstanceState AS iState ON (iState.Category = toCheck.Category)
						WHERE (iState.Query = 28) AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS p
					PIVOT (
						MAX(_Value_)
						FOR [Key] IN ([max_cpu_percent], [max_memory_percent], [max_processes], [version])
					) AS pvt;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Resource governor external resource pools]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Resource governor external resource pools');
			SET @objName = PARSENAME(@objectName, 1);
			SET @schName = PARSENAME(@objectName, 2);

			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMVersion', @propertyValue = @version;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreated', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 0, @propertyName = 'FHSMCreatedBy', @propertyValue = @myUserName;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModified', @propertyValue = @nowUTCStr;
			EXEC dbo.fhsmSPExtendedProperties @objectType = 'View', @level0name = @schName, @level1name = @objName, @updateIfExists = 1, @propertyName = 'FHSMModifiedBy', @propertyValue = @myUserName;
		END;

		--
		-- Create fact view @pbiSchema.[Trace flags history]
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Trace flags history') + ''', ''V'') IS NULL
				BEGIN
					EXEC(''CREATE VIEW ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Trace flags history') + ' AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER VIEW  ' + QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Trace flags history') + '
				AS
					SELECT
						tf.TraceFlag
						,tf.Description
						,traceFlags.ValidFrom
						,traceFlags.ValidTo
					FROM dbo.fhsmTraceFlags AS tf
					CROSS APPLY (
						SELECT CAST(iState.Value AS int) AS Value
						FROM dbo.fhsmInstanceState AS iState
						WHERE (iState.Query = 3) AND (iState.[Key] = ''ProductMajorVersion'') AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS productMajorVersion
					CROSS APPLY (
						SELECT CAST(iState.Value AS int) AS Value
						FROM dbo.fhsmInstanceState AS iState
						WHERE (iState.Query = 3) AND (iState.[Key] = ''ProductMinorVersion'') AND (iState.ValidTo = ''9999-12-31 23:59:59.000'')
					) AS productMinorVersion
					INNER JOIN (
						SELECT iState.ValidFrom, iState.ValidTo, CAST(iState.Category AS int) AS TraceFlag
						FROM dbo.fhsmInstanceState AS iState
						WHERE (iState.Query = 5) AND (iState.[Key] = ''Global'') AND (dbo.fhsmFNTryParseAsInt(iState.Value) = 1) AND (iState.ValidTo <> ''9999-12-31 23:59:59.000'')
					) AS traceFlags ON (traceFlags.TraceFlag = tf.TraceFlag)
					WHERE (tf.ProductMajorVersion = productMajorVersion.Value) AND (tf.ProductMinorVersion = productMinorVersion.Value);
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on fact view @pbiSchema.[Trace flags history]
		--
		BEGIN
			SET @objectName = QUOTENAME(@pbiSchema) + '.' + QUOTENAME('Trace flags history');
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
		-- Create stored procedure dbo.fhsmSPInstanceState
		--
		BEGIN
			SET @stmt = '
				IF OBJECT_ID(''dbo.fhsmSPInstanceState'', ''P'') IS NULL
				BEGIN
					EXEC(''CREATE PROC dbo.fhsmSPInstanceState AS SELECT ''''dummy'''' AS Txt'');
				END;
			';
			EXEC(@stmt);

			SET @stmt = '
				ALTER PROC dbo.fhsmSPInstanceState (
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

					--******************************************************************************
					--*   Copyright (C) 2020 Glenn Berry
					--*   All rights reserved. 
					--*
					--*
					--*   You may alter this code for your own *non-commercial* purposes. You may
					--*   republish altered code as long as you include this copyright and give due credit. 
					--*
					--*
					--*   THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF 
					--*   ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED 
					--*   TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
					--*   PARTICULAR PURPOSE. 
					--*
					--******************************************************************************

					--
					-- Get the parameters for the command
					--
					BEGIN
						SET @parameters = dbo.fhsmFNGetTaskParameter(@thisTask, @name);
					END;

					--
					-- Collect data
					--
					BEGIN
						SELECT
							@now = SYSDATETIME()
							,@nowUTC = SYSUTCDATETIME();

						IF (OBJECT_ID(''tempdb..#inventory'') IS NOT NULL) DROP TABLE #inventory;

						CREATE TABLE #inventory(
							Query int NOT NULL
							,Category nvarchar(128) NOT NULL
							,[Key] nvarchar(128) NOT NULL
							,Value nvarchar(max) NULL
							,PRIMARY KEY(Query, Category, [Key])
						);

						DECLARE @xpReadErrorLog TABLE(LogDate datetime, ProcessorInfo nvarchar(128), Text nvarchar(max));
						DECLARE @xpReadReg TABLE(Value nvarchar(128), Data nvarchar(max));

						--
						-- SQL and OS Version information for current instance  (Query 1) (Version Info)
						--
						BEGIN
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 1 AS Query, '''' AS Category, ''Server Name''                    AS K, @@SERVERNAME AS V UNION ALL
							SELECT 1 AS Query, '''' AS Category, ''SQL Server and OS Version Info'' AS K, @@VERSION    AS V;
						END;

						--
						-- Get socket, physical core and logical core count from the SQL Server Error log. (Query 2) (Core Counts)
						--
						BEGIN
							DELETE @xpReadErrorLog;
							INSERT INTO @xpReadErrorLog
							EXEC sys.xp_readerrorlog 0, 1, N''detected'', N''socket'';
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 2 AS Query, '''' AS Category, ''LogDate''       AS K, CONVERT(nvarchar(max), q.LogDate, 126) AS V FROM @xpReadErrorLog AS q UNION ALL
							SELECT 2 AS Query, '''' AS Category, ''ProcessorInfo'' AS K, q.ProcessorInfo                        AS V FROM @xpReadErrorLog AS q UNION ALL
							SELECT 2 AS Query, '''' AS Category, ''Text''          AS K, q.Text                                 AS V FROM @xpReadErrorLog AS q;
						END;

						--
						-- Get selected server properties (Query 3) (Server Properties)
						--
						BEGIN
                            WITH
							productVersion AS (SELECT CAST(SERVERPROPERTY(''ProductVersion'') AS nvarchar(max)) AS Str),
							productVersionP1 AS (SELECT t.Txt AS Str FROM dbo.fhsmFNSplitString((SELECT a.Str FROM productVersion AS a), ''.'') AS t WHERE (t.Part = 1)),
							productVersionP2 AS (SELECT t.Txt AS Str FROM dbo.fhsmFNSplitString((SELECT a.Str FROM productVersion AS a), ''.'') AS t WHERE (t.Part = 2)),
							productVersionP3 AS (SELECT t.Txt AS Str FROM dbo.fhsmFNSplitString((SELECT a.Str FROM productVersion AS a), ''.'') AS t WHERE (t.Part = 3))
							INSERT INTO #inventory(Query, Category, [Key], Value)
                            SELECT 3 AS Query, '''' AS Category, ''MachineName''                     AS K, CAST(SERVERPROPERTY(''MachineName'') AS nvarchar(max))                     AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''ServerName''                      AS K, CAST(SERVERPROPERTY(''ServerName'') AS nvarchar(max))                      AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''InstanceName''                    AS K, CAST(SERVERPROPERTY(''InstanceName'') AS nvarchar(max))                    AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''IsClustered''                     AS K, CAST(SERVERPROPERTY(''IsClustered'') AS nvarchar(max))                     AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''ComputerNamePhysicalNetBIOS''     AS K, CAST(SERVERPROPERTY(''ComputerNamePhysicalNetBIOS'') AS nvarchar(max))     AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''Edition''                         AS K, CAST(SERVERPROPERTY(''Edition'') AS nvarchar(max))                         AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''ProductLevel''                    AS K, CAST(SERVERPROPERTY(''ProductLevel'') AS nvarchar(max))                    AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''ProductUpdateLevel''              AS K, CAST(SERVERPROPERTY(''ProductUpdateLevel'') AS nvarchar(max))              AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''ProductVersion''                  AS K, (SELECT t.Str FROM productVersion   AS t)                                  AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''ProductMajorVersion''             AS K, (SELECT t.Str FROM productVersionP1 AS t)                                  AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''ProductMinorVersion''             AS K, (SELECT t.Str FROM productVersionP2 AS t)                                  AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''ProductBuild''                    AS K, (SELECT t.Str FROM productVersionP3 AS t)                                  AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''ProductBuildType''                AS K, CAST(SERVERPROPERTY(''ProductBuildType'') AS nvarchar(max))                AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''ProductUpdateReference''          AS K, CAST(SERVERPROPERTY(''ProductUpdateReference'') AS nvarchar(max))          AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''ProcessID''                       AS K, CAST(SERVERPROPERTY(''ProcessID'') AS nvarchar(max))                       AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''Collation''                       AS K, CAST(SERVERPROPERTY(''Collation'') AS nvarchar(max))                       AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''IsFullTextInstalled''             AS K, CAST(SERVERPROPERTY(''IsFullTextInstalled'') AS nvarchar(max))             AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''IsIntegratedSecurityOnly''        AS K, CAST(SERVERPROPERTY(''IsIntegratedSecurityOnly'') AS nvarchar(max))        AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''FilestreamConfiguredLevel''       AS K, CAST(SERVERPROPERTY(''FilestreamConfiguredLevel'') AS nvarchar(max))       AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''IsHadrEnabled''                   AS K, CAST(SERVERPROPERTY(''IsHadrEnabled'') AS nvarchar(max))                   AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''HadrManagerStatus''               AS K, CAST(SERVERPROPERTY(''HadrManagerStatus'') AS nvarchar(max))               AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''InstanceDefaultDataPath''         AS K, CAST(SERVERPROPERTY(''InstanceDefaultDataPath'') AS nvarchar(max))         AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''InstanceDefaultLogPath''          AS K, CAST(SERVERPROPERTY(''InstanceDefaultLogPath'') AS nvarchar(max))          AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''BuildClrVersion''                 AS K, CAST(SERVERPROPERTY(''BuildClrVersion'') AS nvarchar(max))                 AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''IsXTPSupported''                  AS K, CAST(SERVERPROPERTY(''IsXTPSupported'') AS nvarchar(max))                  AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''IsPolybaseInstalled''             AS K, CAST(SERVERPROPERTY(''IsPolybaseInstalled'') AS nvarchar(max))             AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''IsAdvancedAnalyticsInstalled''    AS K, CAST(SERVERPROPERTY(''IsAdvancedAnalyticsInstalled'') AS nvarchar(max))    AS V UNION ALL
                            SELECT 3 AS Query, '''' AS Category, ''IsTempdbMetadataMemoryOptimized'' AS K, CAST(SERVERPROPERTY(''IsTempdbMetadataMemoryOptimized'') AS nvarchar(max)) AS V;
						END;

						--
						-- Get instance-level configuration values for instance  (Query 4) (Configuration Values)
						--
						BEGIN
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 4 AS Query, unpvt.configuration_id AS Category, unpvt.K, unpvt.V
							FROM (
								SELECT
									configuration_id
									,CAST(c.name COLLATE DATABASE_DEFAULT                               AS nvarchar(max)) AS name
									,CAST(c.value                                                       AS nvarchar(max)) AS value
									,CAST(c.value_in_use                                                AS nvarchar(max)) AS value_in_use
									,CAST(c.minimum                                                     AS nvarchar(max)) AS minimum
									,CAST(c.maximum                                                     AS nvarchar(max)) AS maximum
									,CAST(CAST(c.description AS nvarchar(max)) COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS description
									,CAST(c.is_dynamic                                                  AS nvarchar(max)) AS is_dynamic
									,CAST(c.is_advanced                                                 AS nvarchar(max)) AS is_advanced
								FROM sys.configurations AS c WITH (NOLOCK)
							) AS p
							UNPIVOT(
								V FOR K IN (
									p.name
									,p.value
									,p.value_in_use
									,p.minimum
									,p.maximum
									,p.description
									,p.is_dynamic
									,p.is_advanced
								)
							) AS unpvt OPTION (RECOMPILE);
						END;

						--
						-- Returns a list of all global trace flags that are enabled (Query 5) (Global Trace Flags)
						--
						BEGIN
							DECLARE @tracestatus TABLE(TraceFlag nvarchar(40), Status tinyint, Global tinyint, Session tinyint);
							INSERT INTO @tracestatus 
							EXEC(''dbcc tracestatus'');
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 5 AS Query, unpvt.TraceFlag AS Category, unpvt.K, unpvt.V
							FROM (
								SELECT
									t.TraceFlag
									,t.Status
									,t.Global
									,t.Session
								FROM @tracestatus AS t
							) AS p
							UNPIVOT(
								V FOR K IN (
									p.Status
									,p.Global
									,p.Session
								)
							) AS unpvt OPTION (RECOMPILE);
						END;

						--
						-- SQL Server Services information (Query 7) (SQL Server Services Info)
						--
						IF EXISTS(SELECT * FROM master.sys.system_objects AS so WHERE (so.name = ''dm_server_services''))
						BEGIN
							--
							-- Test if instant_file_initialization_enabled exists on dm_server_services
							--
							BEGIN
								DECLARE @instantFileInitializationEnabledStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''dm_server_services'') AND (sc.name = ''instant_file_initialization_enabled'')
								)
								BEGIN
									SET @instantFileInitializationEnabledStmt = ''dss.instant_file_initialization_enabled'';
								END
								ELSE BEGIN
									SET @instantFileInitializationEnabledStmt = ''CAST(NULL AS nvarchar(1))'';
								END;
							END;

							SET @stmt = ''
								INSERT INTO #inventory(Query, Category, [Key], Value)
								SELECT 7 AS Query, unpvt.servicename AS Category, unpvt.K, unpvt.V
								FROM (
									SELECT
										dss.servicename
										,CAST(dss.startup_type                                                 AS nvarchar(max)) AS startup_type
										,CAST(dss.status                                                       AS nvarchar(max)) AS status
										,CAST(dss.process_id                                                   AS nvarchar(max)) AS process_id
										,CONVERT(nvarchar(max), dss.last_startup_time, 126)                                      AS last_startup_time
										,CAST(dss.service_account                     COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS service_account
										,CAST(dss.filename                            COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS filename
										,CAST(dss.is_clustered                        COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS is_clustered
										,CAST(dss.cluster_nodename                    COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS cluster_nodename
										,CAST('' + @instantFileInitializationEnabledStmt + '' COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS instant_file_initialization_enabled
									FROM sys.dm_server_services AS dss WITH (NOLOCK)
								) AS p
								UNPIVOT(
									V FOR K IN (
										p.startup_type
										,p.status
										,p.process_id
										,p.last_startup_time
										,p.service_account
										,p.filename
										,p.is_clustered
										,p.cluster_nodename
										,p.instant_file_initialization_enabled
									)
								) AS unpvt OPTION (RECOMPILE);
							'';
							EXEC(@stmt);
						END;

						--
						-- Get SQL Server Agent jobs and Category information (Query 9) (SQL Server Agent Jobs)
						--
						BEGIN
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 9 AS Query, unpvt.job_name AS Category, unpvt.K, unpvt.V
							FROM (
								SELECT
									sj.name AS job_name
									,CAST(sj.enabled                              AS nvarchar(max)) AS job_enabled
									,CAST(sj.description COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS description
									,CAST(SUSER_SNAME(sj.owner_sid)               AS nvarchar(max)) AS job_owner
									,CAST(sj.notify_level_email                   AS nvarchar(max)) AS notify_level_email
									,CAST(sj.notify_email_operator_id             AS nvarchar(max)) AS notify_email_operator_id
									,CONVERT(nvarchar(max), sj.date_created, 126)                   AS date_created
									,CAST(sc.name COLLATE DATABASE_DEFAULT        AS nvarchar(max)) AS category_name
									,(
										SELECT CAST(SUM(enabledSchedules.Cnt) AS nvarchar(max)) FROM (
											SELECT 1 AS Cnt
											FROM msdb.dbo.sysjobschedules AS js WITH (NOLOCK)
											INNER JOIN msdb.dbo.sysschedules AS s WITH (NOLOCK) ON (js.schedule_id = s.schedule_id)
											WHERE (js.job_id = sj.job_id) AND (s.enabled = 1)
										) AS enabledSchedules
									) AS number_of_enabled_schedules
								FROM msdb.dbo.sysjobs AS sj WITH (NOLOCK)
								INNER JOIN msdb.dbo.syscategories AS sc WITH (NOLOCK) ON (sj.category_id = sc.category_id)
							) AS p
							UNPIVOT(
								V FOR K IN (
									p.job_enabled
									,p.description
									,p.job_owner
									,p.notify_level_email
									,p.notify_email_operator_id
									,p.date_created
									,p.category_name
									,p.number_of_enabled_schedules
								)
							) AS unpvt OPTION (RECOMPILE);
						END;

						--
						-- Get SQL Server Agent Alert Information (Query 10) (SQL Server Agent Alerts)
						--
						BEGIN
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 10 AS Query, unpvt.name AS Category, unpvt.K, unpvt.V
							FROM (
								SELECT
									 CAST(sa.name                                  AS nvarchar(max)) AS name
									,CAST(sa.message_id                            AS nvarchar(max)) AS message_id
									,CAST(sa.event_source COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS event_source
									,CAST(sa.severity                              AS nvarchar(max)) AS severity
									,CAST(sa.enabled                               AS nvarchar(max)) AS enabled
									,CAST(sa.delay_between_responses               AS nvarchar(max)) AS delay_between_responses
									,CAST(sa.last_occurrence_date                  AS nvarchar(max)) AS last_occurrence_date
									,CAST(sa.last_occurrence_time                  AS nvarchar(max)) AS last_occurrence_time
									,CAST(sa.occurrence_count                      AS nvarchar(max)) AS occurrence_count
									,CAST(sa.has_notification                      AS nvarchar(max)) AS has_notification
								FROM msdb.dbo.sysalerts AS sa WITH (NOLOCK)
							) AS p
							UNPIVOT(
								V FOR K IN (
									p.message_id
									,p.event_source
									,p.severity
									,p.enabled
									,p.delay_between_responses
									,p.last_occurrence_date
									,p.last_occurrence_time
									,p.occurrence_count
									,p.has_notification
								)
							) AS unpvt OPTION (RECOMPILE);
						END;

						--
						-- Host information (Query 11) (Host Info)
						--
						BEGIN
							--
							-- Test if object dm_os_host_info exists
							--
							IF EXISTS(
								SELECT *
								FROM master.sys.system_objects AS so
								WHERE (so.name = ''dm_os_host_info'')
							)
							BEGIN
								SET @stmt = ''
									INSERT INTO #inventory(Query, Category, [Key], Value)
									SELECT 11 AS Query, '''''''' AS Category, unpvt.K, unpvt.V
									FROM (
										SELECT
											 CAST(dohi.host_platform           COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS host_platform
											,CAST(dohi.host_distribution       COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS host_distribution
											,CAST(dohi.host_release            COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS host_release
											,CAST(dohi.host_service_pack_level COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS host_service_pack_level
											,CAST(dohi.host_sku                                         AS nvarchar(max)) AS host_sku
											,CAST(dohi.os_language_version                              AS nvarchar(max)) AS os_language_version
										FROM sys.dm_os_host_info AS dohi WITH (NOLOCK)
									) AS p
									UNPIVOT(
										V FOR K IN (
											p.host_platform
											,p.host_distribution
											,p.host_release
											,p.host_service_pack_level
											,p.host_sku
											,p.os_language_version
										)
									) AS unpvt OPTION (RECOMPILE);
								'';
								EXEC(@stmt);
							END
						END;

						--
						-- SQL Server NUMA Node information  (Query 12) (SQL Server NUMA Info)
						--
						BEGIN
							--
							-- Test if online_scheduler_mask exists on dm_os_nodes
							--
							BEGIN
								DECLARE @onlineSchedulerMaskStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''dm_os_nodes'') AND (sc.name = ''online_scheduler_mask'')
								)
								BEGIN
									SET @onlineSchedulerMaskStmt = ''don.online_scheduler_mask'';
								END
								ELSE BEGIN
									SET @onlineSchedulerMaskStmt = ''NULL'';
								END;
							END;

							--
							-- Test if processor_group exists on dm_os_nodes
							--
							BEGIN
								DECLARE @processorGroupStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''dm_os_nodes'') AND (sc.name = ''processor_group'')
								)
								BEGIN
									SET @processorGroupStmt = ''don.processor_group'';
								END
								ELSE BEGIN
									SET @processorGroupStmt = ''NULL'';
								END;
							END;

							--
							-- Test if cpu_count exists on dm_os_nodes
							--
							BEGIN
								DECLARE @cpuCountStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''dm_os_nodes'') AND (sc.name = ''cpu_count'')
								)
								BEGIN
									SET @cpuCountStmt = ''don.cpu_count'';
								END
								ELSE BEGIN
									SET @cpuCountStmt = ''NULL'';
								END;
							END;

							SET @stmt = ''
								INSERT INTO #inventory(Query, Category, [Key], Value)
								SELECT 12 AS Query, unpvt.node_id AS Category, unpvt.K, unpvt.V
								FROM (
									SELECT
										CAST(don.node_id                       AS nvarchar(max)) AS node_id
										,CAST(don.memory_node_id               AS nvarchar(max)) AS memory_node_id
										,CAST(don.cpu_affinity_mask            AS nvarchar(max)) AS cpu_affinity_mask
										,CAST(don.online_scheduler_count       AS nvarchar(max)) AS online_scheduler_count
										,CAST(don.timer_task_affinity_mask     AS nvarchar(max)) AS timer_task_affinity_mask
										,CAST(don.permanent_task_affinity_mask AS nvarchar(max)) AS permanent_task_affinity_mask
										,CAST(don.resource_monitor_state       AS nvarchar(max)) AS resource_monitor_state
										,CAST('' + @onlineSchedulerMaskStmt + '' AS nvarchar(max)) AS online_scheduler_mask
										,CAST('' + @processorGroupStmt + '' AS nvarchar(max)) AS processor_group
										,CAST('' + @cpuCountStmt + '' AS nvarchar(max)) AS cpu_count
									FROM sys.dm_os_nodes AS don WITH (NOLOCK) 
									WHERE (don.node_state_desc <> N''''ONLINE DAC'''')
								) AS p
								UNPIVOT(
									V FOR K IN (
										p.memory_node_id
										,p.cpu_affinity_mask
										,p.online_scheduler_count
										,p.timer_task_affinity_mask
										,p.permanent_task_affinity_mask
										,p.resource_monitor_state
										,p.online_scheduler_mask
										,p.processor_group
										,p.cpu_count
									)
								) AS unpvt OPTION (RECOMPILE);
							'';
							EXEC(@stmt);
						END;

						--
						-- Hardware information from SQL Server 2019  (Query 17) (Hardware Info)
						--
						BEGIN
							--
							-- Test if physical_memory_kb exists on dm_os_sys_info
							--
							BEGIN
								DECLARE @physicalMemoryKBStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''dm_os_sys_info'') AND (sc.name = ''physical_memory_kb'')
								)
								BEGIN
									SET @physicalMemoryKBStmt = ''dosi.physical_memory_kb'';
								END
								ELSE BEGIN
									SET @physicalMemoryKBStmt = ''NULL'';
								END;
							END;

							--
							-- Test if affinity_type exists on dm_os_sys_info
							--
							BEGIN
								DECLARE @affinityTypeStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''dm_os_sys_info'') AND (sc.name = ''affinity_type'')
								)
								BEGIN
									SET @affinityTypeStmt = ''dosi.affinity_type'';
								END
								ELSE BEGIN
									SET @affinityTypeStmt = ''NULL'';
								END;
							END;

							--
							-- Test if virtual_machine_type exists on dm_os_sys_info
							--
							BEGIN
								DECLARE @virtualMachineTypeStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''dm_os_sys_info'') AND (sc.name = ''virtual_machine_type'')
								)
								BEGIN
									SET @virtualMachineTypeStmt = ''dosi.virtual_machine_type'';
								END
								ELSE BEGIN
									SET @virtualMachineTypeStmt = ''NULL'';
								END;
							END;

							--
							-- Test if softnuma_configuration exists on dm_os_sys_info
							--
							BEGIN
								DECLARE @softnumaConfigurationStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''dm_os_sys_info'') AND (sc.name = ''softnuma_configuration'')
								)
								BEGIN
									SET @softnumaConfigurationStmt = ''dosi.softnuma_configuration'';
								END
								ELSE BEGIN
									SET @softnumaConfigurationStmt = ''NULL'';
								END;
							END;

							--
							-- Test if sql_memory_model exists on dm_os_sys_info
							--
							BEGIN
								DECLARE @sqlMemoryModelStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''dm_os_sys_info'') AND (sc.name = ''sql_memory_model'')
								)
								BEGIN
									SET @sqlMemoryModelStmt = ''dosi.sql_memory_model'';
								END
								ELSE BEGIN
									SET @sqlMemoryModelStmt = ''NULL'';
								END;
							END;

							--
							-- Test if socket_count exists on dm_os_sys_info
							--
							BEGIN
								DECLARE @socketCountStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''dm_os_sys_info'') AND (sc.name = ''socket_count'')
								)
								BEGIN
									SET @socketCountStmt = ''dosi.socket_count'';
								END
								ELSE BEGIN
									SET @socketCountStmt = ''NULL'';
								END;
							END;

							--
							-- Test if cores_per_socket exists on dm_os_sys_info
							--
							BEGIN
								DECLARE @coresPerSocketStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''dm_os_sys_info'') AND (sc.name = ''cores_per_socket'')
								)
								BEGIN
									SET @coresPerSocketStmt = ''dosi.cores_per_socket'';
								END
								ELSE BEGIN
									SET @coresPerSocketStmt = ''NULL'';
								END;
							END;

							--
							-- Test if numa_node_count exists on dm_os_sys_info
							--
							BEGIN
								DECLARE @numaNodeCountStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''dm_os_sys_info'') AND (sc.name = ''numa_node_count'')
								)
								BEGIN
									SET @numaNodeCountStmt = ''dosi.numa_node_count'';
								END
								ELSE BEGIN
									SET @numaNodeCountStmt = ''NULL'';
								END;
							END;

							--
							-- Test if container_type exists on dm_os_sys_info
							--
							BEGIN
								DECLARE @containerTypeStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''dm_os_sys_info'') AND (sc.name = ''container_type'')
								)
								BEGIN
									SET @containerTypeStmt = ''dosi.container_type'';
								END
								ELSE BEGIN
									SET @containerTypeStmt = ''NULL'';
								END;
							END;

							SET @stmt = ''
								INSERT INTO #inventory(Query, Category, [Key], Value)
								SELECT 17 AS Query, '''''''' AS Category, unpvt.K, unpvt.V
								FROM (
									SELECT
										CAST(dosi.cpu_count AS nvarchar(max)) AS cpu_count
										,CAST(dosi.hyperthread_ratio AS nvarchar(max)) AS hyperthread_ratio
										,CAST('' + @physicalMemoryKBStmt + '' AS nvarchar(max)) AS physical_memory_kb
										,CAST(dosi.max_workers_count AS nvarchar(max)) AS max_workers_count
										,CAST(dosi.scheduler_count AS nvarchar(max)) AS scheduler_count
										,CAST(dosi.sqlserver_start_time AS nvarchar(max)) AS sqlserver_start_time
										,CAST('' + @affinityTypeStmt + '' AS nvarchar(max)) AS affinity_type
										,CAST('' + @virtualMachineTypeStmt + '' AS nvarchar(max)) AS virtual_machine_type
										,CAST('' + @softnumaConfigurationStmt + '' AS nvarchar(max)) AS softnuma_configuration
										,CAST('' + @sqlMemoryModelStmt + '' AS nvarchar(max)) AS sql_memory_model
										,CAST('' + @socketCountStmt + '' AS nvarchar(max)) AS socket_count
										,CAST('' + @coresPerSocketStmt + '' AS nvarchar(max)) AS cores_per_socket
										,CAST('' + @numaNodeCountStmt + '' AS nvarchar(max)) AS numa_node_count
										,CAST('' + @containerTypeStmt + '' AS nvarchar(max)) AS container_type
									FROM sys.dm_os_sys_info AS dosi WITH (NOLOCK)
								) AS p
								UNPIVOT(
									V FOR K IN (
										p.cpu_count
										,p.hyperthread_ratio
										,p.physical_memory_kb
										,p.max_workers_count
										,p.scheduler_count
										,p.sqlserver_start_time
										,p.affinity_type
										,p.virtual_machine_type
										,p.softnuma_configuration
										,p.sql_memory_model
										,p.socket_count
										,p.cores_per_socket
										,p.numa_node_count
										,p.container_type
									)
								) AS unpvt OPTION (RECOMPILE);
							'';
							EXEC(@stmt);
						END;

						--
						-- Get System Manufacturer and model number from SQL Server Error log (Query 18) (System Manufacturer)
						--
						BEGIN
							DELETE @xpReadErrorLog;
							INSERT INTO @xpReadErrorLog
							EXEC sys.xp_readerrorlog 0, 1, N''Manufacturer'';
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 18 AS Query, '''' AS Category, ''LogDate''       AS K, CONVERT(nvarchar(max), q.LogDate, 126) AS V FROM @xpReadErrorLog AS q UNION ALL
							SELECT 18 AS Query, '''' AS Category, ''ProcessorInfo'' AS K, q.ProcessorInfo                        AS V FROM @xpReadErrorLog AS q UNION ALL
							SELECT 18 AS Query, '''' AS Category, ''Text''          AS K, q.Text                                 AS V FROM @xpReadErrorLog AS q;
						END;

						--
						-- Get BIOS date from Windows Registry (Query 19) (BIOS Date)
						--
						BEGIN
							DELETE @xpReadReg;
							INSERT INTO @xpReadReg
							EXEC sys.xp_instance_regread N''HKEY_LOCAL_MACHINE'', N''HARDWARE\DESCRIPTION\System\BIOS'', N''BiosReleaseDate'';
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 19 AS Query, '''' AS Category, ''BiosReleaseDate'' AS K, q.Data AS V FROM @xpReadReg AS q;
						END;

						--
						-- Get processor description from Windows Registry  (Query 20) (Processor Description)
						--
						BEGIN
							DELETE @xpReadReg;
							INSERT INTO @xpReadReg
							EXEC sys.xp_instance_regread N''HKEY_LOCAL_MACHINE'', N''HARDWARE\DESCRIPTION\System\CentralProcessor\0'', N''ProcessorNameString'';
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 20 AS Query, '''' AS Category, ''ProcessorNameString'' AS K, q.Data AS V FROM @xpReadReg AS q;
						END;

						--
						-- Get information on location, time and size of any memory dumps from SQL Server  (Query 21) (Memory Dump Info)
						--
						IF EXISTS(SELECT * FROM master.sys.system_objects AS so WHERE (so.name = ''dm_server_memory_dumps''))
						BEGIN
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 21 AS Query, unpvt.Rnk AS Category, unpvt.K, unpvt.V
							FROM (
								SELECT
									 CAST(dsmd.filename COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS filename
									,CONVERT(nvarchar(max), dsmd.creation_time, 126)               AS creation_time
									,CAST(dsmd.size_in_bytes                     AS nvarchar(max)) AS size_in_bytes
									,ROW_NUMBER() OVER(ORDER BY dsmd.creation_time)                AS Rnk
								FROM sys.dm_server_memory_dumps AS dsmd WITH (NOLOCK) 
							) AS p
							UNPIVOT(
								V FOR K IN (
									p.filename
									,p.creation_time
									,p.size_in_bytes
								)
							) AS unpvt OPTION (RECOMPILE);
						END;

						--
						-- Look at Suspect Pages table (Query 22) (Suspect Pages)
						--
						BEGIN
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 22 AS Query, unpvt.database_file_page AS Category, unpvt.K, unpvt.V
							FROM (
								SELECT
									CAST(DB_NAME(sp.database_id) AS nvarchar(max)) + '':'' +  CAST(sp.file_id AS nvarchar(max)) + '':'' + CAST(sp.page_id AS nvarchar(max)) AS database_file_page
									,CAST(sp.event_type AS nvarchar(max)) AS event_type
									,CAST(sp.error_count AS nvarchar(max)) AS error_count
									,CONVERT(nvarchar(max), sp.last_update_date, 126) AS last_update_date
								FROM msdb.dbo.suspect_pages AS sp WITH (NOLOCK)
							) AS p
							UNPIVOT(
								V FOR K IN (
									p.event_type
									,p.error_count
									,p.last_update_date
								)
							) AS unpvt OPTION (RECOMPILE);
						END;

						--
						-- Look at Resource Governor configuration
						--
						BEGIN
							--
							-- Test if max_outstanding_io_per_volume exists on resource_governor_configuration
							--
							BEGIN
								DECLARE @maxOutstandingIOperVolumeStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''resource_governor_configuration'') AND (sc.name = ''max_outstanding_io_per_volume'')
								)
								BEGIN
									SET @maxOutstandingIOperVolumeStmt = ''rgc.max_outstanding_io_per_volume'';
								END
								ELSE BEGIN
									SET @maxOutstandingIOperVolumeStmt = ''NULL'';
								END;
							END;

							SET @stmt = ''
								INSERT INTO #inventory(Query, Category, [Key], Value)
								SELECT 23 AS Query, '''''''' AS Category, unpvt.K, unpvt.V
								FROM (
									SELECT
										CAST(rgc.is_enabled AS nvarchar(max)) AS is_enabled
										,CAST('' + @maxOutstandingIOperVolumeStmt + '' AS nvarchar(max)) AS max_outstanding_io_per_volume
										,CAST(QUOTENAME(sch.name) + ''''.'''' + QUOTENAME(o.name) COLLATE DATABASE_DEFAULT AS nvarchar(max)) AS ClassifierFunction
										,sm.definition COLLATE DATABASE_DEFAULT AS ClassifierFunctionDefinition
									FROM master.sys.resource_governor_configuration AS rgc
									LEFT OUTER JOIN master.sys.objects AS o ON (o.object_id = rgc.classifier_function_id)
									LEFT OUTER JOIN master.sys.schemas AS sch ON (sch.schema_id = o.schema_id)
									LEFT OUTER JOIN master.sys.sql_modules AS sm ON (sm.object_id = rgc.classifier_function_id)
								) AS p
								UNPIVOT(
									V FOR K IN (
										p.is_enabled
										,p.max_outstanding_io_per_volume
										,p.ClassifierFunction
										,p.ClassifierFunctionDefinition
									)
								) AS unpvt OPTION (RECOMPILE);
							'';
							EXEC(@stmt);
						END;

						--
						-- Look at Resource Governor resource pool affinity
						--
						IF EXISTS(SELECT * FROM master.sys.system_objects AS so WHERE (so.name = ''resource_governor_resource_pool_affinity''))
						BEGIN
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 24 AS Query, unpvt.PoolName AS Category, unpvt.K, unpvt.V
							FROM (
								SELECT
									CAST(rgrp.name AS nvarchar(max)) AS PoolName
									,CAST(rgrpa.processor_group AS nvarchar(max)) AS processor_group
									,CAST(rgrpa.scheduler_mask AS nvarchar(max)) AS scheduler_mask
								FROM sys.resource_governor_resource_pool_affinity AS rgrpa
								LEFT OUTER JOIN sys.resource_governor_resource_pools AS rgrp ON (rgrp.pool_id = rgrpa.pool_id)
							) AS p
							UNPIVOT(
								V FOR K IN (
									p.processor_group
									,p.scheduler_mask
								)
							) AS unpvt OPTION (RECOMPILE);
						END;

						--
						-- Look at Resource Governor resource pools
						--
						BEGIN
							--
							-- Test if cap_cpu_percent exists on resource_governor_resource_pools
							--
							BEGIN
								DECLARE @capCPUpercentStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''resource_governor_resource_pools'') AND (sc.name = ''cap_cpu_percent'')
								)
								BEGIN
									SET @capCPUpercentStmt = ''rgrp.cap_cpu_percent'';
								END
								ELSE BEGIN
									SET @capCPUpercentStmt = ''NULL'';
								END;
							END;

							--
							-- Test if min_iops_per_volume exists on resource_governor_resource_pools
							--
							BEGIN
								DECLARE @minIOPSperVolumeStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''resource_governor_resource_pools'') AND (sc.name = ''min_iops_per_volume'')
								)
								BEGIN
									SET @minIOPSperVolumeStmt = ''rgrp.min_iops_per_volume'';
								END
								ELSE BEGIN
									SET @minIOPSperVolumeStmt = ''NULL'';
								END;
							END;

							--
							-- Test if max_iops_per_volume exists on resource_governor_resource_pools
							--
							BEGIN
								DECLARE @maxIOPSperVolumeStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''resource_governor_resource_pools'') AND (sc.name = ''max_iops_per_volume'')
								)
								BEGIN
									SET @maxIOPSperVolumeStmt = ''rgrp.max_iops_per_volume'';
								END
								ELSE BEGIN
									SET @maxIOPSperVolumeStmt = ''NULL'';
								END;
							END;

							SET @stmt = ''
								INSERT INTO #inventory(Query, Category, [Key], Value)
								SELECT 25 AS Query, unpvt.PoolName AS Category, unpvt.K, unpvt.V
								FROM (
									SELECT
										rgrp.name AS PoolName
										,CAST(rgrp.min_cpu_percent AS nvarchar(max)) AS min_cpu_percent
										,CAST(rgrp.max_cpu_percent AS nvarchar(max)) AS max_cpu_percent
										,CAST(rgrp.min_memory_percent AS nvarchar(max)) AS min_memory_percent
										,CAST(rgrp.max_memory_percent AS nvarchar(max)) AS max_memory_percent
										,CAST('' + @capCPUpercentStmt + '' AS nvarchar(max)) AS cap_cpu_percent
										,CAST('' + @minIOPSperVolumeStmt + '' AS nvarchar(max)) AS min_iops_per_volume
										,CAST('' + @maxIOPSperVolumeStmt + '' AS nvarchar(max)) AS max_iops_per_volume
									FROM sys.resource_governor_resource_pools AS rgrp
								) AS p
								UNPIVOT(
									V FOR K IN (
										p.min_cpu_percent
										,p.max_cpu_percent
										,p.min_memory_percent
										,p.max_memory_percent
										,p.cap_cpu_percent
										,p.min_iops_per_volume
										,p.max_iops_per_volume
									)
								) AS unpvt OPTION (RECOMPILE);
							'';
							EXEC(@stmt);
						END;

						--
						-- Look at Resource Governor workload groups
						--
						BEGIN
							--
							-- Test if request_max_memory_grant_percent_numeric exists on resource_governor_workload_groups
							--
							BEGIN
								DECLARE @requestMaxMemoryGrantPercentNumericStmt nvarchar(max);

								IF EXISTS(
									SELECT *
									FROM master.sys.system_columns AS sc
									INNER JOIN master.sys.system_objects AS so ON (so.object_id = sc.object_id)
									WHERE (so.name = ''resource_governor_workload_groups'') AND (sc.name = ''request_max_memory_grant_percent_numeric'')
								)
								BEGIN
									SET @requestMaxMemoryGrantPercentNumericStmt = ''rgwg.request_max_memory_grant_percent_numeric'';
								END
								ELSE BEGIN
									SET @requestMaxMemoryGrantPercentNumericStmt = ''NULL'';
								END;
							END;

							SET @stmt = ''
								INSERT INTO #inventory(Query, Category, [Key], Value)
								SELECT 26 AS Query, QUOTENAME(unpvt.PoolName) + ''''.'''' + QUOTENAME(unpvt.WorkloadGroupName) AS Category, unpvt.K, unpvt.V
								FROM (
									SELECT
										CAST(rgrp.name AS nvarchar(max)) AS PoolName
										,CAST(rgwg.name AS nvarchar(max)) AS WorkloadGroupName
										,CAST(rgwg.importance AS nvarchar(max)) COLLATE DATABASE_DEFAULT AS importance
										,CAST(rgwg.request_max_memory_grant_percent AS nvarchar(max)) AS request_max_memory_grant_percent
										,CAST(rgwg.request_max_cpu_time_sec AS nvarchar(max)) AS request_max_cpu_time_sec
										,CAST(rgwg.request_memory_grant_timeout_sec AS nvarchar(max)) AS request_memory_grant_timeout_sec
										,CAST(rgwg.max_dop AS nvarchar(max)) AS max_dop
										,CAST(rgwg.group_max_requests AS nvarchar(max)) AS group_max_requests
										,CAST('' + @requestMaxMemoryGrantPercentNumericStmt + '' AS nvarchar(max)) AS request_max_memory_grant_percent_numeric
									FROM sys.resource_governor_workload_groups AS rgwg
									LEFT OUTER JOIN sys.resource_governor_resource_pools AS rgrp ON (rgrp.pool_id = rgwg.pool_id)
								) AS p
								UNPIVOT(
									V FOR K IN (
										p.importance
										,p.request_max_memory_grant_percent
										,p.request_max_cpu_time_sec
										,p.request_memory_grant_timeout_sec
										,p.max_dop
										,p.group_max_requests
										,p.request_max_memory_grant_percent_numeric
									)
								) AS unpvt OPTION (RECOMPILE);
							'';
							EXEC(@stmt);
						END;

						--
						-- Look at Resource Governor external resource pool affinity
						--
						IF EXISTS(SELECT * FROM master.sys.system_objects AS so WHERE (so.name = ''resource_governor_external_resource_pool_affinity''))
						BEGIN
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 27 AS Query, unpvt.PoolName AS Category, unpvt.K, unpvt.V
							FROM (
								SELECT
									CAST(rgerp.name AS nvarchar(max)) AS PoolName
									,CAST(rgerpa.processor_group AS nvarchar(max)) AS processor_group
									,CAST(rgerpa.cpu_mask AS nvarchar(max)) AS cpu_mask
								FROM sys.resource_governor_external_resource_pool_affinity AS rgerpa
								LEFT OUTER JOIN sys.resource_governor_external_resource_pools AS rgerp ON (rgerp.external_pool_id = rgerpa.external_pool_id)
							) AS p
							UNPIVOT(
								V FOR K IN (
									p.processor_group
									,p.cpu_mask
								)
							) AS unpvt OPTION (RECOMPILE);
						END;

						--
						-- Look at Resource Governor external resource pool affinity
						--
						IF EXISTS(SELECT * FROM master.sys.system_objects AS so WHERE (so.name = ''resource_governor_external_resource_pools''))
						BEGIN
							INSERT INTO #inventory(Query, Category, [Key], Value)
							SELECT 28 AS Query, unpvt.PoolName AS Category, unpvt.K, unpvt.V
							FROM (
								SELECT
									CAST(rgerp.name AS nvarchar(max)) AS PoolName
									,CAST(rgerp.max_cpu_percent AS nvarchar(max)) AS max_cpu_percent
									,CAST(rgerp.max_memory_percent AS nvarchar(max)) AS max_memory_percent
									,CAST(rgerp.max_processes AS nvarchar(max)) AS max_processes
									,CAST(rgerp.version AS nvarchar(max)) AS version
								FROM sys.resource_governor_external_resource_pools AS rgerp
							) AS p
							UNPIVOT(
								V FOR K IN (
									p.max_cpu_percent
									,p.max_memory_percent
									,p.max_processes
									,p.version
								)
							) AS unpvt OPTION (RECOMPILE);
						END;

						--
						-- Remove records where Value is NULL
						--
						BEGIN
							DELETE tgt
							FROM #inventory AS tgt
							WHERE (tgt.Value IS NULL);
						END;

						--
						-- Update current record ValidTo as it is no longer valid
						--
						BEGIN
							UPDATE tgt
							SET tgt.ValidTo = @nowUTC
							FROM dbo.fhsmInstanceState AS tgt
							LEFT OUTER JOIN #inventory AS src ON (src.Query = tgt.Query) AND (src.Category COLLATE DATABASE_DEFAULT = tgt.Category) AND (src.[Key] COLLATE DATABASE_DEFAULT = tgt.[Key])
							WHERE
								(
									(src.Query IS NULL)
									OR ((src.Value COLLATE DATABASE_DEFAULT <> tgt.Value) OR (src.Value IS NULL AND tgt.Value IS NOT NULL) OR (src.Value IS NOT NULL AND tgt.Value IS NULL))
								) AND (tgt.ValidTo = ''9999-dec-31 23:59:59'');
						END;

						--
						-- Insert new records
						--
						BEGIN
							INSERT INTO dbo.fhsmInstanceState(Query, Category, [Key], Value, ValidFrom, ValidTo, TimestampUTC, Timestamp)
							SELECT src.Query, src.Category, src.[Key], src.Value, @nowUTC AS ValidFrom, ''9999-dec-31 23:59:59'' AS ValidTo, @nowUTC, @now
							FROM #inventory AS src
							WHERE NOT EXISTS (
								SELECT *
								FROM dbo.fhsmInstanceState AS tgt
								WHERE
									(tgt.Query = src.Query)
									AND (tgt.Category COLLATE DATABASE_DEFAULT = src.Category)
									AND (tgt.[Key] COLLATE DATABASE_DEFAULT = src.[Key])
									AND ((tgt.Value COLLATE DATABASE_DEFAULT = src.Value) OR (tgt.Value IS NULL AND src.Value IS NULL)) AND (tgt.ValidTo = ''9999-dec-31 23:59:59'')
							);
						END;
					END;

					RETURN 0;
				END;
			';
			EXEC(@stmt);
		END;

		--
		-- Register extended properties on the stored procedure dbo.fhsmSPInstanceState
		--
		BEGIN
			SET @objectName = 'dbo.fhsmSPInstanceState';
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
				,'dbo.fhsmInstanceState'
				,1
				,'TimestampUTC'
				,1
				,1825	-- 5 years
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
				1
				,'Instance State'
				,PARSENAME('dbo.fhsmSPInstanceState', 1)
				,1 * 60 * 60
				,CAST('1900-1-1T00:00:00.0000' AS datetime2(0))
				,CAST('1900-1-1T23:59:59.0000' AS datetime2(0))
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

	--
	-- Update dimensions based upon the fact tables
	--
END;
