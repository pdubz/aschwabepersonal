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
                     , @NewDBLogicalData NVARCHAR(255)
                     , @NewDBLogicalLog NVARCHAR(255)
                     , @XPCmdshellCMD NVARCHAR(4000);

 DROP TABLE #DriveLetterOutput;
 CREATE TABLE #DriveLetterOutput ( [Output] NVARCHAR(255) );

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
			    END;



SET @XPCmdshellCMD = 'powershell.exe -Command "(Get-Volume -DriveLetter ''' + @ServerDefaultDataDrive + ''').Size"';

INSERT INTO #DriveLetterOutput 
EXEC xp_cmdshell @XPCmdshellCMD

SELECT * 
  FROM #DriveLetterOutput
 WHERE [Output] IS NOT NULL
