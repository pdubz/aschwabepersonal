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

    DECLARE @BadDataTypeQuery nvarchar(max)
    
    IF OBJECT_ID('tempdb..#BadDataTypeInfo') IS NOT NULL
    	BEGIN
    		DROP TABLE #BadDataTypeInfo
    	END
    
    CREATE TABLE #BadDataTypeInfo ( ServerName nvarchar(400)
                                  , DatabaseName nvarchar(400)
                                  , TABLE_NAME nvarchar(400)
                                  , COLUMN_NAME datetime
                                  , DATA_TYPE datetime
                                  ) ;
    
    SET @BadDataTypeQuery = '
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
        INSERT INTO #BadDataTypeInfo
        SELECT @LSNR AS ServerName
             , ''?'' AS DatabaseName 
             , TABLE_SCHEMA + ''.'' + TABLE_NAME AS TABLE_NAME
             , COLUMN_NAME
             , DATA_TYPE
          FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE DATA_TYPE IN ( ''TEXT''
                            , ''NTEXT''
                            , ''IMAGE'' )
    END
    '
    
      EXEC dba.dbo.usp_foreachdb @command = @BadDataTypeQuery
                               , @suppress_quotename = 1

    SELECT *
      FROM #BadDataTypeInfo
     order by 5 desc
    
    IF OBJECT_ID('tempdb..#BadDataTypeInfo') IS NOT NULL
    	BEGIN
    		DROP TABLE #BadDataTypeInfo
    	END
END
