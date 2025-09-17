SET NOCOUNT ON;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Installing IndexOptimize-001', 0, 1) WITH NOWAIT;
END;

--
-- Declare variables
--
BEGIN
	DECLARE @edition nvarchar(128);
	DECLARE @productEndPos int;
	DECLARE @productStartPos int;
	DECLARE @productVersion nvarchar(128);
	DECLARE @productVersion1 int;
	DECLARE @productVersion2 int;
	DECLARE @productVersion3 int;
	DECLARE @returnValue int;
	DECLARE @stmt nvarchar(max);
	DECLARE @tableCompressionStmt nvarchar(max);
END;

--
-- Check if SQL version allows to use data compression
--
BEGIN
	SET @tableCompressionStmt = '';

	SET @edition = CAST(SERVERPROPERTY('Edition') AS nvarchar);

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

	IF (@edition = 'SQL Azure')
		OR (SUBSTRING(@edition, 1, CHARINDEX(' ', @edition)) = 'Developer')
		OR (SUBSTRING(@edition, 1, CHARINDEX(' ', @edition)) = 'Enterprise')
		OR (@productVersion1 > 13)
		OR ((@productVersion1 = 13) AND (@productVersion2 >= 1))
		OR ((@productVersion1 = 13) AND (@productVersion2 = 0) AND (@productVersion3 >= 4001))
	BEGIN
		SET @tableCompressionStmt = ', DATA_COMPRESSION = PAGE';
	END;
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
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CommandLog]') AND type in (N'U'))
BEGIN
SET @stmt = '
CREATE TABLE [dbo].[CommandLog](
  [ID] [int] IDENTITY(1,1) NOT NULL,
  [DatabaseName] [sysname] NULL,
  [SchemaName] [sysname] NULL,
  [ObjectName] [sysname] NULL,
  [ObjectType] [char](2) NULL,
  [IndexName] [sysname] NULL,
  [IndexType] [tinyint] NULL,
  [StatisticsName] [sysname] NULL,
  [PartitionNumber] [int] NULL,
  [ExtendedInfo] [xml] NULL,
  [Command] [nvarchar](max) NOT NULL,
  [CommandType] [nvarchar](60) NOT NULL,
  [StartTime] [datetime2](7) NOT NULL,
  [EndTime] [datetime2](7) NULL,
  [ErrorNumber] [int] NULL,
  [ErrorMessage] [nvarchar](max) NULL,
 CONSTRAINT [PK_CommandLog] PRIMARY KEY CLUSTERED
(
  [ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON' + @tableCompressionStmt + ')
)
';
EXEC(@stmt);
END
END;
