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

    DECLARE @SiteCountQuery nvarchar(max)
    
    IF OBJECT_ID('tempdb..#SiteCountInfo') IS NOT NULL
    	BEGIN
    		DROP TABLE #SiteCountInfo
    	END
    
    CREATE TABLE #SiteCountInfo ( ServerName nvarchar(400)
                                , DatabaseName nvarchar(400)
                                , Sites int
                                ) ;
    
    SET @SiteCountQuery = '
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
    IF OBJECT_ID(''[?].dbo.UserNames'') IS NOT NULL
    BEGIN
        INSERT INTO #SiteCountInfo
        SELECT @LSNR AS ServerName
             , ''?'' AS DatabaseName
             , COUNT(*) AS Sites
          FROM [?].dbo.site
    END
    '
    
      EXEC dba.dbo.usp_foreachdb @command = @SiteCountQuery
                               , @suppress_quotename = 1
                               , @name_pattern = '%PRD%_App'

    SELECT *
      FROM #SiteCountInfo
    
    IF OBJECT_ID('tempdb..#SiteCountInfo') IS NOT NULL
    	BEGIN
    		DROP TABLE #SiteCountInfo
    	END
END
