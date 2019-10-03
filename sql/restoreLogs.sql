declare @backupType char(1) = 'L'
, @dbname sysname = 'eSiteRAMPAC_PRM'
, @logLocation varchar(10) = 'E:\backups01\log'
, @restoreDB sysname = 'eSiteRAMPAC_PRM'
, @beginDate datetime = '12/18/2015 08:15:00'
, @endDate datetime = '12/18/2015 08:30:00'

select  'restore log [' + @restoreDB + '] from disk = ''' + replace(bf.physical_device_name, 'E:\Backups01\Log\', @logLocation ) + ''' with file=1, norecovery, stats=5'

  from master.sys.databases d
  join msdb.dbo.backupset bs
    on bs.type = @backupType
   and d.name = bs.database_name
  join msdb.dbo.backupmediafamily bf 
    on bf.media_set_id = bs.media_set_id
 where d.name = @dbname 
   and bs.backup_start_date between @begindate and @enddate
   and bf.physical_device_name like 'E:\%'
 order by bs.backup_start_date 
