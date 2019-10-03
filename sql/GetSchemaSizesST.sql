IF OBJECT_ID('tempdb..#SchemaSizeInfo') IS NOT NULL
    BEGIN
        DROP TABLE #SchemaSizeInfo
    END

CREATE TABLE #SchemaSizeInfo ( ServerName nvarchar(400)
                            , DatabaseName nvarchar(400)
                            , SchemaName nvarchar(400)
                            , SchemaSizeMB float
                            , SchemaSizeGB float
                            ) ;

INSERT INTO #SchemaSizeInfo
SELECT @@SERVERNAME AS ServerName
    , LSLMDB AS DatabaseName
    , SCHEMA_NAME(so.schema_id) AS SchemaName
    , (SUM(ps.reserved_page_count)*8.0)/1024 AS SchemaSizeMB
    , ((SUM(ps.reserved_page_count)*8.0)/1024)/1024.00 AS SchemaSizeGB
FROM LSLMDB.sys.dm_db_partition_stats ps
INNER JOIN LSLMDB.sys.indexes i ON i.object_id = ps.object_id
AND i.index_id = ps.index_id
INNER JOIN LSLMDB.sys.objects so ON i.object_id = so.object_id
WHERE so.type = 'U'
GROUP BY so.schema_id


SELECT *
FROM #SchemaSizeInfo
ORDER BY SchemaSizeGB DESC
--WHERE DatabaseName NOT IN ('master','model','msdb','tempdb','dba','util')
--ORDER BY DatabaseName ASC

IF OBJECT_ID('tempdb..#SchemaSizeInfo') IS NOT NULL
    BEGIN
        DROP TABLE #SchemaSizeInfo
    END
