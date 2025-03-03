UPDATE ip
SET
	ip.TimestampUTCDate = CAST(ip.TimestampUTC AS date)
	,ip.TimestampDate = CAST(ip.Timestamp AS date)
	,ip.TimeKey = (DATEPART(HOUR, ip.Timestamp) * 60 * 60) + (DATEPART(MINUTE, ip.Timestamp) * 60) + (DATEPART(SECOND, ip.Timestamp))
	,ip.DatabaseKey =       (SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ip.DatabaseName, DEFAULT,        DEFAULT,       DEFAULT,      DEFAULT,          DEFAULT             ) AS k)
	,ip.SchemaKey =         (SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ip.DatabaseName, ip.SchemaName,  DEFAULT,       DEFAULT,      DEFAULT,          DEFAULT             ) AS k)
	,ip.ObjectKey =         (SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ip.DatabaseName, ip.SchemaName,  ip.ObjectName, DEFAULT,      DEFAULT,          DEFAULT             ) AS k)
	,ip.IndexKey =          (SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ip.DatabaseName, ip.SchemaName,  ip.ObjectName, ip.IndexName, DEFAULT,          DEFAULT             ) AS k)
	,ip.IndexTypeKey =      (SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ip.DatabaseName, ip.SchemaName,  ip.ObjectName, ip.IndexName, ip.IndexTypeDesc, DEFAULT             ) AS k)
	,ip.IndexAllocTypeKey = (SELECT k.[Key] FROM dbo.fhsmFNGenerateKey(ip.DatabaseName, ip.SchemaName,  ip.ObjectName, ip.IndexName, ip.IndexTypeDesc, ip.AllocUnitTypeDesc) AS k)
FROM dbo.fhsmIndexPhysical AS ip
WHERE (ip.TimestampUTCDate IS NULL);
GO
