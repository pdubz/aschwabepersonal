SET NOCOUNT ON

DECLARE @dbname nvarchar(255) = 'eSiteGrecoProperties'
      , @fullRestoreFile nvarchar(1024)
      , @diffRestoreFile nvarchar(1024)
      , @physicalLocation nvarchar(256) = 'E:\backups01\'
      , @shareLocation nvarchar(256) = '\\' + @@SERVERNAME + '\backup\'

DECLARE @Domain sysname
      , @UserAcct sysname
  
DECLARE @tempRestoreName nvarchar(256) = @dbname + '_Temp'

SELECT @Domain = DEFAULT_DOMAIN()
   SET @UserAcct = @Domain + N'\sql' + @Domain+ '_svc' 

SELECT @fullRestoreFile = ( SELECT TOP 1 replace(bf.physical_device_name, @physicalLocation + 'full\', @shareLocation + 'full\')
                              FROM master.sys.databases d
                              JOIN msdb.dbo.backupset bs
                                ON bs.type = 'D'
                               AND d.name = bs.database_name
                              JOIN msdb.dbo.backupmediafamily bf 
                                ON bf.media_set_id = bs.media_set_id
                             WHERE d.name = @dbname
                               AND bf.physical_device_name like 'E:\backups01\%'
                             ORDER BY bs.backup_start_date DESC
                          ) ;

SELECT @diffRestoreFile = ( SELECT TOP 1 REPLACE( bf.physical_device_name, @physicalLocation + 'diff\', @shareLocation + 'diff\' )
                              FROM master.sys.databases d
                              JOIN msdb.dbo.backupset bs
                                ON bs.type = 'I'
                               AND d.name = bs.database_name
                              JOIN msdb.dbo.backupmediafamily bf 
                                ON bf.media_set_id = bs.media_set_id
                             WHERE d.name = @dbname
                               AND bf.physical_device_name like 'E:\backups01\%'
                             ORDER BY bs.backup_start_date DESC
                          ) ;

CREATE TABLE #RestoreFileList ( LogicalName nvarchar(128)
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

INSERT INTO #RestoreFileList
  EXEC ( 'RESTORE FILELISTONLY FROM DISK = ''' + @fullRestoreFile + '''' )

DECLARE @logicalData nvarchar(255)
      , @logicalLog nvarchar(255)

SELECT @logicalData = LogicalName
  FROM #RestoreFileList
 WHERE Type = 'D'

SELECT @logicalLog = LogicalName
  FROM #RestoreFileList
 WHERE Type = 'L'

  DROP TABLE #RestoreFileList

  EXEC ( 'RESTORE DATABASE [' + @tempRestoreName + ']
             FROM DISK = ''' + @fullRestoreFile + '''
             WITH FILE = 1
                , MOVE ''' + @logicalData + ''' TO ''E:\data01\data\' +  @tempRestoreName + '.mdf''
                , MOVE ''' + @logicalLog + ''' TO ''E:\logs01\data\' + @tempRestoreName + '_log.ldf''
                , NORECOVERY
                , STATS = 10' )

  EXEC ( 'RESTORE DATABASE [' + @tempRestoreName + ']
             FROM DISK = ''' + @diffRestoreFile + '''
             WITH FILE = 1
                , RECOVERY
                , STATS = 10' )

  EXEC ( 'ALTER DATABASE [' + @tempRestoreName + '] MODIFY FILE ( NAME = [' + @logicalData + '], NEWNAME = [' + @tempRestoreName + '_data] )' )
  EXEC ( 'ALTER DATABASE [' + @tempRestoreName + '] MODIFY FILE ( NAME = [' + @logicalLog + '], NEWNAME = [' + @tempRestoreName + '_log] )' )
  EXEC ( 'ALTER AUTHORIZATION ON DATABASE::[' + @tempRestoreName + '] to [' + @UserAcct + ']' ) 

  EXEC util.dbo.usp_backup_db @bu_type = 'full'
                            , @dbname = @tempRestoreName

/*

declare @emailbody nvarchar(2000)
      , @emailSubject nvarchar(255)

set @emailSubject = 'Restore of ' + @dbRestoreName + ' as temporary database ' + @tempRestoreName + ' on ' + @@SERVERNAME + ' is complete.'
set @emailBody = 'Restore of ' + @dbRestoreName + ' as temporary database ' + @tempRestoreName + ' on ' + @@SERVERNAME + ' is complete.'
               + CHAR(10) + CHAR(13)
               + 'Used ' + @dbRestoreFile + ' to create ' + @tempRestoreName

exec msdb.dbo.sp_notify_operator @profile_name = 'SQLMail Profile'
                               , @name = 'AMSI Group'
                               , @subject = @emailSubject
                               , @body = @emailBody
*/

