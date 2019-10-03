USE util;
GO

IF NOT EXISTS (
	SELECT 1
	  FROM sys.procedures sp
	  JOIN sys.schemas ss
	    ON sp.schema_id = ss.schema_id
	 WHERE ss.name = 'dbo'
	   AND sp.name = 'RestoreDB'
)
BEGIN
	EXEC ( 'CREATE PROCEDURE dbo.RestoreDB AS BEGIN SET NOCOUNT ON END' )
END;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

ALTER PROCEDURE dbo.RestoreDB @DBName NVARCHAR(255)
                            , @File NVARCHAR(255)
                            , @BackupType NVARCHAR(4) = 'FULL'
                            , @Recovery NVARCHAR(5) = 'TRUE'
                            , @Replace NVARCHAR(5) = 'FALSE'
                            , @DBCC NVARCHAR(1) = 'N'
                            , @CompatibilityLevel NVARCHAR(3) = NULL
                            , @AddToAG NVARCHAR(1) = 'N'
                            , @Encrypt NVARCHAR(1) = 'N'
                            , @Help NVARCHAR(1) = 'N'

AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Usage NVARCHAR(MAX)
         , @CRLF CHAR(2) = CHAR(13) + CHAR(10)
         , @ErrorMessage NVARCHAR(MAX);

       SET @Usage = @CRLF  + 'EXEC dbo.RestoreDB @DBName = ''dbname'', @File = ''file'' [, @BackupType = ''FULL|DIFF|LOG'', @Recovery = ''Y'', @Replace = ''N'', @DBCC = ''N'', @CompatibilityLevel = ''110'', @AddToAG = ''N'', @Encrypt = ''N'']' + @CRLF;
       SET @Usage = @Usage + '    Required Parameters: @DBName, @File' + @CRLF;
       SET @Usage = @Usage + '        @DBName : name for the restored backup' + @CRLF;
       SET @Usage = @Usage + '          @File : file desired to be restored' + @CRLF;
       SET @Usage = @Usage + '    Optional Parameters:' + @CRLF;
       SET @Usage = @Usage + '                @BackupType : FULL [default], DIFF, LOG' + @CRLF;
       SET @Usage = @Usage + '                              backup type to be restored' + @CRLF;
       SET @Usage = @Usage + '                  @Recovery : TRUE [default], FALSE' + @CRLF;
       SET @Usage = @Usage + '                              restore database with recovery' + @CRLF;
       SET @Usage = @Usage + '                   @Replace : FALSE [default], TRUE' + @CRLF;
       SET @Usage = @Usage + '                              restore database over existing database with same name' + @CRLF;
       SET @Usage = @Usage + '                      @DBCC : N [default], Y' + @CRLF;
       SET @Usage = @Usage + '                              run DBCC CHECKDB on the restored database' + @CRLF;
       SET @Usage = @Usage + '        @CompatibilityLevel : NULL [default], 80, 90, 100, 110, 120, 130' + @CRLF;
       SET @Usage = @Usage + '                              sets certain database behaviors in the restored database to be compatible with the specified version of SQL Server' + @CRLF;
       SET @Usage = @Usage + '                   @AddToAG : N [default], Y' + @CRLF;
       SET @Usage = @Usage + '                              if there is an availability group, the database will be added to the availability group and synced across all nodes' + @CRLF;
       SET @Usage = @Usage + '                   @Encrypt : N [default], Y' + @CRLF;
       SET @Usage = @Usage + '                              finds the server''s TDE cert and encrypts the database with it' + @CRLF;
       SET @Usage = @Usage + '                      @Help : N [default], Y' + @CRLF;
       SET @Usage = @Usage + '                              prints help text and then exits' + @CRLF;

    /*ensure upper case for case sensitive collations*/
    SELECT @BackupType = UPPER(@BackupType);
    SELECT @Recovery = UPPER(@Recovery);
    SELECT @Replace = UPPER(@Replace);
    SELECT @DBCC = UPPER(@DBCC);
    SELECT @AddToAG = UPPER(@AddToAG);
    SELECT @Encrypt = UPPER(@Encrypt);
    SELECT @Help = UPPER(@Help);

    /*trim leading or trailing spaces*/
    SELECT @DBName = LTRIM(RTRIM(@DBName));
    SELECT @BackupType = LTRIM(RTRIM(@BackupType));
    SELECT @Recovery = LTRIM(RTRIM(@Recovery));
    SELECT @Replace = LTRIM(RTRIM(@Replace))

    /*convert compat level????*/

    /*if help text is requested, do not run any of the rest of the sproc*/
    IF (@Help = 'Y')
    BEGIN
        /*print help text*/
        print @Usage;
    END;
    /*help text not requested, move into rest of sproc*/
    ELSE
    BEGIN
        BEGIN /*validate inputs*/
            BEGIN /*check for null, if found, exit*/
                IF (ISNULL(@DBName, '') = '')
                BEGIN
                    SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @DBName cannot be NULL or empty' + @CRLF + @CRLF;
                    SET @ErrorMessage = @ErrorMessage + @Usage;
                    RAISERROR(@ErrorMessage, 16, 1);
                    RETURN -1;
                END;

                IF (ISNULL(@File, '') = '')
                BEGIN
                    SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @File cannot be NULL or empty' + @CRLF + @CRLF;
                    SET @ErrorMessage = @ErrorMessage + @Usage;
                    RAISERROR(@ErrorMessage, 16, 1);
                    RETURN -1;
                END;

                IF (ISNULL(@BackupType, '') = '')
                BEGIN
                    SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @BackupType cannot be NULL or empty' + @CRLF + @CRLF;
                    SET @ErrorMessage = @ErrorMessage + @Usage;
                    RAISERROR(@ErrorMessage, 16, 1);
                    RETURN -1;
                END;

                IF (ISNULL(@Recovery, '') = '')
                BEGIN
                    SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @Recovery cannot be NULL or empty' + @CRLF + @CRLF;
                    SET @ErrorMessage = @ErrorMessage + @Usage;
                    RAISERROR(@ErrorMessage, 16, 1);
                    RETURN -1;
                END;

                IF (ISNULL(@Replace, '') = '')
                BEGIN
                    SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @Replace cannot be NULL or empty' + @CRLF + @CRLF;
                    SET @ErrorMessage = @ErrorMessage + @Usage;
                    RAISERROR(@ErrorMessage, 16, 1);
                    RETURN -1;
                END;

                IF (ISNULL(@DBCC, '') = '')
                BEGIN
                    SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @DBCC cannot be NULL or empty' + @CRLF + @CRLF;
                    SET @ErrorMessage = @ErrorMessage + @Usage;
                    RAISERROR(@ErrorMessage, 16, 1);
                    RETURN -1;
                END;

                IF (ISNULL(@AddToAG, '') = '')
                BEGIN
                    SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @AddToAG cannot be NULL or empty' + @CRLF + @CRLF;
                    SET @ErrorMessage = @ErrorMessage + @Usage;
                    RAISERROR(@ErrorMessage, 16, 1);
                    RETURN -1;
                END;

                IF (ISNULL(@Encrypt, '') = '')
                BEGIN
                    SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @Encrypt cannot be NULL or empty' + @CRLF + @CRLF;
                    SET @ErrorMessage = @ErrorMessage + @Usage;
                    RAISERROR(@ErrorMessage, 16, 1);
                    RETURN -1;
                END;
            END;

            /*ensure database name doesn't have bad characters*/
            IF (    ((SELECT CHARINDEX('[', @DBName)) <> 0)
                 OR ((SELECT CHARINDEX(']', @DBName)) <> 0)
                 OR ((SELECT CHARINDEX('.', @DBName)) <> 0)
                 OR ((SELECT CHARINDEX('"', @DBName)) <> 0)
                 OR ((SELECT CHARINDEX('''', @DBName)) <> 0) )
            BEGIN
                SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @DBName cannot contain any of the following characters: ", '', ., [, or ]' + @CRLF + @CRLF;
                SET @ErrorMessage = @ErrorMessage + @Usage;
                RAISERROR(@ErrorMessage, 16, 1);
                RETURN -1;
            END;

            /*ensure backup type is one of three options*/
            IF ( (@BackupType NOT IN ('FULL','DIFF','LOG')) )
            BEGIN
                SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @BackupType must be one of the following: FULL, DIFF, or LOG' + @CRLF + @CRLF;
                SET @ErrorMessage = @ErrorMessage + @Usage;
                RAISERROR(@ErrorMessage, 16, 1);
                RETURN -1;
            END;

            /*ensure recovery is TRUE or FALSE*/
            IF ( (@Recovery NOT IN ('TRUE','FALSE')) )
            BEGIN
                SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @Recovery must be one of the following: TRUE or FALSE' + @CRLF + @CRLF;
                SET @ErrorMessage = @ErrorMessage + @Usage;
                RAISERROR(@ErrorMessage, 16, 1);
                RETURN -1;
            END;

            /*ensure replace is TRUE or FALSE*/
            IF ( (@Replace NOT IN ('TRUE','FALSE')) )
            BEGIN
                SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @Replace must be one of the following: TRUE or FALSE' + @CRLF + @CRLF;
                SET @ErrorMessage = @ErrorMessage + @Usage;
                RAISERROR(@ErrorMessage, 16, 1);
                RETURN -1;
            END;

            /*ensure dbcc is Y or N*/
            IF ( (@DBCC NOT IN ('Y','N')) )
            BEGIN
                SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @DBCC must be one of the following: Y or N' + @CRLF + @CRLF;
                SET @ErrorMessage = @ErrorMessage + @Usage;
                RAISERROR(@ErrorMessage, 16, 1);
                RETURN -1;
            END;

            /*ensure compatibility level is valid*/
            IF (@CompatibilityLevel IS NOT NULL)
            BEGIN
                IF (@CompatibilityLevel NOT IN ('80','90','100','110','120','130'))
                BEGIN
                    SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @CompatibilityLevel must be one of the following: 80, 90, 100, 110, 120, 130, or NULL' + @CRLF + @CRLF;
                    SET @ErrorMessage = @ErrorMessage + @Usage;
                    RAISERROR(@ErrorMessage, 16, 1);
                    RETURN -1;
                END;
            END;

            /*ensure AddToAG is Y or N*/
            IF ( (@AddToAG NOT IN ('Y','N')) )
            BEGIN
                SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @AddToAG must be one of the following: Y or N' + @CRLF + @CRLF;
                SET @ErrorMessage = @ErrorMessage + @Usage;
                RAISERROR(@ErrorMessage, 16, 1);
                RETURN -1;
            END;

            /*ensure encrypt is Y or N*/
            IF ( (@Encrypt NOT IN ('Y','N')) )
            BEGIN
                SET @ErrorMessage = @CRLF + '[ERROR] Invalid Parameter: @Encrypt must be one of the following: Y or N' + @CRLF + @CRLF;
                SET @ErrorMessage = @ErrorMessage + @Usage;
                RAISERROR(@ErrorMessage, 16, 1);
                RETURN -1;
            END;
        END;

        BEGIN /*start work*/
            IF ( (@BackupType = 'FULL') OR (@BackupType = 'DIFF') )
            BEGIN
                DECLARE @OriginalDBName NVARCHAR(255)
                     , @BackupsetPosition INT
                     , @ServerTDEThumbprint VARBINARY(32)
                     , @TDEStatus NVARCHAR(5)
                     , @OriginalDBTDEThumbprint VARBINARY(32)
                     , @OriginalDBCollation NVARCHAR(128)
                     , @OriginalDBLogicalData NVARCHAR(255)
                     , @OriginalDBLogicalLog NVARCHAR(255)
                     , @ServerDefaultDataPath NVARCHAR(255)
                     , @ServerDefaultDataDrive NVARCHAR(1)
                     , @ServerDefaultLogDrive NVARCHAR(1)
                     , @ServerDefaultLogPath NVARCHAR(255)
                     , @ServerXPCmdshellCurrent INT
                     , @ServerCollation NVARCHAR(128)
                     , @NeededDataSpace INT
                     , @NeededLogSpace INT
                     , @XPCmdshellCMD NVARCHAR(4000)
                     , @NewDBLogicalData NVARCHAR(255)
                     , @NewDBLogicalLog NVARCHAR(255);

                /*check for header temp table existence*/
                IF OBJECT_ID('tempdb..#Header') IS NOT NULL
                BEGIN
                    DROP TABLE #Header;
                END;

                CREATE TABLE #Header ( BackupName NVARCHAR(128)
                                     , BackupDescription NVARCHAR(255)
                                     , BackupType SMALLINT
                                     , ExpirationDate DATETIME
                                     , Compressed TINYINT
                                     , Position SMALLINT
                                     , DeviceType TINYINT
                                     , UserName NVARCHAR(128)
                                     , ServerName NVARCHAR(128)
                                     , DatabaseName NVARCHAR(128)
                                     , DatabaseVersion BIGINT
                                     , DatabaseCreationDate DATETIME
                                     , BackupSize NUMERIC(20,0)
                                     , FirstLSN NUMERIC(25,0)
                                     , LastLSN NUMERIC(25,0)
                                     , CheckpointLSN NUMERIC(25,0)
                                     , DatabaseBackupLSN NUMERIC(25,0)
                                     , BackupStartDate DATETIME
                                     , BackupFinishDate DATETIME
                                     , SortOrder SMALLINT
                                     , [CodePage] SMALLINT
                                     , UnicodeLocaleId BIGINT
                                     , UnicodeComparisonStyle BIGINT
                                     , CompatibilityLevel TINYINT
                                     , SoftwareVendorId BIGINT
                                     , SoftwareVersionMajor BIGINT
                                     , SoftwareVersionMinor BIGINT
                                     , SoftwareVersionBuild BIGINT
                                     , MachineName NVARCHAR(128)
                                     , Flags BIGINT
                                     , BindingID UNIQUEIDENTIFIER
                                     , RecoveryForkID UNIQUEIDENTIFIER
                                     , Collation NVARCHAR(128)
                                     , FamilyGUID UNIQUEIDENTIFIER
                                     , HasBulkLoggedData BIGINT
                                     , IsSnapshot BIGINT
                                     , IsReadOnly BIGINT
                                     , IsSingleUser BIGINT
                                     , HasBackupChecksums BIGINT
                                     , IsDamaged BIGINT
                                     , BegibsLogChain BIGINT
                                     , HasIncompleteMetaData BIGINT
                                     , IsForceOffline BIGINT
                                     , IsCopyOnly BIGINT
                                     , FirstRecoveryForkID UNIQUEIDENTIFIER
                                     , ForkPointLSN NUMERIC(25,0)
                                     , RecoveryModel NVARCHAR(128)
                                     , DifferentialBaseLSN NUMERIC(25,0)
                                     , DifferentialBaseGUID UNIQUEIDENTIFIER
                                     , BackupTypeDescription NVARCHAR(128)
                                     , BackupSetGUID UNIQUEIDENTIFIER
                                     , CompressedBackupSize BIGINT
                                     , Containment BIGINT
                                     ) ;

                /*check for filelist temp table existence*/
                IF OBJECT_ID('tempdb..#FileList') IS NOT NULL
                BEGIN
                    DROP TABLE #FileList;
                END;

                CREATE TABLE #FileList ( LogicalName NVARCHAR(128)
                                       , PhysicalName NVARCHAR(260)
                                       , Type CHAR(1)
                                       , FileGroupName NVARCHAR(128)
                                       , Size NUMERIC(20,0)
                                       , MaxSize NUMERIC(20,0)
                                       , FileId BIGINT
                                       , CreateLSN NUMERIC(25,0)
                                       , DropLSN NUMERIC(25,0)
                                       , UniqueId UNIQUEIDENTIFIER
                                       , ReadOnlyLSN NUMERIC(25,0)
                                       , ReadWriteLSN NUMERIC(25,0)
                                       , BackupSizeInBytes BIGINT
                                       , SourceBlockSize INT
                                       , FileGroupId INT
                                       , LogGroupGUID UNIQUEIDENTIFIER
                                       , DifferentialBaseLSN NUMERIC(25,0)
                                       , DifferentialBaseGUID UNIQUEIDENTIFIER
                                       , IsReadOnly BIT
                                       , IsPresent BIT
                                       , TDEThumbprint VARBINARY(32)
                                       ) ;

                /*get original database name*/
                INSERT INTO #Header
                  EXEC ( 'RESTORE HEADERONLY FROM DISK = ''' + @file + '''' );

                SELECT TOP 1 @OriginalDBName = DatabaseName
                     , @BackupsetPosition = Position
                  FROM #HEADER
                 ORDER BY BackupFinishDate DESC;

                /*get original database files*/
                INSERT INTO #FileList
                  EXEC ( 'RESTORE FILELISTONLY FROM DISK = ''' + @file + ''' WITH FILE = ' + @BackupsetPosition );

                BEGIN /*TDE check*/
                    /*verify TDE thumbprint matches server*/
                    SELECT TOP 1 @OriginalDBTDEThumbprint = TDEThumbprint
                      FROM #FileList
                     WHERE [Type] <> 'L';

                    IF (ISNULL(CONVERT(VARCHAR,@OriginalDBTDEThumbprint), '') = '')
                    BEGIN
                        /*no TDE on backup*/
                        SET NOCOUNT ON;
                    END
                    ELSE
                    BEGIN
                        /*TDE on backup, check if it matches server cert by looping through server certs*/
                        DECLARE TDECursor CURSOR FOR
                               SELECT thumbprint
                                 FROM master.sys.certificates
                                WHERE pvt_key_encryption_type = 'MK'
                          OPEN TDECursor
                         FETCH NEXT FROM TDECursor INTO @ServerTDEThumbprint
                         WHILE @@FETCH_STATUS = 0
                        BEGIN
                            IF ( @OriginalDBTDEThumbprint = @ServerTDEThumbprint )
                            BEGIN
                                SET @TDEStatus = 'TRUE';
                                BREAK;
                            END
                            ELSE
                            BEGIN
                                SET @TDEStatus = 'FALSE';
                                CONTINUE;
                            END;
                        END;
                         CLOSE TDECursor
                        DEALLOCATE TDECursor
                        IF ( @TDEStatus = 'FALSE' )
                        BEGIN
                            SET @ErrorMessage = @CRLF + '[ERROR] Backup Encrypted: TDE Thumbprint on the backup ( ' + CONVERT(VARCHAR,@OriginalDBTDEThumbprint) + ') does not match an existing TDE Cert on this server' + @CRLF + @CRLF;
                            SET @ErrorMessage = @ErrorMessage + @Usage;
                            RAISERROR(@ErrorMessage, 16, 1);
                            RETURN -1;
                        END;
                    END;
                END;

                BEGIN /*drive free space check*/
                    /*get default data and log paths*/
                       SET @ServerDefaultDataPath = CONVERT( NVARCHAR,SERVERPROPERTY('InstanceDefaultDataPath') );
                       SET @ServerDefaultLogPath = CONVERT( NVARCHAR,SERVERPROPERTY('InstanceDefaultLogPath') );
                    SELECT @ServerDefaultDataDrive = SUBSTRING(@ServerDefaultDataPath,1,1);
                    SELECT @ServerDefaultLogDrive = SUBSTRING(@ServerDefaultLogPath,1,1);

                    /*verify xp_cmdshell is enabled*/
                    SELECT @ServerXPCmdshellCurrent = CONVERT(INT, ISNULL(value, value_in_use))
                      FROM sys.configurations
                     WHERE name = 'xp_cmdshell';

			        IF @ServerXPCmdshellCurrent = 0
			        BEGIN
                        EXEC sp_configure 'show advanced options', 1;
                        RECONFIGURE WITH OVERRIDE;
                        EXEC sp_configure 'xp_cmdshell', 1;
                        RECONFIGURE WITH OVERRIDE;
                        EXEC sp_configure 'show advanced options', 0;
                        RECONFIGURE WITH OVERRIDE;
			        END;

                    /*find needed space for data and log paths*/
                    SELECT @NeededLogSpace = SUM(Size)
                      FROM #FileList
                     WHERE [Type] = 'L';

                    /*data will contain all mdfs and ndfs, so measuring type D (data) and type F (full text catalog)*/
                    SELECT @NeededDataSpace = SUM(Size)
                      FROM #FileList
                     WHERE [Type] = 'D'
                        OR [Type] = 'F';

                    /*use xp_cmdshell to call powershell to find amount of free space for each*/
                    DECLARE @DataCheckCommand NVARCHAR(4000)
                         , @LogCheckCommand NVARCHAR(4000)
                         , @DataFreeSpace FLOAT
                         , @LogFreeSpace FLOAT;

                    IF OBJECT_ID('tempdb..#CMDShellResults') IS NOT NULL
                    BEGIN
                        DROP TABLE #CMDShellResults;
                    END;

                    CREATE TABLE #CMDShellResults ( results NVARCHAR(255) );

                       SET @DataCheckCommand = 'powershell.exe (Get-Volume -DriveLetter ' + @ServerDefaultDataDrive + ').SizeRemaining /1024 /1024 /1024';

                    INSERT INTO #CMDShellResults
                      EXEC master.sys.xp_cmdshell @DataCheckCommand;

                    SELECT @DataFreeSpace = CONVERT(float,results)
                      FROM #CMDShellResults
                     WHERE results IS NOT NULL;

                    TRUNCATE TABLE #CMDShellResults;

                       SET @LogCheckCommand = 'powershell.exe (Get-Volume -DriveLetter ' + @ServerDefaultLogDrive + ').SizeRemaining /1024 /1024 /1024';

                    INSERT INTO #CMDShellResults
                      EXEC master.sys.xp_cmdshell @LogCheckCommand;

                    SELECT @LogFreeSpace = CONVERT(float,results)
                      FROM #CMDShellResults
                     WHERE results IS NOT NULL;

                     --(((Get-Volume -DriveLetter E).SizeRemaining) - ((Get-Volume -DriveLetter E).Size * .2))
                    TRUNCATE TABLE #CMDShellResults;

                    /*see if data and log are on the same drive*/
                    IF @ServerDefaultDataDrive = @ServerDefaultLogDrive
                    BEGIN
                        DECLARE @DatabaseTotalNeededSpace FLOAT

                    END
                    ELSE
                    BEGIN
                        select name from master.sys.databases
                    END
                END;

                /*check to see if the collations match*/
                   SET @ServerCollation = SERVERPROPERTY('Collation');
                SELECT @OriginalDBCollation = Collation
                  FROM #Header
                 WHERE Position = @BackupsetPosition

                IF ( @OriginalDBCollation <> @ServerCollation )
                BEGIN
                    PRINT '[NOTICE] Collation Mismatch : Collation on the database you are restoring is ' + @OriginalDBCollation + ', and the server''s collation is ' + @ServerCollation + '.';
                END;
    /*
                /*begin building restore command*/
                SET @cmd = 'RESTORE DATABASE [' + @DBName + '] FROM DISK = ''' + @File + ''' ' + @CRLF + 'WITH ' + @CRLF;
                SET @alter_cmd = '';

                /*check for temp table existence*/
                IF OBJECT_ID('tempdb..#NDFtable') IS NOT NULL
                BEGIN
                    DROP TABLE #NDFtable
                END

                /*create temp table*/
                CREATE TABLE #NDFtable ( FileNDF INT );

                /*check for temp table existence*/
                IF OBJECT_ID('tempdb..#NDFlist') IS NOT NULL
                BEGIN
                    DROP TABLE #NDFlist
                END

                /*create temp table*/
                CREATE TABLE #NDFlist ( NewPhysical NVARCHAR(128), NewLogical NVARCHAR(128), OldLogical NVARCHAR(128), N_db NVARCHAR(128), N_crlf NVARCHAR(2) );
    */
            END;
        END;
    END;
END;
