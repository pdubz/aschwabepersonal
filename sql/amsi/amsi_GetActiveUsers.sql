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

    DECLARE @UserCountQuery nvarchar(max)
    
    IF OBJECT_ID('tempdb..#UserCountInfo') IS NOT NULL
    	BEGIN
    		DROP TABLE #UserCountInfo
    	END
    
    CREATE TABLE #UserCountInfo ( ServerName nvarchar(400)
                                , DatabaseName nvarchar(400)
                                , ActiveUsers int
                                ) ;
    
    SET @UserCountQuery = '
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
    IF OBJECT_ID(''[?].dbo.aspnet_Users'') IS NOT NULL
    BEGIN
        INSERT INTO #UserCountInfo
        SELECT @LSNR AS ServerName
             , ''?'' AS DatabaseName
             , COUNT(*) AS ActiveUsers
          FROM [?].dbo.aspnet_Users
         WHERE LastActivityDate > ''2016-01-01 00:00:00.001''
    END
    '
    
      EXEC dba.dbo.usp_foreachdb @command = @UserCountQuery
                               , @suppress_quotename = 1
                               , @name_pattern = 'AMSIWebConfig%'

    SELECT *
      FROM #UserCountInfo
    
    IF OBJECT_ID('tempdb..#UserCountInfo') IS NOT NULL
    	BEGIN
    		DROP TABLE #UserCountInfo
    	END
END
