declare @dbRestoreFile nvarchar(512)
      , @dbname nvarchar(256) = 'eSiteTomHomGroup'
      , @location nvarchar(512) = '\\' + @@SERVERNAME + '\backup\full\'
      , @sourceDBName nvarchar(256) = 'eSiteWIMemphis_Source'

exec dba.dbo.usp_backup_db @dbname = @dbname
                         , @bu_type = 'full'

   set @dbRestoreFile = (select top 1 replace(bf.physical_device_name, 'E:\backups01\full\', @location)
  from sys.databases d
  join msdb.dbo.backupset bs
    on bs.type = 'D'
   and d.name = bs.database_name
  join msdb.dbo.backupmediafamily bf 
    on bf.media_set_id = bs.media_set_id
 where d.name = @dbname
   and bf.physical_device_name like 'E:\%'
 order by bs.backup_start_date desc)

--Restore database as NoDocs name
create table #RestoreFileList ( LogicalName nvarchar(128)
                              , PhysicalName nvarchar(260)
                              , Type Char(1)
                              , FileGroupName nvarchar(128)
                              , Size numeric(20,0)
                              , maxSize numeric(20,0)
                              , FileId int
                              , CreateLSN numeric(25,0)
                              , DropLSN numeric(25,0)
                              , UniqueId uniqueidentifier
                              , ReadOnlyLSN numeric(25,0)
                              , ReadWriteLSN numeric(25,0)
                              , BackupSizeInBytes bigint
                              , SourceBlockSize int
                              , FileGroupId int
                              , LogGroupGUID uniqueidentifier
                              , DifferentialBaseLSN numeric(25,0)
                              , DifferentialBaseGUID uniqueidentifier
                              , IsReadOnly bit
                              , IsPresent bit
                              , TDEThumbprint varbinary(32)
                              ) ;

insert into #RestoreFileList
  exec ('restore filelistonly from disk = ''' + @dbRestoreFile + '''');

declare @logicalData nvarchar(255)
      , @logicalLog nvarchar(255);

select @logicalData = LogicalName
  from #RestoreFileList
 where Type = 'D';

select @logicalLog = LogicalName
  from #RestoreFileList
 where Type = 'L'
 
exec ('restore database [' + @sourceDBName + ']
          from disk = ''' + @dbRestoreFile + '''
          with file = 1
             , move ''' + @logicalData + ''' to ''E:\data01\data\' +  @sourceDBName + '_data.mdf''
             , move ''' + @logicalLog + ''' to ''E:\logs01\data\' + @sourceDBName + '_log.ldf''
             , recovery
             , stats = 10')

exec ('ALTER DATABASE [' + @sourceDBName + '] MODIFY FILE (NAME = [' + @logicalData + '], NEWNAME = [' + @sourceDBName + '_data])')
exec ('ALTER DATABASE [' + @sourceDBName + '] MODIFY FILE (NAME = [' + @logicalLog + '], NEWNAME = [' + @sourceDBName + '_log])')

drop table #RestoreFileList

exec ('use [' + @sourceDBName + ']; exec sp_changedbowner ''prod\sqlprod_svc''')

exec dba.dbo.usp_backup_db @dbname = @sourceDBName
                         , @bu_type = 'full'
