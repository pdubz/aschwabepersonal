declare @bkupLOC as nvarchar(100) = '\\vpc144share01\sl_backups01_smb'
 select '
RESTORE DATABASE ['+database_name+']
   FROM DISK = '''+REPLACE(physical_device_name,'F:\backups01',@bkupLOC)+'''
   WITH FILE = 1
      , MOVE '''+bf_data.logical_name+''' TO ''E:\data01\data\'+database_name+'.mdf''
      , MOVE '''+bf_log.logical_name+''' TO ''E:\logs01\data\'+database_name+'_log.ldf''
      , STATS = 10
	 GO '
   from msdb.dbo.backupmediaset bms
   join msdb.dbo.backupmediafamily bmf
     on bms.media_set_id = bmf.media_set_id
   join msdb.dbo.backupset bs
     on bms.media_set_id = bs.media_set_id
   join msdb.dbo.backupfile bf_data
     on bs.backup_set_id = bf_data.backup_set_id
    and bf_data.file_type = 'D'
   join msdb.dbo.backupfile bf_log
     on bs.backup_set_id = bf_log.backup_set_id
    and bf_log.file_type = 'L'
  where bs.type = 'D'
    and bs.backup_start_date > '2014-12-29'
  order by bs.backup_start_date desc