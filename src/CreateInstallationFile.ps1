$outputFile = "..\build\FHSQLMonitor.sql"

if (Test-Path $outputFile) {
    Clear-Content $outputFile
}

Add-Content $outputFile "USE master;"
Add-Content $outputFile ""
Add-Content $outputFile "--"
Add-Content $outputFile "-- FHSQLMonitor v2.0"
Add-Content $outputFile "--"
Add-Content $outputFile ""
Add-Content $outputFile "--"
Add-Content $outputFile "-- Installation parameters - They are used both during a fresh installation and during an update"
Add-Content $outputFile "--"
Add-Content $outputFile "DECLARE @createSQLAgentJob    bit           = 1;"
Add-Content $outputFile "DECLARE @fhSQLMonitorDatabase nvarchar(128) = 'FHSQLMonitor';"
Add-Content $outputFile "DECLARE @pbiSchema            nvarchar(128) = 'FHSM';"
Add-Content $outputFile "DECLARE @olaDatabase          nvarchar(128) = NULL;"
Add-Content $outputFile "DECLARE @olaSchema            nvarchar(128) = NULL;"
Add-Content $outputFile ""
Add-Content $outputFile "-- Service parameters - They are only used during a fresh installation and not during an update"
Add-Content $outputFile "--   When updating the already configured values in the tables dbo.fhsmSchedules and dbo.fhsmRetentions remains unchanged"
Add-Content $outputFile "--"
Add-Content $outputFile "DECLARE @enableAgentJobs                bit = 1;"
Add-Content $outputFile "DECLARE @enableAgeOfStatistics          bit = 1;"
Add-Content $outputFile "DECLARE @enableBackupStatus             bit = 1;"
Add-Content $outputFile "DECLARE @enableConnections              bit = 1;"
Add-Content $outputFile "DECLARE @enableCPUUtilization           bit = 1;"
Add-Content $outputFile "DECLARE @enableDatabaseIO               bit = 1;"
Add-Content $outputFile "DECLARE @enableDatabaseSize             bit = 1;"
Add-Content $outputFile "DECLARE @enableDatabaseState            bit = 1;"
Add-Content $outputFile "DECLARE @enableIndexOperational         bit = 1;"
Add-Content $outputFile "DECLARE @enableIndexPhysical            bit = 1;"
Add-Content $outputFile "DECLARE @enableIndexUsage               bit = 1;"
Add-Content $outputFile "DECLARE @enableInstanceState            bit = 1;"
Add-Content $outputFile "DECLARE @enableMissingIndexes           bit = 1;"
Add-Content $outputFile "DECLARE @enablePerformanceStatistics    bit = 1;"
Add-Content $outputFile "DECLARE @enablePlanCacheUsage           bit = 1;"
Add-Content $outputFile "DECLARE @enablePlanGuides               bit = 1;"
Add-Content $outputFile "DECLARE @enableQueryStatistics          bit = 1;"
Add-Content $outputFile "DECLARE @enableTableSize                bit = 1;"
Add-Content $outputFile "DECLARE @enableTriggers                 bit = 1;"
Add-Content $outputFile "DECLARE @enableWaitStatistics           bit = 1;"
Add-Content $outputFile "DECLARE @enableWhoIsActive              bit = 1;"
Add-Content $outputFile "DECLARE @enableIndexRebuild             bit = 0;"
Add-Content $outputFile "DECLARE @enableIndexReorganize          bit = 0;"
Add-Content $outputFile "DECLARE @enableUpdateAllStatistics      bit = 0;"
Add-Content $outputFile "DECLARE @enableUpdateModifiedStatistics bit = 0;"
Add-Content $outputFile ""
Add-Content $outputFile "--"
Add-Content $outputFile "-- No need to change more from here on"
Add-Content $outputFile "--"
Add-Content $outputFile ""
Add-Content $outputFile "DECLARE @stmt nvarchar(max);"

$filenames = Get-Content InstallationFileNames.txt
foreach ($file in $filenames) {
    echo $file

    $content = Get-Content $file -Raw
    $content = $content.Replace('''', '''''')

    Add-Content $outputFile -Value "--"
    Add-Content $outputFile -Value ("-- File part:" + $file)
    Add-Content $outputFile -Value "--"

    Add-Content $outputFile -Value "SET @stmt = '"

    if ($file -ne "_Install-FHSQLMonitor.sql") {
        Add-Content $outputFile -Value "USE [' + @fhSQLMonitorDatabase + '];"
    }

    Add-Content $outputFile $content
    Add-Content $outputFile -Value "';"

    if ($file -eq "_Install-FHSQLMonitor.sql") {
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @createSQLAgentJob = 1;',                   'SET @createSQLAgentJob = ' + CAST(@createSQLAgentJob AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @fhSQLMonitorDatabase = ''FHSQLMonitor'';', 'SET @fhSQLMonitorDatabase = ''' + @fhSQLMonitorDatabase + ''';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @pbiSchema = ''FHSM'';',                    'SET @pbiSchema = ''' + @pbiSchema + ''';');"
    } else {
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @olaDatabase = NULL;', 'SET @olaDatabase = ' + COALESCE('''' + CAST(@olaDatabase AS nvarchar) + '''', 'NULL') + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @olaSchema = NULL;',   'SET @olaSchema = '   + COALESCE('''' + CAST(@olaSchema AS nvarchar)   + '''', 'NULL') + ';');"
        Add-Content $outputFile ""
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableAgentJobs = 0;',                'SET @enableAgentJobs = '                + CAST(@enableAgentJobs AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableAgeOfStatistics = 0;',          'SET @enableAgeOfStatistics = '          + CAST(@enableAgeOfStatistics AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableBackupStatus = 0;',             'SET @enableBackupStatus = '             + CAST(@enableBackupStatus AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableConnections = 0;',              'SET @enableConnections = '              + CAST(@enableConnections AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableCPUUtilization = 0;',           'SET @enableCPUUtilization = '           + CAST(@enableCPUUtilization AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableDatabaseIO = 0;',               'SET @enableDatabaseIO = '               + CAST(@enableDatabaseIO AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableDatabaseSize = 0;',             'SET @enableDatabaseSize = '             + CAST(@enableDatabaseSize AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableDatabaseState = 0;',            'SET @enableDatabaseState = '            + CAST(@enableDatabaseState AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableIndexOperational = 0;',         'SET @enableIndexOperational = '         + CAST(@enableIndexOperational AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableIndexPhysical = 0;',            'SET @enableIndexPhysical = '            + CAST(@enableIndexPhysical AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableIndexUsage = 0;',               'SET @enableIndexUsage = '               + CAST(@enableIndexUsage AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableInstanceState = 0;',            'SET @enableInstanceState = '            + CAST(@enableInstanceState AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableMissingIndexes = 0;',           'SET @enableMissingIndexes = '           + CAST(@enableMissingIndexes AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enablePerformanceStatistics = 0;',    'SET @enablePerformanceStatistics = '    + CAST(@enablePerformanceStatistics AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enablePlanCacheUsage = 0;',           'SET @enablePlanCacheUsage = '           + CAST(@enablePlanCacheUsage AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enablePlanGuides = 0;',               'SET @enablePlanGuides = '               + CAST(@enablePlanGuides AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableQueryStatistics = 0;',          'SET @enableQueryStatistics = '          + CAST(@enableQueryStatistics AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableTableSize = 0;',                'SET @enableTableSize = '                + CAST(@enableTableSize AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableTriggers = 0;',                 'SET @enableTriggers = '                 + CAST(@enableTriggers AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableWaitStatistics = 0;',           'SET @enableWaitStatistics = '           + CAST(@enableWaitStatistics AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableWhoIsActive = 0;',              'SET @enableWhoIsActive = '              + CAST(@enableWhoIsActive AS nvarchar) + ';');"

        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableIndexRebuild = 0;',             'SET @enableIndexRebuild = '             + CAST(@enableIndexRebuild AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableIndexReorganize = 0;',          'SET @enableIndexReorganize = '          + CAST(@enableIndexReorganize AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableUpdateAllStatistics = 0;',      'SET @enableUpdateAllStatistics = '      + CAST(@enableUpdateAllStatistics AS nvarchar) + ';');"
        Add-Content $outputFile "SET @stmt = REPLACE(@stmt, 'SET @enableUpdateModifiedStatistics = 0;', 'SET @enableUpdateModifiedStatistics = ' + CAST(@enableUpdateModifiedStatistics AS nvarchar) + ';');"
    }

    Add-Content $outputFile -Value "EXEC(@stmt);"
}
