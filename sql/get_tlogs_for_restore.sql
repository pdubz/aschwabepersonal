declare @backupType char(1) = 'L'
, @dbname sysname = 'Pod_Main'
, @logLocation varchar(10) = 'D:\'
, @restoreDB sysname = 'Pod_Main_Restore'
, @beginDate datetime = '3/13/2015 2:00:00'
, @endDate datetime = '3/13/2015 5:07:00'

select  'restore log [' + @restoreDB + '] from disk = ''' + replace(bf.physical_device_name, 'E:\Backups01\Log\', @logLocation ) + ''' with file=1, norecovery, nounload, stats=5'

  from sys.databases d
  join msdb.dbo.backupset bs
    on bs.type = @backupType
   and d.name = bs.database_name
  join msdb.dbo.backupmediafamily bf 
    on bf.media_set_id = bs.media_set_id
 where d.name = @dbname 
   and bs.backup_start_date between @begindate and @enddate
   and bf.physical_device_name like 'E:\%'
 order by bs.backup_start_date 