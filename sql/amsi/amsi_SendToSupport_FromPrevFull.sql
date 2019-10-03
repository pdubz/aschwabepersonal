   SET NOCOUNT ON
DECLARE @dbRestoreName nvarchar(255) = 'eFinancialsDixonRealEstate'
     , @deleteDate nvarchar(10) = '20150104'
DECLARE @tempDeleteDBName nvarchar(255) = @dbRestoreName + @deleteDate
     , @dbRestoreFile nvarchar(512) = '\\' + @@SERVERNAME + '\backup\full\' + @dbRestoreName + '\eFinancialsDixonRealEstate_20151230_full_20160106122119.bak'
     , @code nvarchar(20) = 'Amsi9246646'
     , @utilServer nvarchar(20) = 'amsiutil01'
   
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

  EXEC dba.dbo.usp_send_to_support @dbName = @tempDeleteDBName
                                 , @code = @code
                                 , @testBackup = 'Y'
                                 , @utilServerName = @utilServer
                                 , @customs = 'N'

  EXEC ( 'DROP DATABASE [' + @tempDeleteDBName + ']' )
