USE [util]
GO

/****** Object:  StoredProcedure [api_alias].[usp_restore_db_v2]    Script Date: 1/14/2016 5:20:52 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [api_alias].[usp_restore_db_v2]
       @db SYSNAME
     , @file NVARCHAR(128)
     , @bu_type NVARCHAR(4) = 'FULL'
     , @recovery NVARCHAR(5) = 'TRUE'
     , @replace NVARCHAR(5) = 'FALSE'
     , @dbcc NVARCHAR(1) = 'N'
     , @compatibility_level NVARCHAR(3) = NULL

WITH EXECUTE AS OWNER
AS

SET NOCOUNT ON;

DECLARE @cmd NVARCHAR(MAX)
     , @alter_cmd NVARCHAR(MAX)
     , @parameters NVARCHAR(MAX)
     , @qry_exec NVARCHAR(MAX)
     , @qry_cursor CURSOR

SET @parameters = '@file varchar(128)'

IF ((@bu_type = 'FULL') OR (@bu_type = 'DIFF'))
BEGIN
    DECLARE @FileType CHAR(1)
         , @LogicalName NVARCHAR(128)
         , @NewLogicalName NVARCHAR(128)
         , @PhysicalName NVARCHAR(128)
         , @NewPhysicalName NVARCHAR(128)
         , @PhysicalFileName NVARCHAR(128)
         , @crlf NVARCHAR(2)
         , @orig_db_name NVARCHAR(128)
         , @index_ndf NVARCHAR(128)
         , @data_ndf_par NVARCHAR(128)
         , @data_ndf_var INT
         , @data_ndf_file NVARCHAR(10)
    
       SET @crlf = CHAR(13) + CHAR(10);
    
    CREATE TABLE #header ( BackupName NVARCHAR(128)
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
    
    CREATE TABLE #filelist ( LogicalName NVARCHAR(128)
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
    INSERT INTO #header
    EXEC ('RESTORE headeronly FROM DISK = ''' + @file + '''')
    SET @orig_db_name = (SELECT TOP 1 (DatabaseName) FROM #HEADER ORDER BY BackupFinishDate DESC);

    /*get original database files*/
    INSERT INTO #filelist
        EXEC ('RESTORE filelistonly FROM DISK = ''' + @file + '''')
    
    /*begin building restore command*/
    SET @cmd = 'RESTORE DATABASE ' + QUOTENAME(@db) + ' FROM DISK = ''' + @file + ''' ' + @crlf + 'WITH ' + @crlf;
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
    
    DECLARE file_cursor CURSOR FOR
        SELECT Type, LogicalName, LTRIM(RTRIM(RIGHT(PhysicalName, CHARINDEX('\', REVERSE(PhysicalName)) - 1))) AS PhysicalFileName FROM #filelist;
    
    OPEN file_cursor;
    
    WHILE 1 = 1
    BEGIN
        FETCH NEXT FROM file_cursor INTO
            @FileType, @LogicalName, @PhysicalFileName
        IF @@FETCH_STATUS = -1 BREAK;
        
        /*mdf files (has specific code for xm)*/
        IF @FileType = 'D'
        BEGIN
            IF CHARINDEX('docs01', @PhysicalFileName) > 0
                SET @NewPhysicalName = 'E:\docs01\data\' + @db;
            ELSE
            BEGIN
                SET @NewPhysicalName = CAST(SERVERPROPERTY('instancedefaultdatapath') AS VARCHAR(128)) + @db
                SET @NewLogicalName = @db
            END
        END

        /*ldf file*/
        ELSE IF @FileType = 'L'
        BEGIN
            SET @NewPhysicalName = CAST(SERVERPROPERTY('instancedefaultlogpath') AS VARCHAR(128)) + @db + '_log.ldf'
            SET @NewLogicalName = @db + '_log'
            IF (@bu_type = 'FULL')
                    SET @alter_cmd = @alter_cmd + 'ALTER DATABASE ' + QUOTENAME(@db) + ' MODIFY FILE (NAME=''' + @LogicalName + ''', NEWNAME=''' + @NewLogicalName + ''');'
        
            SET @cmd = @cmd + 'MOVE ''' + @LogicalName + ''' TO ''' + @NewPhysicalName + ''', ' + @crlf;
        END

        /*full text index*/
        ELSE IF @FileType = 'F'
        BEGIN
            SET @NewPhysicalName = CAST(SERVERPROPERTY('instancedefaultdatapath') AS VARCHAR(128)) + @db
            SET @NewLogicalName = @db
        END

        IF PATINDEX('%.mdf', @PhysicalFileName) > 0
        BEGIN
            SET @NewPhysicalName = @NewPhysicalName + '.mdf'
            IF (@bu_type = 'FULL')
                    SET @alter_cmd = @alter_cmd + 'ALTER DATABASE ' + QUOTENAME(@db) + ' MODIFY FILE (NAME=''' + @LogicalName + ''', NEWNAME=''' + @NewLogicalName + ''');'
        
            SET @cmd = @cmd + 'MOVE ''' + @LogicalName + ''' TO ''' + @NewPhysicalName + ''', ' + @crlf;
        END
        
        -- NDF Normalizatiton
        ELSE IF PATINDEX('%.ndf', @PhysicalFileName) > 0
        BEGIN
            SET @index_ndf = @orig_db_name + '[_]%.ndf'
            IF (@PhysicalFileName LIKE @index_ndf)
            BEGIN
                SET @data_ndf_par = LEFT(@PhysicalFileName, charindex('.', @PhysicalFileName) - 1)
                SET @data_ndf_par = RIGHT(@data_ndf_par, charindex('_',REVERSE(@data_ndf_par)) - 1)
                IF (@data_ndf_par LIKE 'file%')
                BEGIN
                    SET @data_ndf_file = RIGHT(@data_ndf_par, LEN(@data_ndf_par) - 4)
                    IF NOT @data_ndf_file like '%[^0-9]%'
                    BEGIN
                        INSERT INTO #NDFtable (FileNDF) VALUES (CONVERT(INT, @data_ndf_file))
                    END
                END
                SET @NewPhysicalName = @NewPhysicalName + '_' + @data_ndf_par + '.ndf'
                SET @NewLogicalName = @NewLogicalName + '_' + @data_ndf_par

                IF (@bu_type = 'FULL')
                    SET @alter_cmd = @alter_cmd + 'ALTER DATABASE ' + QUOTENAME(@db) + ' MODIFY FILE (NAME=''' + @LogicalName + ''', NEWNAME=''' + @NewLogicalName + ''');'
        
                SET @cmd = @cmd + 'MOVE ''' + @LogicalName + ''' TO ''' + @NewPhysicalName + ''', ' + @crlf;
                
            END
            ELSE
            BEGIN
                SET @NewPhysicalName = @NewPhysicalName + '_file'
                SET @NewLogicalName = @NewLogicalName + '_file'    
                INSERT INTO #NDFlist VALUES (@NewPhysicalName, @NewLogicalName, @LogicalName, @db, @crlf)
            END

        END

    END
    CLOSE file_cursor;
    DEALLOCATE file_cursor;

    SET @data_ndf_var = (SELECT TOP 1 (FileNDf) FROM #NDFtable ORDER BY FileNDf DESC)
    SET @data_ndf_var = @data_ndf_var + 1
 
    DECLARE db_cursor CURSOR FOR  
        SELECT NewPhysical, NewLogical, OldLogical, N_db, N_crlf FROM #NDFlist

    OPEN db_cursor   
        FETCH NEXT FROM db_cursor INTO @NewPhysicalName, @NewLogicalName, @LogicalName, @db, @crlf

    WHILE @@FETCH_STATUS = 0    
    BEGIN  
       SET @NewPhysicalName = @NewPhysicalName + CONVERT(VARCHAR, @data_ndf_var) + '.ndf'
       SET @NewLogicalName = @NewLogicalName + CONVERT(VARCHAR, @data_ndf_var) 
       IF (@bu_type = 'FULL')
            SET @alter_cmd = @alter_cmd + 'ALTER DATABASE ' + QUOTENAME(@db) + ' MODIFY FILE (NAME=''' + @LogicalName + ''', NEWNAME=''' + @NewLogicalName + ''');'
        
       SET @cmd = @cmd + 'MOVE ''' + @LogicalName + ''' TO ''' + @NewPhysicalName + ''', ' + @crlf;
       SET @data_ndf_var = @data_ndf_var + 1
       FETCH NEXT FROM db_cursor INTO @NewPhysicalName, @NewLogicalName, @LogicalName, @db, @crlf
    END
    CLOSE db_cursor   
    DEALLOCATE db_cursor
    
    SET @cmd = @cmd + CASE WHEN @recovery = 'TRUE' THEN 'RECOVERY' ELSE 'NORECOVERY' END + CASE WHEN @replace = 'TRUE' THEN ', REPLACE' ELSE ' ' END;
    DROP TABLE #filelist;

END

ELSE IF (@bu_type = 'LOG')
    SET @cmd = 'RESTORE LOG ' + QUOTENAME(@db) + ' FROM  DISK = ''' + @file + ''' ' + CASE WHEN @recovery = 'TRUE' THEN 'WITH RECOVERY' ELSE 'WITH NORECOVERY' END;

EXEC sp_executesql @cmd, @parameters, @file = @file;
IF (@bu_type = 'FULL') AND (@recovery = 'TRUE') AND (@alter_cmd <> '')
    EXEC sp_executesql @alter_cmd;

IF OBJECT_ID('tempdb..#NDFtable') IS NOT NULL
BEGIN
    DROP TABLE #NDFtable
END
IF OBJECT_ID('tempdb..#NDFlist') IS NOT NULL
BEGIN    
    DROP TABLE #NDFlist
END

IF (@recovery = 'TRUE')
BEGIN
    CREATE TABLE #checksExec ( Query NVARCHAR(max) );

    /*FILEGROUP SIZE*/
    IF OBJECT_ID('tempdb..#fileGroupCheck') IS NOT NULL
    BEGIN
        DROP TABLE #fileGroupCheck
    END
    
    DECLARE @dynSQLFileGroup NVARCHAR(MAX), @GrowthQuery NVARCHAR(MAX)
    
    CREATE TABLE #fileGroupCheck ( [DBName] NVARCHAR(128), [FileGroupName] VARCHAR(300), [LogicalFileName] VARCHAR(300), [CurrentSizeInMB] INT, [NewSizeInMB] INT, [SpaceUsedMB] INT, [PercentUsed] DECIMAL(5,2) );
    SET @dynSQLFileGroup = '
    DECLARE @meg int = 128, @gig int = 131072
    USE [' + @db + '];
    INSERT INTO #fileGroupCheck
    SELECT DB_NAME( DB_ID() ) as [DBName], ISNULL ( sfg.name, ''LOG'' ) as [FileGroupName], sdf.name as [LogicalFileName], size/@meg AS [CurrentSizeInMB]
         , CASE
           WHEN size < @gig*2 THEN ((size + (@meg*256))*8)/1024
           WHEN size >= @gig*2 AND size < @gig*5 THEN ((size + (@meg*512))*8)/1024
           WHEN size >= @gig*5 AND size < @gig*10 THEN ((size + (@meg*768))*8)/1024
           WHEN size >= @gig*10 AND size < @gig*50 THEN ((size + (@meg*1024))*8)/1024
           WHEN size >= @gig*50 AND size < @gig*100 THEN ((size + (@meg*2048))*8)/1024
           WHEN size >= @gig*100 THEN ((size + (@meg*5120))*8)/1024
           END AS [NewSizeInMB]
         , (size/@meg)-((size/@meg) - ((FILEPROPERTY(sdf.name, ''SpaceUsed''))/@meg)) AS [SpaceUsedMB]
         , CAST(((size/128.0)-((size/128.0) - ((FILEPROPERTY(sdf.name, ''SpaceUsed''))/128.0)))/(size/128.0) AS decimal(5,2)) AS [PercentUsed]
      FROM [' + @db + '].sys.database_files sdf 
      LEFT JOIN [' + @db + '].sys.filegroups sfg
        ON sdf.data_space_id = sfg.data_space_id
     ORDER BY sdf.name'        
      EXEC ( @dynSQLFileGroup )
    
    SELECT @GrowthQuery = 'USE [master]; ALTER DATABASE [' + @db + '] MODIFY FILE ( NAME = ''' + [LogicalFileName] + ''', SIZE = ' + CAST( [NewSizeInMB] AS NVARCHAR(20) ) + 'MB )'
      FROM #fileGroupCheck 
     WHERE PercentUsed > .80
    
    EXEC( @GrowthQuery )
    
    IF OBJECT_ID('tempdb..#fileGroupCheck') IS NOT NULL
    BEGIN
        DROP TABLE #fileGroupCheck
    END
    
    
    /*AUTOGROWTH*/
    IF OBJECT_ID('tempdb..#databaseFiles') IS NOT NULL
    BEGIN
        DROP TABLE #databaseFiles
    END
    
    CREATE TABLE #databaseFiles (DBName NVARCHAR(200), LogicalName NVARCHAR(200), PhysicalName NVARCHAR(200), FileType INT, FileSize INT, IsPercentGrowth INT, MaxSize INT, Growth INT, NewGrowthAmount INT);
    INSERT INTO #databaseFiles
    SELECT sdb.[name], smf.[name], smf.[physical_name], smf.[type], smf.[size]/128, smf.[is_percent_growth], smf.[max_size], smf.[growth]
         , CASE
           WHEN size/128 < 2048 THEN 256
           WHEN size/128 >= 2048 AND size/128 < 5120 THEN 512
           WHEN size/128 >= 5120 AND size/128 < 10240 THEN 768
           WHEN size/128 >= 10240 AND size/128 < 51200 THEN 1024
           WHEN size/128 >= 51200 AND size/128 < 102400 THEN 2048
           WHEN size/128 >= 102400 THEN 5120
           END AS NewGrowthAmount
      FROM master.sys.master_files smf
     INNER JOIN master.sys.databases sdb
        ON smf.database_id = sdb.database_id
     WHERE sdb.name = @db
    
    /*MAX GROWTH UPPER LIMIT*/
    INSERT INTO #checksExec (Query) 
    SELECT 'ALTER DATABASE [' + DBName + '] MODIFY FILE ( NAME = ''' + LogicalName + ''', MAXSIZE = UNLIMITED )'
    FROM #databaseFiles
    WHERE MaxSize NOT IN ( 268435456, -1) AND DBName = @db
    
    /*GROWTH AMOUNT*/    
    INSERT INTO #checksExec (Query) 
    SELECT 'ALTER DATABASE [' + DBName + '] MODIFY FILE ( NAME = ''' + LogicalName + ''', FILEGROWTH = ' + CAST( NewGrowthAmount AS NVARCHAR ) + 'MB)'
      FROM #databaseFiles    
     WHERE IsPercentGrowth <> 1 AND DBName = @db
    
    DROP TABLE #databaseFiles
    
    /*RECOVERY MODEL*/
    INSERT INTO #checksExec (Query)
    SELECT 'USE [' + @db + ']; ALTER DATABASE [' + @db + '] SET RECOVERY FULL WITH NO_WAIT'
    
    /*AUTOCLOSE*/
    INSERT INTO #checksExec (Query)
    SELECT 'USE [' + @db + ']; ALTER DATABASE [' + @db + '] SET AUTO_CLOSE OFF WITH NO_WAIT'
    
    /*AUTOSHRINK*/
    INSERT INTO #checksExec (Query)
    SELECT 'USE [' + @db + ']; ALTER DATABASE [' + @db + '] SET AUTO_SHRINK OFF WITH NO_WAIT'
    
    /*AUTO CREATE STATS*/
    INSERT INTO #checksExec (Query)
    SELECT 'USE [' + @db + ']; ALTER DATABASE [' + @db + '] SET AUTO_CREATE_STATISTICS ON WITH NO_WAIT' 
    
    /*AUTO UPDATE STATS*/
    INSERT INTO #checksExec (Query)
    SELECT 'USE [' + @db + ']; ALTER DATABASE [' + @db + '] SET AUTO_UPDATE_STATISTICS ON WITH NO_WAIT'
    
    /*PAGE VERIFY*/
    INSERT INTO #checksExec (Query)
    SELECT 'USE [' + @db + ']; ALTER DATABASE [' + @db + '] SET PAGE_VERIFY CHECKSUM WITH NO_WAIT' 
    
    /*MULTI USER*/
    INSERT INTO #checksExec (Query)
    SELECT 'USE [' + @db + ']; ALTER DATABASE [' + @db + '] SET MULTI_USER WITH NO_WAIT'
    
    /*DB OWNER*/
    DECLARE @Domain sysname, @UserAcct sysname
    SELECT @Domain = DEFAULT_DOMAIN()
    SET @UserAcct = @Domain + N'\sql' + @Domain+ '_svc' 
    INSERT INTO #checksExec (Query)
    SELECT 'ALTER AUTHORIZATION ON DATABASE::[' + @db + '] to [' + @UserAcct + ']'
    
    /*COMPATIBILITY LEVEL*/
    IF (@compatibility_level IS NOT NULL)
    BEGIN
        INSERT INTO #checksExec (Query)
        SELECT 'USE [' + @db + ']; ALTER DATABASE [' + @db + '] SET COMPATIBILITY_LEVEL =' + @compatibility_level 
    END
    
    /*DBCC*/
    IF (@dbcc = 'Y')
    BEGIN
        INSERT INTO #checksExec (Query)
        SELECT 'DBCC CHECKDB ([' + @db + ']) WITH NO_INFOMSGS'
    END
    
    SET @qry_cursor = CURSOR FOR SELECT Query FROM #checksExec
    OPEN @qry_cursor
    FETCH NEXT FROM @qry_cursor INTO @qry_exec
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sp_executesql @qry_exec
        PRINT @qry_exec
        FETCH NEXT FROM @qry_cursor INTO @qry_exec
    END
    
    CLOSE @qry_cursor    
    DEALLOCATE @qry_cursor
    DROP TABLE #checksExec
END

GO
