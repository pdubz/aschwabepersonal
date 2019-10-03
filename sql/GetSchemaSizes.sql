DECLARE @Primary as nvarchar(128)
DECLARE @Machine as nvarchar(128) 
   SET @Machine = CASE WHEN @@SERVERNAME LIKE '%\%'
                  THEN LEFT(@@SERVERNAME,charindex('\',@@SERVERNAME,1)-1)
                  ELSE @@SERVERNAME 
                  END
 
/*if AlwaysOn, then check if we are primary node*/
IF SERVERPROPERTY('IsHadrEnabled')= 1
BEGIN
    /*get primary node*/
    SELECT @Primary = hags.primary_replica
      FROM master.sys.dm_hadr_availability_group_states hags
      JOIN master.sys.availability_groups ag
        ON hags.group_id=ag.group_id
END

/*either AAG and primary node, or not AAG*/ 
IF (@Primary = @Machine) OR (@Primary IS NULL) -- 
BEGIN

    DECLARE @SchemaSizeQuery nvarchar(max)
    
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
    
    SET @SchemaSizeQuery = '
    DECLARE @LSNR as nvarchar(128);
    IF SERVERPROPERTY(''IsHadrEnabled'')= 1
    BEGIN
        SELECT @LSNR = dns_name
          FROM master.sys.availability_group_listeners
    END
    ELSE
    BEGIN
        SELECT @LSNR = @@SERVERNAME
    END
    IF OBJECT_ID(''[?].sys.dm_db_partition_stats'') IS NOT NULL
    BEGIN
	    USE [?]
        INSERT INTO #SchemaSizeInfo
		SELECT @LSNR AS ServerName
             , ''?'' AS DatabaseName
		     , SCHEMA_NAME(so.schema_id) AS SchemaName
	         , (SUM(ps.reserved_page_count)*8.0)/1024 AS SchemaSizeMB
	         , ((SUM(ps.reserved_page_count)*8.0)/1024)/1024.00 AS SchemaSizeGB
          FROM [?].sys.dm_db_partition_stats ps
         INNER JOIN [?].sys.indexes i ON i.object_id = ps.object_id
           AND i.index_id = ps.index_id
         INNER JOIN [?].sys.objects so ON i.object_id = so.object_id
         WHERE so.type = ''U''
         GROUP BY so.schema_id
    END
    '
    
      EXEC dba.dbo.usp_foreachdb @command = @SchemaSizeQuery
                               , @suppress_quotename = 1

    SELECT *
      FROM #SchemaSizeInfo
      ORDER BY SchemaSizeGB DESC
	  --WHERE DatabaseName NOT IN ('master','model','msdb','tempdb','dba','util')
	  --ORDER BY DatabaseName ASC
    
    IF OBJECT_ID('tempdb..#SchemaSizeInfo') IS NOT NULL
    	BEGIN
    		DROP TABLE #SchemaSizeInfo
    	END
END
