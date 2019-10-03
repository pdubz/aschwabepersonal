--Check login for user 'dbo' on each database
--Make sure the login name is the correct sql*_svc
--Will return db's that are incorrect
DECLARE @Domain sysname, @UserAcct sysname
SELECT @Domain = DEFAULT_DOMAIN()
   SET @UserAcct = @Domain + N'\sql' + @Domain+ '_svc' 

CREATE TABLE #IncorrectLogins ( RowID int IDENTITY(1,1)
                               , UserName sysname
                               , RoleName sysname
                               , LoginName sysname NULL
                               , DefDBName sysname NULL
                               , DefSchemaName sysname
                               , UserID	int
                               , [SID] varbinary(85)
                               ) ;

  EXEC master.sys.sp_MSforeachdb '
	INSERT INTO #IncorrectLogins
		EXEC [?].dbo.sp_helpuser ''dbo''
	UPDATE #IncorrectLogins
	SET DefDBName = ''?''
	Where RowID = IDENT_CURRENT(''#IncorrectLogins'')
'
SELECT UserName
     , LoginName
     , DefDBName
     , 'USE [' 
     + DefDBName 
     + ']; EXEC sys.sp_changedbowner ''' 
     + @UserAcct 
     + '''' AS [Command(s) to Change 'dbo' User]
  FROM #IncorrectLogins 
 WHERE DefDBName not in ( 'master'
                        , 'model'
                        , 'msdb'
                        , 'tempdb'
                        , 'dba'
                        , 'util' ) 
   AND LoginName <> @UserAcct

DROP TABLE #IncorrectLogins
