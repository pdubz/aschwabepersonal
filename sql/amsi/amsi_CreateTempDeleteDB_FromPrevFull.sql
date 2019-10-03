   SET NOCOUNT ON
DECLARE @dbRestoreName nvarchar(255) = 'eSiteRam'
     , @deleteDate nvarchar(10) = '011516'
DECLARE @tempDeleteDBName nvarchar(255) = @dbRestoreName + '_TempDel' + @deleteDate
     , @dbRestoreFile nvarchar(512) = '\\' + @@SERVERNAME + '\backup\full\' + @dbRestoreName + '\eSiteRam_full_20151223202517.bak'
   
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
  EXEC ('RESTORE FILELISTONLY FROM DISK = ''' + @dbRestoreFile + '''')

DECLARE @logicalData nvarchar(255)
      , @logicalLog nvarchar(255)

SELECT @logicalData = LogicalName
  FROM #RestoreFileList
 WHERE Type = 'D'

SELECT @logicalLog = LogicalName
  FROM #RestoreFileList
 WHERE Type = 'L'

  DROP TABLE #RestoreFileList

  EXEC ('RESTORE DATABASE [' + @tempDeleteDBName + ']
            FROM DISK = ''' + @dbRestoreFile + '''
            WITH FILE = 1
               , MOVE ''' + @logicalData + ''' TO ''E:\data01\data\' +  @tempDeleteDBName + '.mdf''
               , MOVE ''' + @logicalLog + ''' TO ''E:\logs01\data\' + @tempDeleteDBName + '_log.ldf''
               , RECOVERY
               , STATS = 10'
       ) ;

EXEC ('ALTER DATABASE [' + @tempDeleteDBName + '] MODIFY FILE (NAME = [' + @logicalData + '], NEWNAME = [' + @tempDeleteDBName + '])')
EXEC ('ALTER DATABASE [' + @tempDeleteDBName + '] MODIFY FILE (NAME = [' + @logicalLog + '], NEWNAME = [' + @tempDeleteDBName + '_log])')



  EXEC util.dbo.usp_backup_db @bu_type = 'full'
                            , @dbname = @tempDeleteDBName

DECLARE @Domain sysname, @UserAcct sysname
SELECT @Domain = DEFAULT_DOMAIN()
   SET @UserAcct = @Domain + N'\sql' + @Domain+ '_svc' 

  EXEC ( 'ALTER AUTHORIZATION ON DATABASE::[' + @tempDeleteDBName + '] to [' + @UserAcct + ']' )

DECLARE @emailbody nvarchar(2000)
      , @emailSubject nvarchar(255)

   SET @emailSubject = 'Restore of ' + @dbRestoreName + ' as temporary database ' + @tempDeleteDBName + ' on ' + @@SERVERNAME + ' is complete.'
   SET @emailBody = 'Restore of ' + @dbRestoreName + ' as temporary database ' + @tempDeleteDBName + ' on ' + @@SERVERNAME + ' is complete.'
                  + CHAR(10) + CHAR(13)
                  + 'Used ' + @dbRestoreFile + ' to create ' + @tempDeleteDBName

  EXEC msdb.dbo.sp_notify_operator @profile_name = 'SQLMail Profile'
                                 , @name = 'App Group'
                                 , @subject = @emailSubject
                                 , @body = @emailBody
  
  EXEC msdb.dbo.sp_notify_operator @profile_name = 'SQLMail Profile'
                                 , @name = 'DBA Group'
                                 , @subject = @emailSubject
                                 , @body = @emailBody
