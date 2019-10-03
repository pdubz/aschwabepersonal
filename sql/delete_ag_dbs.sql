SELECT name 
     , 'EXEC util.dbo.usp_backup_db @comment = ''final'', @bu_type = ''full'', @dbname = ''' + name + '''' AS BKUP
     , 'ALTER AVAILABILITY GROUP AG1 REMOVE DATABASE [' + name + ']' AS DropFromAG
     , 'RESTORE DATABASE [' + name + '] WITH RECOVERY' AS Recover
     , 'ALTER DATABASE [' + name + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE' AS SingleUser
     , 'DROP DATABASE [' + name + ']' AS [Drop]
  FROM master.sys.databases
 WHERE name LIKE 'CSITEST01_%_CSI_%'
    OR name LIKE 'CSIDEMOOPS_TRN_CSI_%'
    OR name LIKE 'CSIDEMOOPS_AX1_CSI_%'
