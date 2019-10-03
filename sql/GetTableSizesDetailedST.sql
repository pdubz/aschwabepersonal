USE [dbname]

SET STATISTICS TIME,IO ON
DECLARE @PageSize FLOAT
SELECT @PageSize = v.low / 1024.0
  FROM master.dbo.spt_values v
 WHERE v.number = 1
   AND v.type = 'E'

SELECT @@SERVERNAME AS ServerName
     , DB_NAME() AS [DatabaseName]
     , OBJECT_SCHEMA_NAME(i.object_id) AS [SchemaName]
     , OBJECT_NAME(i.object_id) AS [TableName]
     , p.rows AS [NumberOfRows]
     , @PageSize * SUM(total_pages) AS [ReservedSpaceKB]
     , @PageSize * SUM(CASE WHEN a.type <> 1 THEN a.used_pages WHEN p.index_id < 2 THEN a.data_pages ELSE 0 END) AS [DataSpaceKB]
     , @PageSize * SUM(a.used_pages - CASE WHEN a.type <> 1 THEN a.used_pages WHEN p.index_id < 2 THEN a.data_pages ELSE 0 END) AS [IndexSpaceKB]
     , @PageSize * SUM(total_pages - used_pages) AS [UnusedSpaceKB]
  FROM sys.indexes AS i
 INNER JOIN sys.partitions AS p 
    ON p.object_id = i.object_id
   AND p.index_id = i.index_id
 INNER JOIN sys.allocation_units AS a 
    ON a.container_id = p.partition_id
 INNER JOIN sys.tables t 
    ON i.object_id = t.object_id
 WHERE i.type <= 1
   AND a.type = 1
   AND t.type = 'U'
   AND is_ms_shipped = 0
 GROUP BY i.object_id
     , p.rows
