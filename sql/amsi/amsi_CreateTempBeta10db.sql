set nocount on
declare @dbRestoreName nvarchar(255) = 'eServiceDotNetTRMcKenzie'
      , @deleteDate nvarchar(10) = 20150618
      , @dbRestoreFile nvarchar(512)
      , @location nvarchar(512) = '\\' + @@SERVERNAME + '\backup\full\'
  
declare @tempDeleteDBName nvarchar(255) = @dbRestoreName + '_Beta10'

--backup database
exec util.dbo.usp_backup_db @bu_type = 'full', @dbname = @dbRestoreName

set @dbRestoreFile = (select top 1 replace(bf.physical_device_name, 'E:\backups01\full\', @location)
  from sys.databases d
  join msdb.dbo.backupset bs
    on bs.type = 'D'
   and d.name = bs.database_name
  join msdb.dbo.backupmediafamily bf 
    on bf.media_set_id = bs.media_set_id
 where d.name = @dbRestoreName
   and bf.physical_device_name like 'E:\%'
 order by bs.backup_start_date desc)

 print @dbRestoreFile

create table #RestoreFileList (
LogicalName nvarchar(128)
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
, TDEThumbprint varbinary(32))

print 'Getting File List...'
insert into #RestoreFileList
exec ('restore filelistonly from disk = ''' + @dbRestoreFile + '''')

declare @logicalData nvarchar(255)
, @logicalLog nvarchar(255)

select @logicalData = LogicalName
  from #RestoreFileList
 where Type = 'D'

select @logicalLog = LogicalName
  from #RestoreFileList
 where Type = 'L'

print 'Restore Database...'

exec ('
restore database [' + @tempDeleteDBName + ']
   from disk = ''' + @dbRestoreFile + '''
   with file = 1
      , move ''' + @logicalData + ''' to ''E:\data01\data\' +  @tempDeleteDBName + '_data.mdf''
      , move ''' + @logicalLog + ''' to ''E:\logs01\data\' + @tempDeleteDBName + '_log.ldf''
      , recovery
      , stats = 10')

print 'Setting logical file names'
exec ('ALTER DATABASE [' + @tempDeleteDBName + '] MODIFY FILE (NAME = [' + @logicalData + '], NEWNAME = [' + @tempDeleteDBName + '_data])')
exec ('ALTER DATABASE [' + @tempDeleteDBName + '] MODIFY FILE (NAME = [' + @logicalLog + '], NEWNAME = [' + @tempDeleteDBName + '_log])')

drop table #RestoreFileList


print 'Backing up database...'
exec util.dbo.usp_backup_db @bu_type = 'full'
                          , @dbname = @tempDeleteDBName

DECLARE @Domain sysname, @UserAcct sysname
SELECT @Domain = DEFAULT_DOMAIN()
   SET @UserAcct = @Domain + N'\sql' + @Domain+ '_svc' 

EXEC ( 'ALTER AUTHORIZATION ON DATABASE::[' + @tempDeleteDBName + '] to [' + @UserAcct + ']' )

EXEC master.dbo.sp_configure 'show advanced options', 1;
RECONFIGURE WITH OVERRIDE;
EXEC master.dbo.sp_configure 'xp_cmdshell', 1;
RECONFIGURE WITH OVERRIDE;

DECLARE @cmd nvarchar(200)
SET @cmd = 'powershell.exe -Command "& C:\salt\customizations\amsi\addDBtoAG.ps1 -dbname '+ @tempDeleteDBName + '"'
print @cmd
EXEC xp_cmdshell @cmd

EXEC ( 'ALTER AUTHORIZATION ON DATABASE::[' + @tempDeleteDBName + '] to [' + @UserAcct + ']' )

declare @emailbody nvarchar(2000)
      , @emailSubject nvarchar(255)

set @emailSubject = 'Restore of ' + @dbRestoreName + ' as temporary database ' + @tempDeleteDBName + ' on ' + @@SERVERNAME + ' is complete.'
set @emailBody = 'Restore of ' + @dbRestoreName + ' as temporary database ' + @tempDeleteDBName + ' on ' + @@SERVERNAME + ' is complete.'
               + CHAR(10) + CHAR(13)
               + 'Used ' + @dbRestoreFile + ' to create ' + @tempDeleteDBName

exec msdb.dbo.sp_notify_operator @profile_name = 'SQLMail Profile'
                               , @name = 'App Group'
                               , @subject = @emailSubject
                               , @body = @emailBody
