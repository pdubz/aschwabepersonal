SELECT NAME
     , 'EXEC util.dbo.usp_backup_db @dbname = '''
	 + name 
	 + ''', @bu_type = ''full'', @comment = ''final''' 
	 + CHAR(13)
	 + CHAR(10)
	 + 'ALTER DATABASE ['
     + name 
     + '] SET OFFLINE WITH ROLLBACK IMMEDIATE' AS [Command(s) to Backup and Offline]
  FROM master.sys.databases
 WHERE name NOT LIKE '%brand%'
   AND name NOT LIKE '%syteline%'
   AND name NOT IN ( 'master'
                   , 'msdb'
                   , 'model'
                   , 'tempdb'
                   , 'dba'
                   , 'util'
                   ) ;
