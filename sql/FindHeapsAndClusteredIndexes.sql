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

    DECLARE @HeapCheckQuery nvarchar(max)
    
    IF OBJECT_ID('tempdb..#HeapCheck') IS NOT NULL
    	BEGIN
    		DROP TABLE #HeapCheck
    	END
    
    CREATE TABLE #HeapCheck ( ID INT IDENTITY(1,1)
                            , DatabaseName NVARCHAR(255)
                            , NumHeaps INT
                            , NumClustered INT
                            , SumHeapsAndClustered AS NumHeaps + NumClustered 
                            , TotalTables INT
                            ) ;
    
       SET @HeapCheckQuery = '
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
    IF OBJECT_ID(''[?].sys.tables'') IS NOT NULL
    BEGIN
       DECLARE @CurrentID INT
       
       INSERT INTO #HeapCheck ( DatabaseName ) 
       VALUES ( ''?'' )
       
       SELECT @CurrentID = ID
         FROM #HeapCheck
        WHERE DatabaseName = ''?''
       
       UPDATE #HeapCheck
          SET NumHeaps = ( SELECT COUNT(*) 
                             FROM [?].sys.tables AS t 
                            INNER JOIN [?].sys.schemas AS s 
                               ON t.schema_id = s.schema_id 
                            INNER JOIN [?].sys.indexes i
                               ON t.object_id = i.object_id 
                            WHERE i.type = 0
                              AND t.is_ms_shipped = 0 )
        WHERE ID = @CurrentID
       
       UPDATE #HeapCheck
          SET NumClustered = ( SELECT COUNT(*) 
                                 FROM [?].sys.tables AS t 
                                INNER JOIN [?].sys.schemas AS s 
                                   ON t.schema_id = s.schema_id 
                                INNER JOIN [?].sys.indexes i
                                   ON t.object_id = i.object_id 
                                WHERE i.type = 1
                                  AND t.is_ms_shipped = 0 )
        WHERE ID = @CurrentID
       
       UPDATE #HeapCheck
          SET TotalTables = ( SELECT COUNT(*) 
                                 FROM [?].sys.tables
                                WHERE is_ms_shipped = 0 )
        WHERE ID = @CurrentID
    END
    '
    
      EXEC dba.dbo.usp_foreachdb @command = @HeapCheckQuery
                               , @suppress_quotename = 1
                               , @user_only = 1
    SELECT *
      FROM #HeapCheck
     ORDER BY DatabaseName
    
    IF OBJECT_ID('tempdb..#HeapCheck') IS NOT NULL
    	BEGIN
    		DROP TABLE #HeapCheck
    	END
END
