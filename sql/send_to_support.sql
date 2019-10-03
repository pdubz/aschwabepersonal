USE [dba]
GO
/****** Object:  StoredProcedure [dbo].[usp_send_to_support]    Script Date: 10/8/2015 11:35:01 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


IF NOT EXISTS (SELECT name FROM dba.sys.procedures WHERE name = 'usp_restore_db')
BEGIN
	DECLARE @command nvarchar(max)
	SET @command = '
	CREATE PROCEDURE [dbo].[usp_restore_db]   @dbRestoreName NVARCHAR(255) = NULL
											, @dbRestoreFile NVARCHAR(1000) = NULL
											, @help CHAR(1) = ''N''
	AS
	BEGIN
		BEGIN TRY 
			/* create temp table to store results of restore file list */
			CREATE TABLE #RestoreFileList 
			( 
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
			  , TDEThumbprint varbinary(32)
			);

			/* insert into the temp table */
			INSERT INTO #RestoreFileList
				EXEC ( ''RESTORE FILELISTONLY FROM DISK = '''''' + @dbRestoreFile + '''''''');

			/* find data and log files */
			DECLARE @logicalData nvarchar(255)
				  , @logicalLog nvarchar(255);

			SELECT	@logicalData = LogicalName
			FROM	#RestoreFileList
			WHERE	[type] = ''D'';

			SELECT	@logicalLog = LogicalName
			FROM	#RestoreFileList
			WHERE	[type] = ''L'';
				   
			DROP TABLE #RestoreFileList

			/* restore temporary database from backup */
			exec ( ''restore database ['' + @dbRestoreName + '']
					from disk = '''''' + @dbRestoreFile + ''''''
					with file = 1
					, move '''''' + @logicalData + '''''' to ''''E:\data01\data\'' +  @dbRestoreName + ''_data.mdf'''' 
					, move '''''' + @logicalLog + '''''' to ''''E:\logs01\data\'' + @dbRestoreName + ''_log.ldf''''
					, recovery
					, stats = 10''
				) ;            
			BEGIN TRY         
				/* change logical filenames */
				EXEC ( ''ALTER DATABASE ['' + @dbRestoreName + ''] MODIFY FILE (NAME = ['' + @logicalData + ''], NEWNAME = ['' + @dbRestoreName + ''_data])'' )
				EXEC ( ''ALTER DATABASE ['' + @dbRestoreName + ''] MODIFY FILE (NAME = ['' + @logicalLog + ''], NEWNAME = ['' + @dbRestoreName + ''_log])'' )
			END TRY
			BEGIN CATCH
				PRINT ''Logical file names are already set correctly''
			END CATCH
		END TRY
		BEGIN CATCH
			THROW;
		END CATCH
	END'

	EXEC (@command)
END
GO

IF NOT EXISTS (SELECT name FROM dba.sys.procedures WHERE name = 'usp_send_to_support_customs')
BEGIN
	DECLARE @command nvarchar(max)
	SET @command = 'CREATE PROCEDURE [dbo].[usp_send_to_support_customs]
					AS
					BEGIN
						SET NOCOUNT ON
					END'
	EXEC (@command)
END
GO

IF NOT EXISTS (SELECT name FROM dba.sys.objects WHERE name = 'fn_CheckForNumbers')
BEGIN
	DECLARE @command nvarchar(max)
	SET @command = 'CREATE FUNCTION dbo.fn_CheckForNumbers (@code nvarchar(64), @startPos int)
					RETURNS int
					BEGIN
						DECLARE @num int
						IF(@startPos = LEN(@code))
						BEGIN
							SET @num = 1
						END
						ELSE IF ISNUMERIC(SUBSTRING(@code, @startPos, @startPos)) = 1
						BEGIN
							SET @num = 0 + dbo.checkForNumbers(@code, @startPos + 1)
						END

						RETURN @num
					END'
	EXEC (@command)
END
GO

IF NOT EXISTS (SELECT name FROM dba.sys.procedures WHERE name = 'usp_send_to_support')
BEGIN
	EXEC ('CREATE PROCEDURE dbo.usp_send_to_support AS BEGIN SET NOCOUNT ON END')
END
GO  

ALTER PROCEDURE [dbo].[usp_send_to_support]	
		@dbname			NVARCHAR(255) = NULL
	,   @code			NVARCHAR(64) = NULL
	,   @customs		CHAR(1) = 'N'
	,   @testBackup		CHAR(1) = 'N'
	,   @utilServerName	NVARCHAR(100) = NULL
	,   @retryLogID		INT = 0
	,   @help			CHAR(1) = 'N'
AS
BEGIN
	/* set no count on to ensure we don't spam the SSMS messages window */
	SET NOCOUNT ON;

	IF not exists ( SELECT *
					FROM dba.sys.tables
					WHERE name = 'send_to_support_log' )
		BEGIN
			--Drop Table dba.dbo.send_to_support_log
			/* create table for logging if it doesn't exist */
			CREATE TABLE [dba].dbo.send_to_support_log 
			( 
				  [LogID] INT IDENTITY(1,1) PRIMARY KEY
				, [UserName] NVARCHAR(200) NOT NULL
				, [StartUTCDateTime] DATETIME2 NOT NULL
				, [EndUTCDateTime] DATETIME2
				, [RunTimeInMins] nvarchar(200)
				, [IsRetry] BIT NOT NULL
				, [RetryLogID] INT NOT NULL
				, [ServerName] NVARCHAR(200) NOT NULL
				, [SourceDB] NVARCHAR(200) NOT NULL
				, [TempDBName] NVARCHAR(200) NOT NULL
				, [TempDBInAGLog] BIT NOT NULL
				, [SourceBackupFilePath] NVARCHAR(750)
				, [RestoreDB] BIT
				, [ChangeDBOwner] BIT
				, [BeforeCustomsFullBackupPath] NVARCHAR(750)
				, [CustomsSuccess] BIT
				, [BeforeDecryptFullBackupPath] NVARCHAR(750)
				, [DecryptDB] BIT
				, [FirstWait] BIT
				, [DecryptState] INT
				, [SecondWait] BIT
				, [DropEncryptionKey] BIT
				, [ThirdWait] BIT
				, [NewBackupLocation] NVARCHAR(750)
				, [OfflineDB] BIT
				, [DeleteBackupHistory] BIT
				, [DropDB] BIT
				, [UtilityServerName] NVARCHAR(200)
				, [RestoreTestDBName] NVARCHAR(200)
				, [RestoreTest] BIT
				, [OfflineTestDB] BIT
				, [DeleteTestDBBackupHistory] BIT
				, [DropTestDB] BIT
				, [Retried] BIT
				, [ZipStatus] BIT
				, [S3ZipFilePath] NVARCHAR(750)
				, [S3PreSignedURL] NVARCHAR(4000)
				, [DeleteB4CustomBackup] BIT
				, [DeleteB4DecryptBackup] BIT
				, [ShredZipFile] BIT
				, [ShredPreSignedURLTxtFile] BIT
				, [ShredDataFile] BIT
				, [ShredLogFile] BIT
				, [ShredLocalDecryptedFull] BIT 
				, [ShredTestDBDataFile] BIT
				, [ShredTestDBLogFile] BIT 
				, [ShredUtilDecryptedFull] BIT
				, [EmailAppGroup] BIT
				, [EmailDBAGroup] BIT
			);
		END
		--Check for function
		IF NOT EXISTS (	SELECT name 
						FROM dba.sys.objects 
						WHERE name = 'fn_CheckForNumbers')
		BEGIN
			DECLARE @command nvarchar(max)
			SET @command = 'CREATE FUNCTION dbo.fn_CheckForNumbers (@code nvarchar(64), @startPos int)
							RETURNS int
							BEGIN
								DECLARE @num int
								IF(@startPos = LEN(@code))
								BEGIN
									SET @num = 1
								END
								ELSE IF ISNUMERIC(SUBSTRING(@code, @startPos, @startPos)) = 1
								BEGIN
									SET @num = 0 + dbo.checkForNumbers(@code, @startPos + 1)
								END

								RETURN @num
							END'
			EXEC (@command)
		END

        /* declare variables for logging and sproc execution */
        DECLARE	  @tempDBName			NVARCHAR(255) = @dbName + '_TempRestore'
                , @dbRestoreFile		NVARCHAR(512)    
                , @backupLocation		NVARCHAR(512) = '\\' + @@SERVERNAME + '\backup\full'
				, @utilBackupLoc		NVARCHAR(512) = '\\' + @utilServerName + '\ImportExport'
                , @startUTCDateTime		DATETIME2	  = SYSUTCDATETIME()
                , @userName				NVARCHAR(255) = SUSER_NAME()
                , @logTableID			INT
                , @crlf					VARCHAR(2)	  = CHAR(13) + CHAR(10)
                , @usage				NVARCHAR(3000);

		SET @crlf = CHAR(13) + CHAR(10)
	
		SET @usage = @crlf	+ 'Send To Support Stored Procedure:' + @crlf
		SET @usage = @usage + '-------------------------------------------------------------------------------------------------------------------------' + @crlf
		SET @usage = @usage + 'This procedure will decrypt a database, optionally test the file on a utility server, ' + @crlf
		SET @usage = @usage + 'place it in a password protected zip file, upload to S3 for support, email the App and DBA Group,' + @crlf
		SET @usage = @usage + 'and shred the decrypted files.' + @crlf
		SET @usage = @usage + 'If the test of the backup fails, the script will automatically call the script one more time and test again.' + @crlf
		SET @usage = @usage + 'Unfortunately, due to the size of a database the shredding could take a long period of time.' + @crlf
		SET @usage = @usage + 'The customs send to support stored procedure will include product specific database processing.' + @crlf
		SET @usage = @usage + '-------------------------------------------------------------------------------------------------------------------------' + @crlf
		SET @usage = @usage + 'EXEC dba.dbo.usp_send_to_support ''database''s name to send'' ,''pass code for zip file'' [, <Customs>, <TestBackup>, ''utility server name'', <RetryLogID>]' + @crlf
		SET @usage = @usage + '    Required Parameters: ' + @crlf
		SET @usage = @usage + '			@dbName:			Should be the original name of the database.' + @crlf
		SET @usage = @usage + '			@code:				Use to password protect the zip file.  ' + @crlf
		SET @usage = @usage + '								Criteria:' + @crlf
		SET @usage = @usage + '								Must be at least 6 characters in length,' + @crlf
		SET @usage = @usage + '								Cannot be only numbers, ' + @crlf
		SET @usage = @usage + '								Cannot contain the name of the database.' + @crlf
		SET @usage = @usage + '    Optional parameters:' + @crlf
		SET @usage = @usage + '            @customs:			N [Default] - use for product specific processing before database is decrypted' + @crlf
		SET @usage = @usage + '								usp_send_to_support_customs sproc should be available in dba.dbo.'  + @crlf
		SET @usage = @usage + '								If this is the first time adding it to the server it will be blank.'  + @crlf
		SET @usage = @usage + '								This sproc is intended for adding in extra steps for processing databses that are app/support specific. '  + @crlf
		SET @usage = @usage + '								If this option is left as ''N'' then it will not call the sproc and will process the database with the generic requirements.'  + @crlf
		SET @usage = @usage + '            @testBackup:		N [Default] - use for testing the decrypted bak file on a utility server' + @crlf
		SET @usage = @usage + '								NOTE: IF @testBackup is a Y then @utilServerName is MANDATORY.'  + @crlf
		SET @usage = @usage + '			@utilServerName:	NULL [Default] - indicate the name of the utility server IF @testBackup is Y' + @crlf
		SET @usage = @usage + '            @retryLogID:		0 [Default] - DO NOT CHANGE. This will change automatically if the test of the backup fails.' + @crlf + @crlf
		SET @usage = @usage + 'EXEC dba.dbo.usp_send_to_support @help = ''Y'' (prints this help text and quits)' + @crlf
		SET @usage = @usage + '    Note: @help = ''Y'' parameter ALWAYS overrides any other parameters.' + @crlf + @crlf
		SET @usage = @usage + 'Explanation of the error table output' + @crlf
		SET @usage = @usage + '	   NULL - Skipped the particular segment of the code (Can be an expected result) ' + @crlf
		SET @usage = @usage + char(9) + '    0	- Did not skip the segment of code and did not complete execution' + @crlf
		SET @usage = @usage + char(9) + '    1	- task completed' + @crlf
		
		IF @help = 'N'
		BEGIN
			DECLARE @message nvarchar(200) = 'Doesn''t meet passcode guidelines!' + @crlf
			CREATE TABLE #validate (Name nvarchar(100), Diff int, Sound1 char(4), Sound2 char(4), CheckSound int)
			INSERT INTO #validate VALUES	('password', DIFFERENCE('password', @code), SOUNDEX('password'), SOUNDEX(@code), CHARINDEX(SOUNDEX('password'), SOUNDEX(@code)))
										,	(@dbname, DIFFERENCE(@dbname, @code), SOUNDEX(@dbname), SOUNDEX(@code), CHARINDEX(SOUNDEX(@dbname), SOUNDEX(@code)));
			
			IF	EXISTS (Select * From #validate Where Diff > 2 OR CheckSound = 1)
				OR LEN(@code) < 6
			BEGIN
				PRINT @message
				SET @help = 'Y'
			END
			ELSE IF EXISTS (Select Sound2 From #validate Where Sound2 = '0000')
			BEGIN
				DECLARE @result int
				EXEC @result = dba.dbo.fn_CheckForNumbers @code = @code, @startPos = 1
				IF @result = 1
				BEGIN
					PRINT @message
					SET @help = 'Y'
				END
			END

			DROP TABLE #validate
		END

		IF @help = 'Y'
			BEGIN
				PRINT @usage
				RETURN 0
			END
		ELSE
		BEGIN
			/* insert temp db name into AG_Log to ensure it does not get backed up */

			INSERT INTO dba.dbo.AG_Log ([DB]) VALUES (@tempDBName); 
               
			/* find if this is a retry */
			IF @retryLogID = 0
				BEGIN
					/* start a new tuple into log table */
					INSERT INTO [dba].dbo.send_to_support_log 
					( 
						[UserName]
						, [StartUTCDateTime]
						, [IsRetry]
						, [RetryLogID]
						, [ServerName]
						, [SourceDB]
						, [TempDBName]
						, [TempDBInAGLog]
						, [UtilityServerName]
					) 
					VALUES 
					( 
						@userName
						, @startUTCDateTime
						, 0
						, 0
						, @@SERVERNAME
						, @dbName
						, @tempDBName
						, 1
						, @utilServerName
					) ;
				END
			ELSE
				BEGIN
						/* start a new tuple into log table */
					INSERT INTO [dba].dbo.send_to_support_log 
					(
						[UserName]
						, [StartUTCDateTime]
						, [IsRetry]
						, [RetryLogID]
						, [ServerName]
						, [SourceDB]
						, [TempDBName]
						, [TempDBInAGLog]
						, [UtilityServerName]
					) 
					VALUES 
					( 
						  @userName
						, @startUTCDateTime
						, 1
						, @retryLogID
						, @@SERVERNAME
						, @dbName
						, @tempDBName
						, 1
						, @utilServerName
					);
					END


			/* retrieve unique ID for easy updating when a task completes */
			SELECT	@logTableID = LogID
			FROM	dba.dbo.send_to_support_log
			WHERE	[UserName] = @userName 
			AND		[StartUTCDateTime] = @startUTCDateTime;


			/* intial backup (encrypted) */
			EXEC util.dbo.usp_backup_db	@bu_type = 'full'
									,	@dbname = @dbName
									,	@num_files = 1
									,	@compression = 'N'
									,	@checksum = 'Y';

			/* find last full backup */
			SET @dbRestoreFile = (	SELECT TOP 1 
									REPLACE (	bf.physical_device_name, 'E:\backups01\full', @backupLocation )
									FROM		sys.databases d
									JOIN		msdb.dbo.backupset bs
									ON			bs.type = 'D'
									AND			d.name = bs.database_name
									JOIN		msdb.dbo.backupmediafamily bf 
									ON			bf.media_set_id = bs.media_set_id
									WHERE		d.name = @dbName
									AND			bf.physical_device_name like 'E:\%'
									ORDER BY	bs.backup_start_date desc );

			/* update log */                    
			UPDATE	dba.dbo.send_to_support_log
			SET		[SourceBackupFilePath] = @dbRestoreFile
			WHERE	@logTableID = LogID     
			
			/* restore db */
			EXEC dba.dbo.usp_restore_db @dbRestoreName = @tempDBName, @dbRestoreFile = @dbRestoreFile
			
			/* update log */                    
			UPDATE	dba.dbo.send_to_support_log
			SET		[RestoreDB] = 1
			WHERE	@logTableID = LogID                  
			 
			/* change dbowner */
			DECLARE	@Domain sysname = DEFAULT_DOMAIN()
			DECLARE	@UserAcct sysname = @Domain + N'\sql' + @Domain+ '_svc' 
			EXEC	( 'use [' + @tempDBName + ']; exec sp_changedbowner ''' + @UserAcct + '''' )
			       
			/* update log */                    
			UPDATE	dba.dbo.send_to_support_log
			SET		[ChangeDBOwner] = 1
			WHERE	@logTableID = LogID                  
                 
			IF @customs = 'Y'
			BEGIN
				/* take full backup of temp db */
				EXEC util.dbo.usp_backup_db @dbname = @tempDBName
													, @bu_type = 'full'
													, @comment = 'b4_customs'
													, @num_files = 1
													, @compression = 'N'
													, @checksum = 'Y'
               
				/* find last full backup */
				DECLARE @beforeCustomsBackupFilePath nvarchar(750)
					SET @beforeCustomsBackupFilePath = (	SELECT TOP 1 
															REPLACE (	bf.physical_device_name, 'E:\backups01\full', @backupLocation )
															FROM		sys.databases d
															JOIN		msdb.dbo.backupset bs
															ON			bs.type = 'D'
															AND			d.name = bs.database_name
															JOIN		msdb.dbo.backupmediafamily bf 
															ON			bf.media_set_id = bs.media_set_id
															WHERE		d.name = @tempDBName
															AND			bf.physical_device_name like 'E:\%'
															ORDER BY	bs.backup_start_date desc );

				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[BeforeCustomsFullBackupPath] = @beforeCustomsBackupFilePath
				WHERE	@logTableID = LogID

				/* run customs sproc */
				BEGIN TRY
					IF NOT EXISTS ( SELECT *
									FROM dba.sys.procedures
									WHERE name = 'usp_send_to_support_customs' ) 
					BEGIN
						/* update log */                    
						UPDATE	dba.dbo.send_to_support_log
						SET		[CustomsSuccess] = 0
						WHERE	@logTableID = LogID
					END
					ELSE
					BEGIN 
						BEGIN TRY
							/* run custom sproc */
							EXEC dba.dbo.usp_send_to_support_customs
								
							/* update log */                    
							UPDATE	dba.dbo.send_to_support_log
							SET		[CustomsSuccess] = 1
							WHERE	@logTableID = LogID
						END TRY
						BEGIN CATCH
							/* update log */                    
							UPDATE	dba.dbo.send_to_support_log
							SET		[CustomsSuccess] = 0
							WHERE	@logTableID = LogID
						END CATCH
					END     
				END TRY
				BEGIN CATCH
					/* update log */                    
					UPDATE	dba.dbo.send_to_support_log
					SET		[CustomsSuccess] = 0
					WHERE	@logTableID = LogID
				END CATCH
			END

			/* take full backup of temp db before decryption */
				EXEC util.dbo.usp_backup_db @dbname = @tempDBName
													, @bu_type = 'full'
													, @comment = 'b4_decrypt'
													, @num_files = 1
													, @compression = 'N'
													, @checksum = 'Y'

			/* find last full backup */
			DECLARE @beforeDecryptBackupFilePath nvarchar(750)
				SET @beforeDecryptBackupFilePath = (	SELECT TOP 1 
														REPLACE (	bf.physical_device_name, 'E:\backups01\full', @backupLocation )
														FROM		sys.databases d
														JOIN		msdb.dbo.backupset bs
														ON			bs.type = 'D'
														AND			d.name = bs.database_name
														JOIN		msdb.dbo.backupmediafamily bf 
														ON			bf.media_set_id = bs.media_set_id
														WHERE		d.name = @tempDBName
														AND			bf.physical_device_name like 'E:\%'
														ORDER BY	bs.backup_start_date desc );

			/* update log */                  
			UPDATE	dba.dbo.send_to_support_log
			SET		[BeforeDecryptFullBackupPath] = @beforeDecryptBackupFilePath
			WHERE	@logTableID = LogID

			BEGIN TRY
				/* decrypt database */
				EXEC ( 'ALTER DATABASE [' + @tempDBName + '] SET ENCRYPTION OFF;' )

				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[DecryptDB] = 1
				WHERE	@logTableID = LogID
			END TRY
			BEGIN CATCH
				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[DecryptDB] = 0
				WHERE	@logTableID = LogID;
			
				EXEC ('DROP DATABASE [' + @tempDBName +']');
				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[DropDB] = 1
				WHERE	@logTableID = LogID ;

				DELETE FROM dba.dbo.AG_Log 
				WHERE DB = @tempDBName;

				--If it can't set encryption off, I want to kill the process and be notified
				THROW;                   
			END CATCH

			/* I was advised to do a WAITFOR DELAY here instead of checkpoint as previously advised */
			WAITFOR DELAY '00:00:30'

			/* update log */                  
			UPDATE	dba.dbo.send_to_support_log
			SET		[FirstWait] = 1
			WHERE	@logTableID = LogID;

			DECLARE @test int
			SET		@test = 3

			/* update log */                    
			UPDATE	dba.dbo.send_to_support_log
			SET		[DecryptState] = @test
			WHERE	@logTableID = LogID;

			WHILE ( @test <> 1 )
			BEGIN 
				SET @test = (	SELECT		encryption_state
								FROM		sys.dm_database_encryption_keys DEK
								INNER JOIN	sys.databases d 
								ON			DEK.database_id = d.database_id 
								WHERE		d.name = @tempDBName )
			END

			/* update log */                    
			UPDATE	dba.dbo.send_to_support_log
			SET		[DecryptState] = @test
			WHERE	@logTableID = LogID;

			/* I was advised to do a WAITFOR DELAY here instead of checkpoint as previously advised */
			WAITFOR DELAY '00:00:30';

			/* update log */                    
			UPDATE	dba.dbo.send_to_support_log
			SET		SecondWait = 1
			WHERE	@logTableID = LogID;
               
			BEGIN TRY
				/* drop encryption key */ 
				EXEC ( 'USE [' + @tempDBName + ']; DROP DATABASE ENCRYPTION KEY' )
                            
				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[DropEncryptionKey] = 1
				WHERE	@logTableID = LogID;
			END TRY
			BEGIN CATCH
				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[DropEncryptionKey] = 0
				WHERE	@logTableID = LogID;

				EXEC ('DROP DATABASE [' + @tempDBName +']');
				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[DropDB] = 1
				WHERE	@logTableID = LogID ;

				DELETE FROM dba.dbo.AG_Log 
				WHERE DB = @tempDBName;

				--If it can't drop the encryption key, I want to kill the process and be notified
				THROW;
			END CATCH

			/* I was advised to do a WAITFOR DELAY here instead of checkpoint as previously advised */
			WAITFOR DELAY '00:00:30';

			/* update log */                    
			UPDATE	dba.dbo.send_to_support_log
			SET		[ThirdWait] = 1
			WHERE	@logTableID = LogID;

			EXEC util.dbo.usp_backup_db	@dbname = @tempDBName
									  , @bu_type = 'full'
									  , @comment = 'after_decrypt'
									  , @num_files = 1
									  , @compression = 'N'
									  , @checksum = 'Y'
									  , @mirror_path = @utilBackupLoc
	
			/* find last full backup */
			DECLARE @afterDecryptBackupFilePath nvarchar(750)
			SET		@afterDecryptBackupFilePath = ( SELECT TOP 1 
													REPLACE( bf.physical_device_name, 'E:\backups01\full', @backupLocation )
													FROM	 sys.databases d
													JOIN	 msdb.dbo.backupset bs
													ON		 bs.type = 'D'
													AND		 d.name = bs.database_name
													JOIN	 msdb.dbo.backupmediafamily bf 
													ON		 bf.media_set_id = bs.media_set_id
													WHERE	 d.name = @tempDBName
													AND		 bf.physical_device_name like 'E:\%'
													ORDER BY bs.backup_start_date desc );			
			DECLARE @utilFullBakLoc nvarchar(750) 
			SELECT @utilFullBakLoc = REPLACE(@afterDecryptBackupFilePath, @backupLocation, @utilBackupLoc)
			
			--New backup location
			IF @testBackup = 'Y'
			BEGIN
				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[NewBackupLocation] = @utilFullBakLoc
				WHERE	@logTableID = LogID;
			END
			ELSE
			BEGIN
				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[NewBackupLocation] = @afterDecryptBackupFilePath
				WHERE	@logTableID = LogID;
			END
			
			BEGIN TRY		
				--Offline database
				EXEC   ('ALTER DATABASE [' + @tempDBName + ']
							SET OFFLINE WITH ROLLBACK IMMEDIATE');
			
				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[OfflineDB] = 1
				WHERE	@logTableID = LogID;
			END TRY
			BEGIN CATCH
				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[OfflineDB] = 0
				WHERE	@logTableID = LogID;

				SELECT	ERROR_NUMBER()		AS ErrorNumber
					,	ERROR_SEVERITY()	AS ErrorSeverity
					,	ERROR_STATE()		AS ErrorState
					,	ERROR_PROCEDURE()	AS ErrorProcedure
					,	ERROR_MESSAGE()		AS ErrorMessage;
			END CATCH

			BEGIN TRY
				EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = @tempDBName;
				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[DeleteBackupHistory] = 1
				WHERE	@logTableID = LogID;
			END TRY
			BEGIN CATCH
				UPDATE	dba.dbo.send_to_support_log
				SET		[DeleteBackupHistory] = 0
				WHERE	@logTableID = LogID;
			END CATCH

			EXEC ('DROP DATABASE [' + @tempDBName +']');
			/* update log */                    
			UPDATE	dba.dbo.send_to_support_log
			SET		[DropDB] = 1
			WHERE	@logTableID = LogID ;
			 
			DECLARE @xp_cmdshell_default int
					,  @cmd nvarchar(3000)

			SELECT	@xp_cmdshell_default = CONVERT(INT, ISNULL(value, value_in_use))
			FROM	sys.configurations
			WHERE	name = N'xp_cmdshell';

			IF @xp_cmdshell_default = 0
			BEGIN
				EXEC sp_configure 'show advanced options', 1;
				RECONFIGURE WITH OVERRIDE;
				EXEC sp_configure 'xp_cmdshell', 1;
				RECONFIGURE;
			END

			--Test to ensure backup can be restored successfully
			IF @testBackup = 'Y'
			BEGIN
				SET @cmd = 'powershell.exe -Command "& C:\scripts\Maintenance\SendToSupport\utilTest.ps1 -utilServerName '+ @utilServerName +' -primaryServerName '+ @@SERVERNAME +' -logID '+ CONVERT(nvarchar(10),@logTableID) +' -tmpDBName '+ @tempDBName +'"'
				print @cmd
				EXEC xp_cmdshell @cmd
			END
			ELSE
			BEGIN
				--Set the log to 1 so the biconditional statement will correctly execute                 
				UPDATE	dba.dbo.send_to_support_log
				SET		[RestoreTest] = 1
				WHERE	@logTableID = LogID 
			END

			--If restore test passed
			IF(	SELECT	RestoreTest
				FROM	dba.dbo.send_to_support_log
				WHERE	LogID = @logTableID ) = 1
			BEGIN
				--call zip to upload
				SET @cmd = 'powershell.exe -Command "& C:\scripts\Maintenance\SendToSupport\ZipUpload4Support.ps1 -fullBakFilePath ' + @afterDecryptBackupFilePath + ' -logTableID ' + CONVERT(nvarchar(10),@logTableID) + ' -code ' + @code + ' -primaryServerName '+ @@SERVERNAME +'"'

				EXEC xp_cmdshell @cmd

				BEGIN TRY
					--setup and send app group email
					DECLARE	@emailbody		nvarchar(2000)
							, @emailSubject	nvarchar(255)
							, @S3Path		nvarchar(2000)
							, @S3Url		nvarchar(2000)
							, @appOperator	nvarchar(128)

					SELECT	@appOperator = name 
					FROM	msdb.dbo.sysoperators 
					WHERE	name = 'App Group'
				
					SELECT	@S3Path = S3ZipFilePath
						,	@S3Url	= S3PreSignedURL
					FROM	dba.dbo.send_to_support_log
					WHERE	LogID = @logTableID

					SET @emailBody =	'Backup of ' + @dbName + ' is complete. ' + @crlf +
										'File Location:  ' + @S3Path + @crlf +
										'Direct download link: ' + @S3Url + @crlf
					SET @emailSubject = 'Backup of ' + @dbName + ' is complete'
				
					IF @appOperator IS NOT NULL
					BEGIN
						EXEC msdb.dbo.sp_notify_operator  @profile_name = 'SQLMail Profile'
														, @name = @appOperator
														, @subject = @emailSubject
														, @body = @emailBody
					END
				
					EXEC msdb.dbo.sp_notify_operator  @profile_name = 'SQLMail Profile'
													, @name = 'DBA Group'
													, @subject = @emailSubject
													, @body = @emailBody
				
					/* update log */                    
					UPDATE	dba.dbo.send_to_support_log
					SET		[EmailAppGroup] = 1
					WHERE	@logTableID = LogID

				END TRY
				BEGIN CATCH
					/* update log */                    
					UPDATE	dba.dbo.send_to_support_log
					SET		[EmailAppGroup] = 0
					WHERE	@logTableID = LogID

					SELECT	ERROR_NUMBER()		AS ErrorNumber
							,	ERROR_SEVERITY()	AS ErrorSeverity
							,	ERROR_STATE()		AS ErrorState
							,	ERROR_PROCEDURE()	AS ErrorProcedure
							,	ERROR_MESSAGE()		AS ErrorMessage;
				END CATCH
			END
			ELSE
			BEGIN --If restore test fails and isn't already on a retry execute again
				IF (SELECT	IsRetry
					FROM	dba.dbo.send_to_support_log
					WHERE	LogID = @logTableID ) = 0
				BEGIN
					EXEC dba.dbo.usp_send_to_support	  @dbname = @tempDBName
														, @customs = @customs
														, @retryLogID = @logTableID
														, @utilServerName = @utilServerName
				END
			END

			DECLARE @utilDBName nvarchar(100)
			SELECT	@utilDBName = RestoreTestDBName 
			FROM	dba.dbo.send_to_support_log
			Where	LogID = @logTableID

			DECLARE @dataFilePath	nvarchar(1000) = 'E:\data01\data\' + @tempDBName + '_data.mdf'
				,	@logFilePath	nvarchar(1000) = 'E:\logs01\data\' + @tempDBName + '_log.ldf'
				,	@utilDFilePath	nvarchar(1000) = '\\' + @utilServerName + '\Data\' + @utilDBName + '_data.mdf'
				,	@utilLFilePath	nvarchar(1000) = '\\' + @utilServerName + '\Logs\' + @utilDBName + '_log.ldf'

			--Begin shredding files
			SET @cmd = 'powershell.exe -Command "& C:\scripts\Maintenance\SendToSupport\shredFiles.ps1 -fullFilePaths "' + @dataFilePath + '", "'+ @logFilePath +'", "'+ @afterDecryptBackupFilePath +'"'
			IF @testBackup = 'Y'
			BEGIN
				SET @cmd = @cmd + ', "'+ @utilFullBakLoc +'", "'+ @utilDFilePath +'", "'+ @utilLFilePath +'"'
			END

			SET @cmd = @cmd + ' -logID ' + CONVERT(nvarchar(10),@logTableID) + '"'
			Print @cmd
			EXEC xp_cmdshell @cmd

			--Delete empty folder
			BEGIN TRY
				SET @cmd = 'RMDIR /Q \\' + @utilServerName + '\ImportExport\' + @tempDBName
				EXEC xp_cmdshell @cmd
			END TRY
			BEGIN CATCH
				SELECT	ERROR_MESSAGE()	AS ErrorMessage;
			END CATCH

			IF @xp_cmdshell_default = 0
			BEGIN
				EXEC sp_configure 'xp_cmdshell', 0;
				RECONFIGURE;
			END

			DECLARE @endUTCDateTime	DATETIME2	  = SYSUTCDATETIME()
			DECLARE @runTime INT = DATEDIFF(minute, @startUTCDateTime, @endUTCDateTime)
			
			/* update log */                    
			UPDATE	dba.dbo.send_to_support_log
			SET		[EndUTCDateTime] = @endUTCDateTime, [RunTimeInMins] = @runTime
			WHERE	@logTableID = LogID

			BEGIN TRY
				--setup/send dba group email
				DECLARE	  @table	nvarchar(MAX)
						, @eHeader  nvarchar(75)  = N'<h3>Send To Support</h3><p>Results from SPROC execution:</p>'
						, @eSubject nvarchar(75)  = N'Send To Support Execution Alert'
						, @logQuery nvarchar(75)  = N'SELECT * FROM dba.dbo.send_to_support_log WHERE LogID = ' + CAST(@logTableID AS nvarchar(10))
						, @eMessage nvarchar(MAX)
						, @dbaGroup nvarchar(MAX) = (SELECT email_address  FROM msdb.dbo.sysoperators WHERE name = 'DBA Group' )
						, @appGroup nvarchar(MAX) = (SELECT email_address  FROM msdb.dbo.sysoperators WHERE name = 'App Group' );

				EXEC dba.dbo.QueryToHTMLTable @html = @table OUTPUT,  @query = @logQuery
				SET @eMessage = CONCAT (@eHeader, @table)

				EXEC msdb.dbo.sp_send_dbmail @profile_name = 'SQLMail Profile'
											,@recipients = @dbaGroup
											,@subject = @eSubject
											,@importance = 'High'
											,@body = @eMessage
											,@body_format = 'HTML'
											,@exclude_query_output = 1

				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[EmailDBAGroup] = 1
				WHERE	@logTableID = LogID
			END TRY
			BEGIN CATCH
				/* update log */                    
				UPDATE	dba.dbo.send_to_support_log
				SET		[EmailDBAGroup] = 0
				WHERE	@logTableID = LogID

				SELECT	ERROR_NUMBER()		AS ErrorNumber
						,	ERROR_SEVERITY()	AS ErrorSeverity
						,	ERROR_STATE()		AS ErrorState
						,	ERROR_PROCEDURE()	AS ErrorProcedure
						,	ERROR_MESSAGE()		AS ErrorMessage;
			END CATCH

			DELETE FROM dba.dbo.AG_Log 
			WHERE DB = @tempDBName; 
		END
END