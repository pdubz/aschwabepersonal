DECLARE @FileNameTbl TABLE 
      ( [DatabaseName] sysname
      , [LogicalFileName] varchar(128)
      , [PhysicalFileName] varchar(128)
      , [AlterLogicalNameCommands] nvarchar(2048)
      )
      
 insert into @FileNameTbl
 exec ( 'SELECT DB_NAME(database_id)
              , name
              , physical_name
              , case type
                     when 0
                          then
                               case 
                                    when name <> DB_NAME(database_id)
                                         then 
                                              ''ALTER DATABASE ['' + DB_NAME(database_id) + ''] MODIFY FILE (NAME = ['' + name + ''], NEWNAME = ['' + DB_NAME(database_id) + ''])''
                                          end
                     when 1
                          then
                               case 
                                    when name <> DB_NAME(database_id) + ''_log''
                                         then 

                                              ''ALTER DATABASE ['' + DB_NAME(database_id) + ''] MODIFY FILE (NAME = ['' + name + ''], NEWNAME = ['' + DB_NAME(database_id) + ''_log])''
                                          end
                end
           FROM master.sys.master_files AS msmf
      ' )
    
 select DatabaseName
      , LogicalFileName
      , PhysicalFileName
      , AlterLogicalNameCommands
   from @FileNameTbl
  where AlterLogicalNameCommands <> 'NULL' 
    and DatabaseName not in ( 'tempdb'
                            , 'master'
                            , 'model'
                            , 'msdb' )
