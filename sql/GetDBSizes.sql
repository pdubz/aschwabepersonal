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

    DECLARE @DBSizeQuery nvarchar(max)
    
    IF OBJECT_ID('tempdb..#DBSizeInfo') IS NOT NULL
    	BEGIN
    		DROP TABLE #DBSizeInfo
    	END
    
    CREATE TABLE #DBSizeInfo ( ServerName nvarchar(400)
                             , DatabaseName nvarchar(400)
                             , DBSizeMB float
                             , DBSizeGB float
                             ) ;
    
    SET @DBSizeQuery = '
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
    IF OBJECT_ID(''[?].sys.database_files'') IS NOT NULL
    BEGIN
        INSERT INTO #DBSizeInfo
        SELECT @LSNR AS ServerName
             , ''?'' AS DatabaseName
             , (SUM((size*8.00)))/1024.00 AS DBSizeMB
             , ((SUM((size*8.00)))/1024.00)/1024.00 AS DBSizeGB
          FROM [?].sys.database_files
    END
    '
    
      EXEC dba.dbo.usp_foreachdb @command = @DBSizeQuery
                               , @suppress_quotename = 1

    SELECT *
      FROM #DBSizeInfo
      ORDER BY DBSizeGB DESC
	  --WHERE DatabaseName NOT IN ('master','model','msdb','tempdb','dba','util')
	  --ORDER BY DatabaseName ASC
    
    IF OBJECT_ID('tempdb..#DBSizeInfo') IS NOT NULL
    	BEGIN
    		DROP TABLE #DBSizeInfo
    	END
END
