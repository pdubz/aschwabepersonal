DECLARE @FileNameTbl TABLE 
      ( [DatabaseName] sysname
      , [LogicalFileName] varchar(128)
      , [PhysicalFileName] varchar(128)
      , [AlterPhysicalNameCommands] nvarchar(2048)
      )
      
 insert into @FileNameTbl
 exec ( 'SELECT DB_NAME(database_id)
              , name
              , physical_name
              , case type
                     when 0
                          then
                               case 
                                    when physical_name <> ''E:\data01\data\'' + DB_NAME(database_id) + ''_data.mdf''
                                         then 
''ALTER DATABASE ['' + db_name(database_id) + ''] SET OFFLINE
GO
ALTER DATABASE ['' + db_name(database_id) + ''] MODIFY FILE (NAME = '' + name + '', FILENAME = ''''E:\data01\data\'' + db_name(database_id) + ''_data.mdf'''')
GO
EXEC master..xp_cmdshell ''''ren '' + physical_name + '' '' + db_name(database_id) + ''_data.mdf''''
ALTER DATABASE ['' + db_name(database_id) + ''] SET ONLINE
GO'' + CHAR(10)
                                          end
                     when 1
                          then
                               case 
                                    when physical_name <> ''E:\logs01\data\'' + DB_NAME(database_id) + ''_log.ldf''
                                         then 
''ALTER DATABASE ['' + db_name(database_id) + ''] SET OFFLINE
GO
ALTER DATABASE ['' + db_name(database_id) + ''] MODIFY FILE (NAME = '' + name + '' , FILENAME = ''''E:\logs01\data\'' + db_name(database_id) + ''_log.ldf'''')
GO
EXEC master..xp_cmdshell ''''ren '' + physical_name + '' '' + db_name(database_id) + ''_log.ldf''''
ALTER DATABASE ['' + db_name(database_id) + ''] SET ONLINE
GO'' + CHAR(10)
                                          end
                end
           FROM master.sys.master_files AS msmf
      ' )
    
 select DatabaseName
      , LogicalFileName
      , PhysicalFileName
      , AlterPhysicalNameCommands
   from @FileNameTbl
  where AlterPhysicalNameCommands <> 'NULL' 
    and DatabaseName not in ( 'tempdb'
                            , 'master'
                            , 'model'
                            , 'msdb' )