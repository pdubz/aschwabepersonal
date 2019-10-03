SET NOCOUNT ON
DECLARE @dbRestoreName nvarchar(255) = 'eSiteQuestManagementGroup'
DECLARE @backupDate nvarchar(10) = '20151230'
      , @dbRestoreFile nvarchar(512) = '\\' + @@SERVERNAME + '\backup\full\' + @dbRestoreName + '\eSiteQuestManagementGroup_full_20151227012303.bak'
      , @diffRestoreFile nvarchar(512) = '\\' + @@SERVERNAME + '\backup\diff\' + @dbRestoreName + '\eSiteQuestManagementGroup_diff_20151230002943.diff'
      , @pword nvarchar(50) = 'Amsi20160105'
      , @truncate CHAR(1) = 'Y'
  
DECLARE @tempDeleteDBName nvarchar(255) = @dbRestoreName + '_' + @backupDate

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
 WHERE [Type] = 'D'
 
SELECT @logicalLog = LogicalName
  FROM #RestoreFileList
 WHERE [Type] = 'L'

  DROP TABLE #RestoreFileList

IF ( @diffRestoreFile <> '' )
   BEGIN
         EXEC ( 'RESTORE DATABASE [' + @tempDeleteDBName + ']
                    FROM DISK = ''' + @dbRestoreFile + '''
                    WITH FILE = 1
                       , MOVE ''' + @logicalData + ''' TO ''E:\data01\data\' +  @tempDeleteDBName + '_data.mdf''
                       , MOVE ''' + @logicalLog + ''' TO ''E:\logs01\data\' + @tempDeleteDBName + '_log.ldf''
                       , NORECOVERY
                       , STATS = 10'
              ) ;
         EXEC ( 'RESTORE DATABASE [' + @tempDeleteDBName + ']
                    FROM DISK = ''' + @diffRestoreFile + '''
                    WITH FILE = 1
                       , RECOVERY
                       , STATS = 10'
              ) ;
     END
ELSE
   BEGIN
         EXEC ( 'RESTORE DATABASE [' + @tempDeleteDBName + ']
                    FROM DISK = ''' + @dbRestoreFile + '''
                    WITH FILE = 1
                       , MOVE ''' + @logicalData + ''' TO ''E:\data01\data\' +  @tempDeleteDBName + '_data.mdf''
                       , MOVE ''' + @logicalLog + ''' TO ''E:\logs01\data\' + @tempDeleteDBName + '_log.ldf''
                       , RECOVERY
                       , STATS = 10'
              ) ;
     END

  EXEC ('ALTER DATABASE [' + @tempDeleteDBName + '] MODIFY FILE (NAME = [' + @logicalData + '], NEWNAME = [' + @tempDeleteDBName + '_data])')
  EXEC ('ALTER DATABASE [' + @tempDeleteDBName + '] MODIFY FILE (NAME = [' + @logicalLog + '], NEWNAME = [' + @tempDeleteDBName + '_log])')



  EXEC util.dbo.usp_backup_db @bu_type = 'full'
                            , @dbname = @tempDeleteDBName

DECLARE @Domain sysname, @UserAcct sysname
SELECT @Domain = DEFAULT_DOMAIN()
   SET @UserAcct = @Domain + N'\sql' + @Domain+ '_svc' 

  EXEC ( 'ALTER AUTHORIZATION ON DATABASE::[' + @tempDeleteDBName + '] to [' + @UserAcct + ']' )

  EXEC dba.dbo.usp_send_to_support @dbname = @tempDeleteDBName
                                 , @code = @pword
                                 , @customs = @truncate
                                 , @testBackup = 'Y'
                                 , @utilServerName = 'amsiutil01'

  EXEC ( 'ALTER DATABASE [' + @tempDeleteDBName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE' );
  EXEC ( 'DROP DATABASE [' + @tempDeleteDBName + ']' );
