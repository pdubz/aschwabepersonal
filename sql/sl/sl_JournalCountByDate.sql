DECLARE @Primary as nvarchar(128)
DECLARE @Machine as nvarchar(128) 
   SET @Machine = CASE WHEN @@SERVERNAME LIKE '%\%'
                  THEN LEFT(@@SERVERNAME,charindex('\',@@SERVERNAME,1)-1)
                  ELSE @@SERVERNAME 
                  END

/*if Availability Group, then check if we are primary node*/
IF SERVERPROPERTY('IsHadrEnabled')= 1
BEGIN
    /*get primary node*/
    SELECT @Primary = hags.primary_replica
      FROM master.sys.dm_hadr_availability_group_states hags
      JOIN master.sys.availability_groups ag
        ON hags.group_id=ag.group_id
END

/*either AG and primary node, or not AG*/ 
IF (@Primary = @Machine) OR (@Primary IS NULL) 
BEGIN
    DECLARE @command nvarchar(max)
    IF OBJECT_ID('tempdb..#JournalCountByDate') IS NOT NULL
    BEGIN
        DROP TABLE #JournalCountByDate
    END
    
    CREATE TABLE #JournalCountByDate ( ServerName NVARCHAR(255)
                                     , DatabaseName NVARCHAR(255)
                                     , site_ref NVARCHAR(8) NULL
                                     , id NVARCHAR(10) NULL
                                     , [count] INT NULL
                                     , [date] DATE NULL )

    SET @command = '
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
    IF OBJECT_ID(''[?].dbo.journal_mst'') IS NOT NULL
    BEGIN
        INSERT INTO #JournalCountByDate ( ServerName
                                        , DatabaseName
                                        , site_ref
                                        , id 
                                        , [count]
                                        , [date] )
        SELECT @LSNR 
             , ''?''
             , site_ref
             , id
             , COUNT(*)
             , CAST(trans_date AS DATE)
          FROM [?].dbo.journal_mst
         GROUP BY site_ref
                , id
                , CAST(trans_date AS DATE)
    END'

    EXEC dba.dbo.usp_foreachdb @command = @command, @suppress_quotename = 1, @name_pattern = '%CS%_App'
    
    SELECT *
      FROM #JournalCountByDate
     ORDER BY site_ref,id,date
    
    IF OBJECT_ID('tempdb..#JournalCountByDate') IS NOT NULL
    BEGIN
        DROP TABLE #JournalCountByDate
    END
END
