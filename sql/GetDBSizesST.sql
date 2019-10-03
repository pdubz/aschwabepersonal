IF OBJECT_ID('tempdb..#DBSizeInfo') IS NOT NULL
    BEGIN
        DROP TABLE #DBSizeInfo
    END

CREATE TABLE #DBSizeInfo ( ServerName nvarchar(400)
                        , DatabaseName nvarchar(400)
                        , DBSizeMB float
                        , DBSizeGB float
                        ) ;


INSERT INTO #DBSizeInfo
SELECT @@ServerName AS ServerName
    , 'LSLMDB' AS DatabaseName
    , (SUM((size*8.00)))/1024.00 AS DBSizeMB
    , ((SUM((size*8.00)))/1024.00)/1024.00 AS DBSizeGB
FROM LSLMDB.sys.database_files

SELECT *
FROM #DBSizeInfo
ORDER BY DBSizeGB DESC
--WHERE DatabaseName NOT IN ('master','model','msdb','tempdb','dba','util')
--ORDER BY DatabaseName ASC
    
IF OBJECT_ID('tempdb..#DBSizeInfo') IS NOT NULL
    BEGIN
        DROP TABLE #DBSizeInfo
    END
