SET NOCOUNT ON;

--
-- Print out start message
--
BEGIN
	RAISERROR('', 0, 1) WITH NOWAIT;
	RAISERROR('Cleanup after installation and upgrade', 0, 1) WITH NOWAIT;
END;

--
-- Declare variables
--
BEGIN
	DECLARE @returnValue int;
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
	RAISERROR('Can not execute as it appears the database is not correct installed', 0, 1) WITH NOWAIT;
END
ELSE BEGIN
	--
	-- Drop function dbo.fhsmFNSplitLines
	--
	BEGIN
		IF OBJECT_ID('dbo.fhsmFNSplitLines', 'FN') IS NOT NULL
		BEGIN
			IF EXISTS(
				SELECT *
				FROM sys.dm_sql_referencing_entities('dbo.fhsmFNSplitLines', 'OBJECT') AS dsre
			)
			BEGIN
				RAISERROR('Cannot drop function dbo.fhsmFNSplitLines as it is still in use', 0, 1) WITH NOWAIT;
			END
			ELSE BEGIN
				RAISERROR('Dropping function dbo.fhsmFNSplitLines', 0, 1) WITH NOWAIT;

				EXEC('DROP FUNCTION dbo.fhsmFNSplitLines;');
			END;
		END;
	END;

	--
	-- Drop function dbo.fhsmSplitLines
	--
	BEGIN
		IF OBJECT_ID('dbo.fhsmSplitLines', 'FN') IS NOT NULL
		BEGIN
			IF EXISTS(
				SELECT *
				FROM sys.dm_sql_referencing_entities('dbo.fhsmSplitLines', 'OBJECT') AS dsre
			)
			BEGIN
				RAISERROR('Cannot drop function dbo.fhsmSplitLines as it is still in use', 0, 1) WITH NOWAIT;
			END
			ELSE BEGIN
				RAISERROR('Dropping function dbo.fhsmSplitLines', 0, 1) WITH NOWAIT;

				EXEC('DROP FUNCTION dbo.fhsmSplitLines;');
			END;
		END;
	END;
END;
