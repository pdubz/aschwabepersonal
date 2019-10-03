SET NOCOUNT ON
DECLARE @dbRestoreName nvarchar(255) = 'eSiteTectonCorporation'
     , @dbRestoreFile nvarchar(512)
     , @location nvarchar(512) = '\\' + @@SERVERNAME + '\backup\full\'
     , @utilServer nvarchar(100) = 'amsiutil02-c'
     , @now nvarchar(8)
     , @scrubDBName nvarchar(255)
     , @code nvarchar(20)
     , @customs nvarchar(1) = 'Y'

   SET @scrubDBName = @dbRestoreName + '_Scrubbed'
   SET @now = CONVERT(NVARCHAR(8),GETDATE(),112)
   SET @code = 'Amsi9648123'

  EXEC util.dbo.usp_backup_db @bu_type = 'full'
                            , @dbname = @dbRestoreName

   SET @dbRestoreFile = ( SELECT TOP 1 REPLACE( bf.physical_device_name, 'E:\backups01\full\', @location )
                            FROM master.sys.databases d
                            JOIN msdb.dbo.backupset bs
                              ON bs.type = 'D'
                             AND d.name = bs.database_name
                            JOIN msdb.dbo.backupmediafamily bf
                              ON bf.media_set_id = bs.media_set_id
                           WHERE d.name = @dbRestoreName
                             AND bf.physical_device_name like 'E:\%'
                           ORDER BY bs.backup_start_date DESC
                        ) ;

CREATE TABLE #RestoreFileList ( LogicalName nvarchar(128)
                              , PhysicalName nvarchar(260)
                              , [Type] Char(1)
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
  EXEC ( 'RESTORE FILELISTONLY
             FROM DISK = ''' + @dbRestoreFile + ''''
       ) ;

DECLARE @logicalData nvarchar(255)
      , @logicalLog nvarchar(255)

SELECT @logicalData = LogicalName
  FROM #RestoreFileList
 WHERE [Type] = 'D'

SELECT @logicalLog = LogicalName
  FROM #RestoreFileList
 WHERE [Type] = 'L'

  DROP TABLE #RestoreFileList

  EXEC ( 'RESTORE DATABASE [' + @scrubDBName + ']
             FROM DISK = ''' + @dbRestoreFile + '''
             WITH FILE = 1
                , MOVE ''' + @logicalData + ''' TO ''E:\data01\data\' +  @scrubDBName + '.mdf''
                , MOVE ''' + @logicalLog + ''' TO ''E:\logs01\data\' + @scrubDBName + '_log.ldf''
                , RECOVERY
                , STATS = 10'
       ) ;

  EXEC ( 'ALTER DATABASE [' + @scrubDBName + '] MODIFY FILE (NAME = [' + @logicalData + '], NEWNAME = [' + @scrubDBName + '])' )
  EXEC ( 'ALTER DATABASE [' + @scrubDBName + '] MODIFY FILE (NAME = [' + @logicalLog + '], NEWNAME = [' + @scrubDBName + '_log])' )

  EXEC util.dbo.usp_backup_db @bu_type = 'full'
                            , @dbname = @scrubDBName

DECLARE @Domain sysname, @UserAcct sysname
SELECT @Domain = DEFAULT_DOMAIN()
   SET @UserAcct = @Domain + N'\sql' + @Domain+ '_svc'

  EXEC ( 'ALTER AUTHORIZATION ON DATABASE::[' + @scrubDBName + '] to [' + @UserAcct + ']' )

DECLARE @firstFourChar NVARCHAR(4)
      , @sql nvarchar(max)
   SET @firstFourChar = @scrubDBName

IF ( @firstFourChar = 'eSit' ) OR ( @firstFourChar = 'eCom' )
   BEGIN
          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[additionalinsured]
                         SET email = ''dummy@dummy.com'''
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[addressbook]
                         SET email = ''dummy@dummy.com'''
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[bankbookheader]
                         SET bankacctno = ''1'''
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[credithistory]
                         SET dlnumber = NULL
                           , email = NULL'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[creditscreenhistory]
                         SET xmldata = NULL'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[directrent]
                         SET originaba = NULL
                           , destinationaba = NULL
                           , fedid = NULL'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[epaysetup]
                         SET bankacct = ''1'''
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[micrscanner]
                         set acctno = STR(ABS(CHECKSUM(NewId()) % 100000000000000))'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[occupantheader]
                         SET occussn = NULL
                           , ssn_encrypted = NULL'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[transactionheader]
                         SET imagedata = NULL
                           , imagedataback = NULL'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[unqualguests]
                         SET ssn = NULL
                           , ssn_encrypted = NULL'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      DELETE
                        FROM [' + @scrubDbName + '].[dbo].[webservicelogin]'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql
     END
ELSE IF ( @firstFourChar = 'eFin' )
   BEGIN
          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[tblACHData]
                         SET AccountNo = ''1'''
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[tblBankAccount]
                         SET AccountNo = ''1'''
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[tblPayee]
                         SET taxId = NULL'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[tblPayeeDirectDeposit]
                         SET accountnumber = ''1''
                           , emailaddress = ''dummy@dummy.com'''
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[tblTransmitter]
                         SET FederalTaxID = NULL'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      DELETE
                        FROM [' + @scrubDbName + '].[dbo].[tblWebServiceSetup]'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[tblAddressBook]
                         SET email = ''dummy@dummy.com'''
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

     END
ELSE IF ( @firstFourChar = 'eSer' )
   BEGIN
          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[tblAddressBook]
                         SET email = ''dummy@dummy.com'''
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      UPDATE [' + @scrubDBName + '].[dbo].[tblEmployee]
                         SET DLNo = NULL
                           , SSN = NULL'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      DELETE
                        FROM [' + @scrubDbName + '].[dbo].[tblWebServiceSetup]'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

     END
ELSE IF ( @firstFourChar = 'eDex' )
   BEGIN
          SET @sql = '/*------------------------------------------------------*/
                      ALTER TABLE [' + @scrubDBName + '].[dbo].[WebservicesAccessLog]
                       DROP CONSTRAINT FK_WebservicesAccessLog_AuthenticationUsers'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                       ALTER TABLE [' + @scrubDBName + '].[dbo].[WebservicesAccessLogDetails]
                        DROP CONSTRAINT FK_WebservicesAccessLogDetails_WebservicesAccessLog'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      TRUNCATE TABLE [' + @scrubDBName + '].dbo.WebservicesAccessLog'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql

          SET @sql = '/*------------------------------------------------------*/
                      TRUNCATE TABLE [' + @scrubDBName + '].dbo.WebservicesAccessLogDetails'
        PRINT @sql
         EXEC master.sys.sp_executesql @sql
   END

ELSE
   BEGIN
         DECLARE @errorMSG nvarchar(500)
         SET @errorMSG = 'There is no scrub script for this type of AMSI database. The script has been terminated to ensure non-secure data will not leave the server. Dropped the restored database ' + @scrubDBName + '.'
         EXEC ( 'DROP DATABASE [' + @scrubDBName + ']' );
         RAISERROR (@errorMSG,20, -1) WITH LOG
     END

DECLARE @emailbody nvarchar(2000)
     , @emailSubject nvarchar(255)

   SET @emailSubject = 'Restore of ' + @dbRestoreName + ' as a scrubbed database (' + @scrubDBName + ') on ' + @@SERVERNAME + ' is complete.'
   SET @emailBody = 'Restore of ' + @dbRestoreName + ' as a scrubbed database (' + @scrubDBName + ') on ' + @@SERVERNAME + ' is complete.'
                  + CHAR(10)
                  + CHAR(13)
                  + 'Used ' + @dbRestoreFile + ' to create ' + @scrubDBName
                  + CHAR(10)
                  + CHAR(13)
                  + 'Beginning to decrypt the database and upload it to S3.'
                  + CHAR(10)
                  + CHAR(13)
                  + 'The password for this zip file will be: ''' + @code + ''''

  EXEC msdb.dbo.sp_notify_operator @profile_name = 'SQLMail Profile'
                                 , @name = 'App Group'
                                 , @subject = @emailSubject
                                 , @body = @emailBody

  EXEC msdb.dbo.sp_notify_operator @profile_name = 'SQLMail Profile'
                                 , @name = 'DBA Group'
                                 , @subject = @emailSubject
                                 , @body = @emailBody

  EXEC dba.dbo.usp_send_to_support @dbName = @scrubDBName
                                 , @code = @code
                                 , @testBackup = 'Y'
                                 , @utilServerName = @utilServer
                                 , @customs = @customs

  EXEC ( 'DROP DATABASE [' + @scrubDBName + ']' )
