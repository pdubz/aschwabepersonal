/*
RUNNING DAILY CHECKS ON A SERVER GROUP:
	Make sure to have Merge Results set to False for Multiserver Results
	Tools -> Options -> Query Results -> SQL Server -> Multiserver Results

IF YOU DO NOT WANT TO CHECK BACKUP FILES CHANGE @BACKUPFILESCHECK TO 'N'
IF YOU DO NOT WANT TO CHECK SNAPSHOTS CHANGE @SNAPSHOTSCHECK TO 'N'
*/

SET NOCOUNT ON;
DECLARE	@backupFilesCheck CHAR(1) = 'N',
	@snapshotsCheck CHAR(1) = 'N';

IF OBJECT_ID('tempdb..#ServerNamesTable') IS NOT NULL
	BEGIN
		DROP TABLE #ServerNamesTable;
	END;

CREATE TABLE #ServerNamesTable
	(
		ServerName NVARCHAR(200)
	);

IF SERVERPROPERTY('IsHadrEnabled') = 1
	BEGIN
		INSERT	INTO #ServerNamesTable
		SELECT LOWER(primary_replica)
		FROM	master.sys.dm_hadr_availability_group_states;
	END;
ELSE
	BEGIN
		INSERT	INTO #ServerNamesTable
		SELECT LOWER(@@SERVERNAME);
	END;

DECLARE	@ServerXPCmdshellCurrent INT;
SELECT	@ServerXPCmdshellCurrent = CONVERT(INT, ISNULL(value, value_in_use))
FROM	sys.configurations
WHERE	name = N'xp_cmdshell';

IF @ServerXPCmdshellCurrent = 0
	BEGIN
		EXEC sys.sp_configure 'show advanced options', 1;
		RECONFIGURE WITH OVERRIDE;
		EXEC sys.sp_configure 'xp_cmdshell', 1;
		RECONFIGURE WITH OVERRIDE;
		EXEC sys.sp_configure 'show advanced options', 0;
		RECONFIGURE WITH OVERRIDE;
	END;
/*
--------------------------
|Database Settings Checks|
--------------------------
AG Properties Checks
Percent Growth
Auto Growth Amount
Max Growth Size
Recovery Model
Auto Close
Auto Shrink
Auto Create Stats
Auto Update Stats
Auto Update Stats Async
Page Verify
Compatibility Level
Multi User
DB Owner
Collation Check
Database State
Physical File Locations
System DB Sizes
*/
BEGIN /*DATABASE SETTINGS CHECKS*/

	EXEC CODBAProcedures.Checks.AGProperties

			
BEGIN /* Cluster Health Check */

		SET NOCOUNT ON

		IF OBJECT_ID('tempdb..#ClusterOutput') IS NOT NULL
			DROP TABLE #ClusterOutput

		CREATE TABLE #ClusterOutput (clusterdata NVARCHAR(max))

		DECLARE @sqlclu VARCHAR(200)

		SET @sqlclu = 'powershell.exe -Command "& Get-ClusterResource | Get-ClusterOwnerNode"'

		INSERT INTO #ClusterOutput
		EXEC xp_cmdshell @sqlclu

		DELETE
		FROM #ClusterOutput
		WHERE (
				clusterdata LIKE '------%'
				OR clusterdata IS NULL
				OR clusterdata LIKE 'ClusterObject%'
				)

		UPDATE #ClusterOutput
		SET clusterdata = REPLACE(clusterdata, 'Cluster Name', 'ClusterName')
		WHERE clusterdata LIKE '%cluster%'

		IF OBJECT_ID('tempdb..#clusterdetails') IS NOT NULL
			DROP TABLE #clusterdetails

		CREATE TABLE #ClusterDetails (
			[Cluster Object] NVARCHAR(100)
			, [Owner Nodes] NVARCHAR(500)
			)

		INSERT INTO #ClusterDetails (
			[Cluster Object]
			, [Owner Nodes]
			)
		SELECT rtrim(ltrim(SUBSTRING(clusterdata, 0, CHARINDEX(' ', clusterdata)))) AS [Cluster Object]
			, rtrim(ltrim(SUBSTRING(clusterdata, CHARINDEX(' ', clusterdata), LEN(clusterdata)))) AS [Owner Nodes]
		FROM #ClusterOutput

		ALTER TABLE #ClusterDetails ADD [Advisory Note] NVARCHAR(500)

		UPDATE #ClusterDetails
		SET [Advisory Note] = 'The primary node and the active fail-over secondary (order of nodes does not matter)'
		WHERE [Cluster Object] = 'AG1'

		UPDATE #ClusterDetails
		SET [Advisory Note] = 'One entry per node that matches the AG1 IP address for that node, owned by that node and that node only'
		WHERE [Cluster Object] LIKE 'AG1_%'

		UPDATE #ClusterDetails
		SET [Advisory Note] = 'Owned by all nodes in the cluster'
		WHERE [Cluster Object] IN (
				'ClusterName'
				, 'ClusterWitnessDisk'
				)

		UPDATE #ClusterDetails
		SET [Advisory Note] = 'Owned by all nodes in the cluster'
		WHERE [Cluster Object] LIKE '%-lsnr'

		UPDATE #ClusterDetails
		SET [Advisory Note] = 'One entry per node, owned by that node and that node only'
		WHERE [Cluster Object] LIKE 'resource-%'

		SELECT *
		FROM #ClusterDetails
END

	EXEC CODBAProcedures.Checks.AutoGrowth
	EXEC CODBAProcedures.Checks.RecoveryModel
	EXEC CODBAProcedures.Checks.AutoClose
	EXEC CODBAProcedures.Checks.AutoShrink

			BEGIN /*AUTO CREATE STATS CHECK*/
				BEGIN TRY
					SELECT	'***AUTO CREATE STATS CHECK***' [Database Name],
							'--All databases should have Auto Create Stats enabled. Run these commands to enable Auto Create Stats.' [Command(s) to change Auto Stats]
					UNION
					SELECT	name AS [Database Name],
							'USE [' + name + ']; ALTER DATABASE [' + name
							+ '] SET AUTO_CREATE_STATISTICS ON WITH NO_WAIT' AS [Command(s) to change Auto Stats]
					FROM	master.sys.databases
					WHERE	is_auto_create_stats_on = 0;
				END TRY
				BEGIN CATCH
					SELECT	'***AUTO CREATE STATS CHECK***' [Database Name],
							'--All databases should have Auto Create Stats enabled. Run these commands to enable Auto Create Stats.' [Command(s) to change Auto Stats]
					UNION
					SELECT	'******ERROR******' AS DatabaseName,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;

			END;

			BEGIN /*AUTO UPDATE STATS CHECK*/
				BEGIN TRY
					SELECT	'***AUTO UPDATE STATS CHECK***' [Database Name],
							'--All databases should have Auto Update Stats enabled. Run these commands to enable Auto Update Stats.' [Command(s) to change Auto Stats]
					UNION
					SELECT	name AS [Database Name],
							'USE [' + name + ']; ALTER DATABASE [' + name
							+ '] SET AUTO_UPDATE_STATISTICS ON WITH NO_WAIT' AS [Command(s) to change Auto Stats]
					FROM	master.sys.databases
					WHERE	is_auto_update_stats_on = 0;
				END TRY
				BEGIN CATCH
					SELECT	'***AUTO UPDATE STATS CHECK***' [Database Name],
							'--All databases should have Auto Update Stats enabled. Run these commands to enable Auto Update Stats.' [Command(s) to change Auto Stats]
					UNION
					SELECT	'******ERROR******' AS DatabaseName,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;

			END;

			BEGIN /*PAGE VERIFY CHECK*/
				BEGIN TRY
					SELECT	'***PAGE VERIFY CHECK***' DatabaseName,
							'***********' PageVerify,
							'--All databases need to have their Page Verify option set to CHECKSUM. Run these commands to fix databases out of compliance.' [Command(s) to change Page Verify]
					UNION
					SELECT	name AS DatabaseName,
							page_verify_option_desc AS PageVerify,
							'USE [' + name + ']; ALTER DATABASE [' + name
							+ '] SET PAGE_VERIFY CHECKSUM WITH NO_WAIT' AS [Command(s) to change Page Verify]
					FROM	master.sys.databases
					WHERE	page_verify_option <> 2;
				END TRY
				BEGIN CATCH
					SELECT	'***PAGE VERIFY CHECK***' DatabaseName,
							'***********' PageVerify,
							'--All databases need to have their Page Verify option set to CHECKSUM. Run these commands to fix databases out of compliance.' [Command(s) to change Page Verify]
					UNION
					SELECT	'******ERROR******' AS DatabaseName,
							'***********' PageVerify,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;

			END;

			BEGIN /*COMPATIBILITY LEVEL CHECK*/
				BEGIN TRY
					SELECT	'***COMPATIBILITY LEVEL CHECK***' DatabaseName,
							NULL CompatibilityLevel,
							'--Most databases should be set to 110 (SQL 2012). There is the possibility that your app does not support that compatibility level, so be sure you know if it does or not before changing to level 110.' [Command(s) to change Compatibility Level]
					UNION
					SELECT	name AS DatabaseName,
							compatibility_level AS CompatibilityLevel,
							'USE [' + name + ']; ALTER DATABASE [' + name
							+ '] SET COMPATIBILITY_LEVEL = 110' AS [Command(s) to change Compatibility Level]
					FROM	master.sys.databases
					WHERE	compatibility_level < 110;
				END TRY
				BEGIN CATCH
					SELECT	'***COMPATIBILITY LEVEL CHECK***' DatabaseName,
							NULL CompatibilityLevel,
							'--Most databases should be set to 110 (SQL 2012). There is the possibility that your app does not support that compatibility level, so be sure you know if it does or not before changing to level 110.' [Command(s) to change Compatibility Level]
					UNION
					SELECT	'******ERROR******' AS DatabaseName,
							NULL CompatibilityLevel,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;
			END;

			BEGIN /*MULTI USER CHECK*/
				BEGIN TRY
					SELECT	'***MULTI USER CHECK***' DatabaseName,
							'***********' UserAccess,
							'--All databases need to be in Multi User State. If a database is not, run these commands to set them to multi user.' [Command(s) to change Multi-User State]
					UNION
					SELECT	name AS DatabaseName,
							user_access_desc AS UserAccess,
							'USE [' + name + ']; ALTER DATABASE [' + name
							+ '] SET MULTI_USER WITH NO_WAIT' AS [Command(s) to change Multi-User State]
					FROM	master.sys.databases
					WHERE	user_access <> 0;
				END TRY
				BEGIN CATCH
					SELECT	'***MULTI USER CHECK***' DatabaseName,
							'***********' UserAccess,
							'--All databases need to be in Multi User State. If a database is not, run these commands to set them to multi user.' [Command(s) to change Multi-User State]
					UNION
					SELECT	'******ERROR******' AS DatabaseName,
							'***********' UserAccess,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;
			END;

			BEGIN /*DB OWNER CHECK*/
				BEGIN TRY
					DECLARE	@Domain sysname,
						@UserAcct sysname;
					SELECT	@Domain = DEFAULT_DOMAIN();
					SET @UserAcct = @Domain + N'\sql' + @Domain + '_svc';

					SELECT	'***DO NOT CHANGE DB OWNER DURING NORMAL DAYS***' DatabaseName,
							'***********' CurrentDatabaseOwner,
							'DO NOT MAKE ANY CHANGES NOW AS PRESCRIBED BELOW. PLEASE MAKE NOTE AND RUN THESE *ONLY* DURING MAINTENANCE WINDOW' [Command(s) to change Database Owner]
					UNION ALL

					SELECT	'***DB OWNER CHECK***' DatabaseName,
							'***********' CurrentDatabaseOwner,
							'All databases need to be owned by ' + @UserAcct
							+ ' to ensure correct operation and permissions.' [Command(s) to change Database Owner]
					UNION ALL				
					
					SELECT	name AS DatabaseName,
							SUSER_SNAME(owner_sid) AS CurrentDatabaseOwner,
							'--ALTER AUTHORIZATION ON DATABASE::[' + name
							+ '] to [' + @UserAcct + ']' AS [Command(s) to change Database Owner]
					FROM	master.sys.databases
					WHERE	SUSER_SNAME(owner_sid) NOT IN ( @UserAcct )
							AND name NOT IN ( 'master', 'model', 'msdb', 'tempdb' );
				END TRY
				BEGIN CATCH
					SELECT	'***DB OWNER CHECK***' DatabaseName,
							'***********' CurrentDatabaseOwner,
							'?DO NOT MAKE ANY CHANGES NOW AS PRESCRIBED BELOW. PLEASE MAKE NOTE AND RUN THESE *ONLY* DURING MAINTENANCE WINDOW' [Command(s) to change Database Owner]
					UNION ALL

					SELECT	'***DB OWNER CHECK***' DatabaseName,
							'***********' CurrentDatabaseOwner,
							'All databases need to be owned by ' + @UserAcct
							+ 'to ensure correct operation and permissions.' [Command(s) to change Database Owner]
					UNION ALL

					SELECT	'******ERROR******' AS DatabaseName,
							'***********' CurrentDatabaseOwner,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;

			END;

	--Create temp table and fill with current values
	BEGIN TRY
		IF OBJECT_ID('tempdb..#fileInfo') IS NOT NULL
			BEGIN
				DROP TABLE #fileInfo;
			END;

		CREATE TABLE #fileInfo
			(
				Name NVARCHAR(100),
				FileID INT,
				Location NVARCHAR(1000),
				State INT,
				StateDesc NVARCHAR(100),
				Collation NVARCHAR(150)
			);

		INSERT	INTO #fileInfo
		SELECT	md.name,
				mf.file_id,
				mf.physical_name,
				mf.state,
				mf.state_desc,
				md.collation_name
		FROM	master.sys.master_files mf
		INNER JOIN master.sys.databases md
				ON mf.database_id = md.database_id;
	END TRY
	BEGIN CATCH
		SELECT	'***Create File Info***' ERROR,
				'***********' ErrorMessage
		UNION
		SELECT	'******ERROR******' AS ERROR,
				'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
				+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
	END CATCH;

	BEGIN /*COLLATION CHECK*/
		BEGIN TRY
			SELECT	'***COLLATION CHECK***' Name,
					'--Make sure that all of the databases are set to the same collation as the server' Collation
			UNION
			SELECT	Name,
					Collation
			FROM	#fileInfo
			WHERE	Collation <> CONVERT (VARCHAR, SERVERPROPERTY('collation'));
		END TRY
		BEGIN CATCH
			SELECT	'***COLLATION CHECK***' Name,
					'--Make sure that all of the databases are set to the same collation as the server' Collation
			UNION
			SELECT	'******ERROR******' AS Name,
					'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
					+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
		END CATCH;
	END;

	BEGIN /*DATABASE STATE*/
		BEGIN TRY
			SELECT	'***DATABASE STATE CHECK***' Name,
					'--Make sure that all of the databases that aren''t ''ONLINE'' are in the correct state' StateDesc
			UNION
			SELECT	name,
					state_desc
			FROM	master.sys.databases
			WHERE	state <> 0;
		END TRY
		BEGIN CATCH
			SELECT	'***DATABASE STATE CHECK***' Name,
					'--Make sure that all of the databases that aren''t ''ONLINE'' are in the correct state' StateDesc
			UNION
			SELECT	'******ERROR******' AS Name,
					'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
					+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
		END CATCH;
	END;

	BEGIN /*PHYSICAL FILE LOCATIONS*/
		BEGIN TRY
			SELECT	'***PHYSICAL FILE LOCATION CHECK***' AS Name,
					'--Investigate and plan a change to any of the files returned that should be changed.' AS Location
			UNION
			SELECT	Name,
					Location
			FROM	#fileInfo
			WHERE	(
						FileID = 1
						AND Location NOT LIKE '%\data01\%'
						AND Name NOT IN ( 'master', 'model', 'msdb', 'tempdb' )
					)
					OR
					(
							FileID <> 1
							AND Location NOT LIKE '%.ndf'
							AND Location NOT LIKE '%\logs01\%.ldf'
							AND Name NOT IN ( 'master', 'model', 'msdb','tempdb' )
					)
					OR
					(
							Location NOT LIKE '%\system01\data\%'
							AND Name IN ( 'master', 'model', 'msdb' )
					)
					OR
					(
							Location NOT LIKE '%\temp01\data\%'
							AND Name = 'tempdb'
					);
		END TRY
		BEGIN CATCH
			SELECT	'***PHYSICAL FILE LOCATION CHECK***' AS Name,
					NULL AS FileID,
					'--Investigate and plan a change to any of the files returned that should be changed.' AS Location
			UNION
			SELECT	'******ERROR******' AS Name,
					NULL AS FileID,
					'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
					+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
		END CATCH;
	END;

--Primary only
IF EXISTS ( SELECT	*
			FROM	#ServerNamesTable
			WHERE	LOWER(@@SERVERNAME) = ServerName )
				BEGIN
					BEGIN /*AG CHECKS*/
							IF SERVERPROPERTY('IsHadrEnabled') = 1
								BEGIN
						BEGIN /*SYSTEM DB SIZES*/
							BEGIN TRY
								SELECT	'***SYSTEM DB SIZE CHECK***' Name,
						'--Make sure that none of the system or dba databases are at extreme sizes' TotalSizeInMB
								UNION
								SELECT	'master' AS Name,
									CONVERT(NVARCHAR(10), ( SUM(size) * 8 ) / 1024) AS TotalSizeInMB
								FROM	master.sys.database_files
								UNION
								SELECT	'model' AS Name,
									CONVERT(NVARCHAR(10), ( SUM(size) * 8 ) / 1024) AS TotalSizeInMB
								FROM	model.sys.database_files
								UNION
								SELECT	'MSDB' AS Name,
									CONVERT(NVARCHAR(10), ( SUM(size) * 8 ) / 1024) AS TotalSizeInMB
								FROM	msdb.sys.database_files
								UNION
								SELECT	'tempdb' AS Name,
									CONVERT(NVARCHAR(10), ( SUM(size) * 8 ) / 1024) AS TotalSizeInMB
								FROM	tempdb.sys.database_files
								UNION
								SELECT	'dba' AS Name,
									CONVERT(NVARCHAR(10), ( SUM(size) * 8 ) / 1024) AS TotalSizeInMB
								FROM	dba.sys.database_files
								UNION
								SELECT	'util' AS Name,
									CONVERT(NVARCHAR(10), ( SUM(size) * 8 ) / 1024) AS TotalSizeInMB
								FROM	util.sys.database_files;
							END TRY
							BEGIN CATCH
								SELECT	'***SYSTEM DB SIZE CHECK***' Name,
							'--Make sure that none of the system or dba databases are at extreme sizes' TotalSizeInMB
								UNION
								SELECT	'******ERROR******' AS Name,
									'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
									+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
							END CATCH;
						END;
					END;
				end;
			end;
		end;


/*
-----------------
|Database Checks|
-----------------
FileGroup
VLF Count
TDE
DBCC CHECKDB
DB & Index Fragmentation
*/

BEGIN /*DATABASE CHECKS*/

	BEGIN /*TDE CHECK*/
		BEGIN TRY
			DECLARE	@CertName AS VARCHAR(200) = ( SELECT	name
													FROM	master.sys.certificates
													WHERE	name LIKE '%_TDECert'
												),
				@crlf AS CHAR(2) = CHAR(13) + CHAR(10);

			SELECT	'***TDE CHECK***' DatabaseName,
					'--All databases should be encrypted. If a database is not encrypted, please run these commands to backup the database, encrypt it, and back it up again.' [Command(s) to Encrypt DB(s)]
			UNION
			SELECT	name AS DatabaseName,
					'exec util.dbo.usp_backup_db @dbname = ''' + name
					+ ''', @bu_type = ''full''' + @crlf
					+ 'exec util.api_alias.EncryptDB @db_name = ''' + name
					+ ''', @appname = ''' + @CertName + '''' + @crlf
					+ 'exec util.dbo.usp_backup_db @dbname = ''' + name
					+ ''', @bu_type = ''full''' + @crlf AS [Command(s) to Encrypt DB(s)]
			FROM	master.sys.databases
			WHERE	is_encrypted = 0
					AND name NOT IN ( 'master', 'model', 'msdb', 'tempdb' );
		END TRY
		BEGIN CATCH
			SELECT	'***TDE CHECK***' DatabaseName,
					'--All databases should be encrypted. If a database is not encrypted, please run these commands to backup the database, encrypt it, and back it up again.' [Command(s) to Encrypt DB(s)]
			UNION
			SELECT	'******ERROR******' AS DatabaseName,
					'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
					+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
		END CATCH;

	END;

	BEGIN /*DBCC CHECKDB CHECK*/
		BEGIN TRY
			DECLARE	@name sysname,
				@sql NVARCHAR(MAX);

			IF OBJECT_ID('tempdb..#databases') IS NOT NULL
				BEGIN
					DROP TABLE #databases;
				END;

			SELECT	name
			INTO	#databases
			FROM	master.sys.databases
			WHERE	state NOT IN ( 1, 6 )
					AND name <> 'tempdb';

			IF OBJECT_ID('tempdb..#DBCCInfo') IS NOT NULL
				BEGIN
					DROP TABLE #DBCCInfo;
				END;

			CREATE TABLE #DBCCInfo
				(
					ParentObject NVARCHAR(255),
					Object NVARCHAR(255),
					Field NVARCHAR(255),
					Value NVARCHAR(1000)
				);

			IF OBJECT_ID('tempdb..#DBCCResults') IS NOT NULL
				BEGIN
					DROP TABLE #DBCCResults;
				END;

			CREATE TABLE #DBCCResults
				(
					DatabaseName sysname,
					LastKnownGoodDBCC DATETIME
				);

			WHILE EXISTS ( SELECT	1
							FROM	#databases )
				BEGIN
					TRUNCATE TABLE #DBCCInfo;

					SELECT TOP 1
							@name = name
					FROM	#databases;
					INSERT	INTO #DBCCInfo
							EXEC
								(
									'DBCC DBINFO (''' + @name
									+ ''') WITH TABLERESULTS'
								);

					INSERT	INTO #DBCCResults
					SELECT	@name AS [Database Name],
							CAST (Value AS DATETIME) LastKnownGood
					FROM	#DBCCInfo
					WHERE	Field = 'dbi_dbccLastKnownGood';

					DELETE	FROM #databases
					WHERE	name = @name;
				END;

			SELECT	'***DBCC CHECKDB CHECK***' DatabaseName,
					NULL LastKnownGoodDBCC,
					'--DBCC CHECKDB needs to be run daily. Run these commands to run DBCC CHECKDB on databases out of compliance' [Command(s) to Run DBCC CheckDB]
			UNION
			SELECT	DatabaseName,
					LastKnownGoodDBCC,
					'DBCC CHECKDB ([' + DatabaseName + ']) WITH NO_INFOMSGS' AS [Command(s) to Run DBCC CheckDB]
			FROM	#DBCCResults
			WHERE	LastKnownGoodDBCC < DATEADD(hh, -26, GETDATE())
			ORDER BY LastKnownGoodDBCC;

			DROP TABLE #databases;
			DROP TABLE #DBCCInfo;
			DROP TABLE #DBCCResults;
		END TRY
		BEGIN CATCH
			SELECT	'***DBCC CHECKDB CHECK***' DatabaseName,
					NULL LastKnownGoodDBCC,
					'--DBCC CHECKDB needs to be run daily. Run these commands to run DBCC CHECKDB on databases out of compliance' [Command(s) to Run DBCC CheckDB]
			UNION
			SELECT	'******ERROR******' AS DatabaseName,
					NULL LastKnownGoodDBCC,
					'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
					+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
		END CATCH;

	END;

	IF EXISTS ( SELECT	*
				FROM	#ServerNamesTable
				WHERE	LOWER(@@SERVERNAME) = ServerName )
		BEGIN
			BEGIN /*DB & INDEX FRAGMENTATION*/
				IF OBJECT_ID('tempdb..#indexCheck') IS NOT NULL
					BEGIN
						DROP TABLE #indexCheck;
					END;
				CREATE TABLE #indexCheck
					(
						DatabaseName NVARCHAR(128),
						IndexedObjectName VARCHAR(300),
						IndexType NVARCHAR(300),
						FragmentationPercent VARCHAR(100),
						PageCount INT
					);

				DECLARE	@indexFragQuery NVARCHAR(MAX);
				SET @indexFragQuery = '
			  INSERT INTO #indexCheck
			  SELECT ''?'' AS [DatabaseName]
				   , o.name AS [IndexedObjectName]
				   , ps.index_type_desc AS [IndexType]
				   , ps.avg_fragmentation_in_percent AS [FragmentationPercent]
				   , ps.page_count AS [PageCount]
				FROM master.sys.dm_db_index_physical_stats(DB_ID(''?''), DEFAULT, DEFAULT, DEFAULT, DEFAULT) ps
			   INNER JOIN [?].sys.objects o
				  ON ps.[object_id] = o.[object_id]
			   WHERE ps.avg_fragmentation_in_percent > 30
				 AND ps.page_count > 1000';
				BEGIN TRY
					EXEC dba.dbo.usp_foreachdb @command = @indexFragQuery,
						@suppress_quotename = 1;
					SELECT	'***FRAGMENTATION CHECK***' AS DatabaseName,
							'***************' AS IndexedObjectName,
							'--Checking to make sure that the reindex job is defragmenting the indexes.  It can have some but a lot needs to be addressed.' AS IndexType,
							NULL FragmentationPercent,
							NULL PageCount
					UNION
					SELECT	DatabaseName,
							IndexedObjectName,
							IndexType,
							FragmentationPercent,
							PageCount
					FROM	#indexCheck;
					IF OBJECT_ID('tempdb..#indexCheck') IS NOT NULL
						BEGIN
							DROP TABLE #indexCheck;
						END;
				END TRY
				BEGIN CATCH
					SELECT	'***FRAGMENTATION CHECK***' AS name,
							'--Checking to make sure that the reindex job is defragmenting the indexes.  It can have a some but a lot needs to be addressed.' AS index_type_desc
					UNION
					SELECT	'******ERROR******' AS name,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;
			END;

			BEGIN /*FILEGROUP CHECK*/
				BEGIN TRY
					IF OBJECT_ID('tempdb..#fileGroupCheck') IS NOT NULL
						BEGIN
							DROP TABLE #fileGroupCheck;
						END;

					DECLARE	@DBName NVARCHAR(512),
						@dynSQLFileGroup NVARCHAR(MAX);

					CREATE TABLE #fileGroupCheck
						(
							DBName NVARCHAR(128),
							FileGroupName VARCHAR(300),
							LogicalFileName VARCHAR(300),
							CurrentSizeInMB INT,
							NewSizeInMB INT,
							SpaceUsedMB INT,
							PercentUsed DECIMAL(5, 2)
						);

					SET @dynSQLFileGroup = '
						DECLARE @meg int = 128, @gig int = 131072
						USE [?];
						INSERT INTO #fileGroupCheck
							SELECT DB_NAME( DB_ID() ) as [DBName]
							, ISNULL ( sfg.name, ''LOG'' ) as [FileGroupName]
							, sdf.name as [LogicalFileName]
							, size/@meg AS [CurrentSizeInMB]
							, CASE
									WHEN size < @gig*2
										THEN ((size + (@meg*256))*8)/1024
									WHEN size >= @gig*2 AND size < @gig*5
										THEN ((size + (@meg*512))*8)/1024
									WHEN size >= @gig*5 AND size < @gig*10
										THEN ((size + (@meg*768))*8)/1024
									WHEN size >= @gig*10 AND size < @gig*50
										THEN ((size + (@meg*1024))*8)/1024
									WHEN size >= @gig*50 AND size < @gig*100
										THEN ((size + (@meg*2048))*8)/1024
									WHEN size >= @gig*100
										THEN ((size + (@meg*5120))*8)/1024
								END AS [NewSizeInMB]
							, (size/@meg)-((size/@meg) - ((FILEPROPERTY(sdf.name, ''SpaceUsed''))/@meg)) AS [SpaceUsedMB]
							, CAST(((size/128.0)-((size/128.0) - ((FILEPROPERTY(sdf.name, ''SpaceUsed''))/128.0)))/(size/128.0) AS decimal(5,2)) AS [PercentUsed]
							FROM [?].sys.database_files sdf
							LEFT JOIN [?].sys.filegroups sfg
							ON sdf.data_space_id = sfg.data_space_id
							ORDER BY sdf.name';

					EXEC dba.dbo.usp_foreachdb @command = @dynSQLFileGroup,
						@suppress_quotename = 1;

					SELECT	'***FILEGROUP CHECK***' DBName,
							'************' FileGroupName,
							'************' LogicalFileName,
							NULL CurrentSizeInMB,
							NULL NewSizeInMB,
							NULL SpaceUsedMB,
							NULL PercentUsed,
							'--Databases can be manually grown to eliminate the need to autogrow a database file. Run these command(s) to manually grow the database.' AS [Command(s) to Change File Space]
					UNION
					SELECT	DBName,
							FileGroupName,
							LogicalFileName,
							CurrentSizeInMB,
							NewSizeInMB,
							SpaceUsedMB,
							PercentUsed,
							'USE [master]; ALTER DATABASE [' + DBName
							+ '] MODIFY FILE ( NAME = ''' + LogicalFileName
							+ ''', SIZE = '
							+ CAST(NewSizeInMB AS NVARCHAR(20)) + 'MB )' AS [Command(s) to Change File Space]
					FROM	#fileGroupCheck
					WHERE	PercentUsed > .80;

					IF OBJECT_ID('tempdb..#fileGroupCheck') IS NOT NULL
						BEGIN
							DROP TABLE #fileGroupCheck;
						END;
				END TRY
				BEGIN CATCH
					SELECT	'***FILEGROUP CHECK***' DBName,
							'************' FileGroupName,
							'************' LogicalFileName,
							NULL CurrentSizeInMB,
							NULL NewSizeInMB,
							NULL SpaceUsedMB,
							NULL PercentUsed,
							'--Databases can be manually grown to eliminate the need to autogrow a database file. Run these command(s) to manually grow the database.' AS [Command(s) to Change File Space]
					UNION
					SELECT	'******ERROR******' AS DBName,
							'************' FileGroupName,
							'************' LogicalFileName,
							NULL CurrentSizeInMB,
							NULL NewSizeInMB,
							NULL SpaceUsedMB,
							NULL PercentUsed,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;
			END;

			BEGIN /*VLF COUNT CHECK*/
				BEGIN TRY
					IF OBJECT_ID('tempdb..#stageVLF2008') IS NOT NULL
						BEGIN
							DROP TABLE #stageVLF2008;
						END;

					IF OBJECT_ID('tempdb..#stageVLF2012') IS NOT NULL
						BEGIN
							DROP TABLE #stageVLF2012;
						END;

					IF OBJECT_ID('tempdb..#vlfResults') IS NOT NULL
						BEGIN
							DROP TABLE #vlfResults;
						END;

					CREATE TABLE #vlfResults
						(
							DBName sysname,
							VLFCount INT
						);

					DECLARE	@version VARCHAR(25),
						@dynSQL NVARCHAR(1000);
					SELECT	@version = @@VERSION;

					IF ( SUBSTRING(@version, 22, 4) = '2012' )
						BEGIN
							CREATE TABLE #stageVLF2012
								(
									RecoveryUnitID INT,
									FileID INT,
									FileSize BIGINT,
									StartOffset BIGINT,
									FSeqNo BIGINT,
									Status BIGINT,
									Parity BIGINT,
									CreateLSN NUMERIC(38)
								);

							SET @dynSQL = 'INSERT INTO #stageVLF2012
											 EXEC ( ''DBCC LogInfo ( [?] )'' )

										   INSERT INTO #vlfResults
										   SELECT ''?''
												, COUNT(*)
											 FROM #stageVLF2012

										 TRUNCATE TABLE #stageVLF2012';



							EXEC dba.dbo.usp_foreachdb @command = @dynSQL,
								@suppress_quotename = 1;
						END;
					ELSE
						BEGIN
							CREATE TABLE #stageVLF2008
								(
									FileID INT,
									FileSize BIGINT,
									StartOffset BIGINT,
									FSeqNo BIGINT,
									Status BIGINT,
									Parity BIGINT,
									CreateLSN NUMERIC(38)
								);

							SET @dynSQL = 'INSERT INTO #stageVLF2008
														EXEC ( ''DBCC LogInfo ( [?] )'' )

													  INSERT INTO #vlfResults
													  SELECT ''?''
														   , COUNT(*)
														FROM #stageVLF2008

													TRUNCATE TABLE #stageVLF2008';

							EXEC dba.dbo.usp_foreachdb @command = @dynSQL,
								@suppress_quotename = 1;
						END;
					SELECT	'***VLF COUNT CHECK***' DBName,
							NULL VLFCount,
							'--All databases should have VLF Counts under 60 VLFs. If you have more than 60 VLFs, please run these commands to reduce your VLFs.' [Command(s) to Reduce VLFs]
					UNION
					SELECT	DBName,
							VLFCount,
							'EXEC dba.dbo.usp_dba_ReduceVLFs @DBName = '''
							+ DBName + '''' AS [Command(s) to Reduce VLFs]
					FROM	#vlfResults
					WHERE	VLFCount > 60;

					IF OBJECT_ID('tempdb..#stageVLF2008') IS NOT NULL
						BEGIN
							DROP TABLE #stageVLF2008;
						END;

					IF OBJECT_ID('tempdb..#stageVLF2012') IS NOT NULL
						BEGIN
							DROP TABLE #stageVLF2012;
						END;

					IF OBJECT_ID('tempdb..#vlfResults') IS NOT NULL
						BEGIN
							DROP TABLE #vlfResults;
						END;
				END TRY
				BEGIN CATCH
					SELECT	'***VLF COUNT CHECK***' DBName,
							NULL VLFCount,
							'--All databases should have VLF Counts under 60 VLFs. If you have more than 60 VLFs, please run these commands to reduce your VLFs.' [Command(s) to Reduce VLFs]
					UNION
					SELECT	'******ERROR******' AS DBName,
							NULL VLFCount,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;
			END;
		END;
END;

/*
------------------
|SQL Agent Checks|
------------------
Standard Jobs   -- Commented out until the correct naming conventions are merged to prod
Standard Alerts -- Commented out until the correct naming conventions are merged to prod
Operators
Job Owner
Job History
Disabled Alerts
Disabled Jobs
Backup History
*/
BEGIN /*SQL AGENT CHECKS*/

	IF EXISTS ( SELECT	*
				FROM	#ServerNamesTable
				WHERE	LOWER(@@SERVERNAME) = ServerName )
		BEGIN
/* Commented out until the correct naming conventions are merged to prod
		BEGIN /*STANDARD JOBS CHECK*/
			BEGIN TRY
				IF OBJECT_ID('tempdb..#XPDirTreeJobs') IS NOT NULL
				   BEGIN
					   DROP TABLE #XPDirTreeJobs;
				   END;

				CREATE TABLE #XPDirTreeJobs ( id int IDENTITY(1,1)
											, subdirectory NVARCHAR(512)
											, depth INT
											, isfile BIT
											, StandardJobName AS (SUBSTRING(subdirectory,1,(LEN(subdirectory)-4)))
											) ;

				INSERT INTO #XPDirTreeJobs
				  EXEC master.sys.xp_dirtree 'C:\scripts\db\msdb\base\jobs',1,1;

				DELETE
				  FROM #XPDirTreeJobs
				 WHERE isfile <> 1;

				SELECT '***STANDARD JOBS CHECK***' [Missing Jobs]
					 , '--All jobs must exist on your server. Run these commands to enable them.' [Command(s) to Add Missing Jobs]
				 UNION
				SELECT ttjobs.StandardJobName AS [Missing Jobs]
					 , 'exec xp_cmdshell ''sqlcmd -d "msdb" -i "C:\scripts\db\msdb\base\jobs\'
					 + ttjobs.StandardJobName
					 + '.sql"'', NO_OUTPUT' AS [Command(s) to Add Missing Jobs]
				  FROM #XPDirTreeJobs ttjobs
				  LEFT JOIN msdb.dbo.sysjobs msdbjobs
					ON ttjobs.StandardJobName = msdbjobs.name
				 WHERE msdbjobs.name IS NULL;

				IF OBJECT_ID('tempdb..#XPDirTreeJobs') IS NOT NULL
				   BEGIN
					   DROP TABLE #XPDirTreeJobs;
				   END;
			END TRY
			BEGIN CATCH
				SELECT '***STANDARD JOBS CHECK***' [Missing Jobs]
					 , '--All jobs must exist on your server. Run these commands to enable them.' [Command(s) to Add Missing Jobs]
				 UNION
				SELECT '******ERROR******'AS [Missing Jobs]
					 , 'ERROR: ' + ERROR_MESSAGE() + '  Located on line: ' + CONVERT(varchar(5), ERROR_LINE()) AS [ErrorMessage]
			END CATCH
		END;

		BEGIN /*STANDARD ALERTS CHECK*/
			BEGIN TRY
				IF OBJECT_ID('tempdb..#XPDirTreeAlerts') IS NOT NULL
					BEGIN
						DROP TABLE #XPDirTreeAlerts;
					END;

				CREATE TABLE #XPDirTreeAlerts ( id int IDENTITY(1,1)
											, subdirectory NVARCHAR(512)
											, depth INT
											, isfile BIT
											, StandardAlertName AS (SUBSTRING(subdirectory,1,(LEN(subdirectory)-4)))
											) ;

				INSERT INTO #XPDirTreeAlerts
				  EXEC master.sys.xp_dirtree 'C:\scripts\db\msdb\base\alerts',1,1;

				DELETE
				  FROM #XPDirTreeAlerts
				 WHERE isfile <> 1;

				SELECT '***STANDARD ALERTS CHECK***' [Missing Alerts]
					 , '--All alerts must exist on your server. Run these commands to enable them.' [Command(s) to Add Missing Alerts]
				 UNION
				SELECT ttalerts.StandardAlertName AS [Missing Alerts]
					 , 'exec xp_cmdshell ''sqlcmd -S '
					 + @@SERVERNAME
					 + ' -d "msdb" -i "C:\scripts\db\msdb\base\alerts\'
					 + ttalerts.StandardAlertName
					 + '.sql"'', NO_OUTPUT' AS [Command(s) to Add Missing Alerts]
				  FROM #XPDirTreeAlerts ttalerts
				  LEFT JOIN msdb.dbo.sysalerts msdbalerts
					ON ttalerts.StandardAlertName = msdbalerts.name
				 WHERE msdbalerts.name IS NULL;

				IF OBJECT_ID('tempdb..#XPDirTreeAlerts') IS NOT NULL
					BEGIN
						DROP TABLE #XPDirTreeAlerts;
					END;
			END TRY
			BEGIN CATCH
				SELECT '***STANDARD ALERTS CHECK***' [Missing Alerts]
					 , '--All alerts must exist on your server. Run these commands to enable them.' [Command(s) to Add Missing Alerts]
				 UNION
				SELECT '******ERROR******'AS [Missing Alerts]
					 , 'ERROR: ' + ERROR_MESSAGE() + '  Located on line: ' + CONVERT(varchar(5), ERROR_LINE()) AS [ErrorMessage]
			END CATCH
		END;
*/

			BEGIN /*OPERATORS CHECK*/
				BEGIN TRY
					SELECT	'***OPERATORS CHECK***' [Operator Names],
							'--All alerts must exist on your server. Run these commands to enable them.' [Operator Emails]
					UNION
					SELECT	name AS [Operator Names],
							email_address AS [Operator Emails]
					FROM	msdb.dbo.sysoperators;
				END TRY
				BEGIN CATCH
					SELECT	'***OPERATORS CHECK***' [Operator Names],
							'--All servers must have an Alert Operator and a DBA Group operator. Ensure you have each, and that they''re set to the correct email addresses.' [Operator Emails]
					UNION
					SELECT	'******ERROR******' AS [Operator Names],
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;
			END;

			BEGIN /*JOB OWNER CHECK*/
				BEGIN TRY
					DECLARE	@ThisDomain sysname,
						@ThisUserAcct sysname;
					SELECT	@ThisDomain = DEFAULT_DOMAIN();
					SET @ThisUserAcct = @ThisDomain + N'\sqlagent_svc';

					SELECT	'***JOB OWNER CHECK***' JobName,
							'***********' CurrentJobOwner,
							'--All DBA jobs need to be owned by '
							+ @ThisUserAcct
							+ '. If this is not the case, run these commands to change the jobs to be in complaince. Certain applications create jobs that need to be owned by specific users. Thus, this script is limited to just DBA jobs.' [Command(s) to change Job Owner]
					UNION
					SELECT	sj.name AS JobName,
							SUSER_SNAME(sj.owner_sid) AS CurrentJobOwner,
							'EXEC msdb.dbo.sp_update_job @job_name = '''
							+ sj.name + ''', @owner_login_name = '''
							+ @ThisUserAcct + '''' AS [Command(s) to change Job Owner]
					FROM	msdb.dbo.sysjobs sj
					WHERE	SUSER_SNAME(sj.owner_sid) NOT IN ( @ThisUserAcct )
							AND sj.name NOT IN ( 'syspolicy_purge_history' )
							AND sj.name LIKE 'dba_%';
				END TRY
				BEGIN CATCH
					SELECT	'***JOB OWNER CHECK***' JobName,
							'***********' CurrentJobOwner,
							'--All DBA jobs need to be owned by '
							+ @ThisUserAcct
							+ '. If this is not the case, run these commands to change the jobs to be in complaince. Certain applications create jobs that need to be owned by specific users. Thus, this script is limited to just DBA jobs.' [Command(s) to change Job Owner]
					UNION
					SELECT	'******ERROR******' AS JobName,
							'***********' CurrentJobOwner,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;
			END;

			BEGIN /*DISABLED ALERTS CHECK*/
				BEGIN TRY
					SELECT	'***DISABLED ALERTS CHECK***' Alert_Name,
							NULL Is_Enabled,
							'--All alerts must be enabled. Run these commands to enable them.' [Command(s) to Enable Alert(s)]
					UNION
					SELECT	name AS Alert_Name,
							enabled AS Is_Enabled,
							'EXEC [msdb].[dbo].[sp_update_alert] @name = '''
							+ name + ''', @enabled = 1' AS [Command(s) to Enable Alert(s)]
					FROM	msdb.dbo.sysalerts
					WHERE	enabled <> 1;
				END TRY
				BEGIN CATCH
					SELECT	'***DISABLED ALERTS CHECK***' Alert_Name,
							NULL Is_Enabled,
							'--All alerts must be enabled. Run these commands to enable them.' [Command(s) to Enable Alert(s)]
					UNION
					SELECT	'******ERROR******' AS Alert_Name,
							NULL Is_Enabled,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;
			END;

			BEGIN /*DISABLED JOBS CHECK*/
				BEGIN TRY
					SELECT	'***DISABLED JOBS CHECK***' Job_Name,
							NULL Is_Enabled,
							'--All DBA jobs should be enabled. Run these commands to enable them.' [Command(s) to Enable Job(s)]
					UNION
					SELECT	name AS Job_Name,
							enabled AS Is_Enabled,
							'EXEC [msdb].[dbo].[sp_update_job] @job_name = '''
							+ name + ''', @enabled = 1' AS [Command(s) to Enable Job(s)]
					FROM	msdb.dbo.sysjobs
					WHERE	enabled <> 1
							AND name LIKE 'dba_%'
					UNION
					SELECT	name AS Job_Name,
							enabled AS Is_Enabled,
							'EXEC [msdb].[dbo].[sp_update_job] @job_name = '''
							+ name + ''', @enabled = 1' AS [Command(s) to Enable Job(s)]
					FROM	msdb.dbo.sysjobs
					WHERE	enabled <> 1
							AND name = 'syspolicy_purge_history';
				END TRY
				BEGIN CATCH
					SELECT	'***DISABLED JOBS CHECK***' Job_Name,
							NULL Is_Enabled,
							'--All DBA jobs should be enabled. Run these commands to enable them.' [Command(s) to Enable Job(s)]
					UNION
					SELECT	'******ERROR******' AS Job_Name,
							NULL Is_Enabled,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;
			END;

			BEGIN /*DISABLED OPERATORS CHECK*/
				BEGIN TRY
					SELECT	'***DISABLED OPERATORS CHECK***' Operator_Name,
							NULL Is_Enabled,
							'--All operators should be enabled. Run these commands to enable them.' [Command(s) to Enable Operator(s)]
					UNION
					SELECT	name AS Operator_Name,
							enabled AS Is_Enabled,
							'EXEC msdb.dbo.sp_update_operator @name = ''' + name
							+ ''', @enabled = 1' AS [Command(s) to Enable Operator(s)]
					FROM	msdb.dbo.sysoperators
					WHERE	enabled <> 1;
				END TRY
				BEGIN CATCH
					SELECT	'***DISABLED OPERATORS CHECK***' Operator_Name,
							NULL Is_Enabled,
							'--All operators should be enabled. Run these commands to enable them.' [Command(s) to Enable Operator(s)]
					UNION
					SELECT	'******ERROR******' AS Operator_Name,
							NULL Is_Enabled,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;
			END;
		END;

	BEGIN /*JOB HISTORY CHECK*/
		BEGIN TRY
			DECLARE	@dt INT = ( YEAR(DATEADD(d, -3, GETDATE())) * 10000 )
				+ ( MONTH(DATEADD(d, -3, GETDATE())) * 100 ) + ( DAY(DATEADD(d,
																-3, GETDATE())) );

			SELECT	'***JOB HISTORY CHECK***' job_name,
					NULL run_date,
					NULL run_time,
					'--Your jobs should not be failing. If they are, please investigate why they are failing and rectify that.' run_status
			UNION
			SELECT	sj.name job_name,
					sjh.run_date,
					sjh.run_time,
					CASE	WHEN sjh.run_status = 0 THEN 'failed'
							WHEN sjh.run_status = 2 THEN 'retry'
							WHEN sjh.run_status = 3 THEN 'cancelled'
					END AS run_status
			FROM	msdb.dbo.sysjobs sj
			INNER JOIN msdb.dbo.sysjobhistory sjh
					ON sj.job_id = sjh.job_id
			WHERE	sjh.step_id = 0
					AND sjh.run_status <> 1
					AND sj.name <> 'syspolicy_purge_history'
					AND sjh.run_date >= @dt
					AND sj.name LIKE 'dba_%'
			ORDER BY run_date ASC;
		END TRY
		BEGIN CATCH
			SELECT	'***JOB HISTORY CHECK***' job_name,
					NULL run_date,
					NULL run_time,
					'--Your jobs should not be failing. If they are, please investigate why they are failing and rectify that.' run_status
			UNION
			SELECT	'******ERROR******' AS job_name,
					NULL run_date,
					NULL run_time,
					'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
					+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
		END CATCH;

	END;

	BEGIN /*BACKUP HISTORY CHECK*/
		BEGIN TRY
			DECLARE	@msdbOldDate DATE;

			SELECT TOP 1
					@msdbOldDate = CONVERT(DATE, backup_finish_date)
			FROM	msdb.dbo.backupset
			WHERE	database_name = 'master'
			ORDER BY backup_finish_date ASC;

			SELECT	'***BACKUP HISTORY CHECK***' [Day(s) of MSDB Backup History],
					'--You should have at most 60-80 days of msdb backup history. If you have less it is most likely because you have a young server.' Instructions
			UNION
			SELECT	CONVERT(VARCHAR(3), ABS(DATEDIFF(dd, GETDATE(), @msdbOldDate)), 0) AS [Day(s) of MSDB Backup History],
					'--Check inside the dba_cleanup job to see if it has code to cleanup MSDB Backup History. If it does, run the job, if not refresh your job.' AS Instructions;

		END TRY
		BEGIN CATCH
			SELECT	'***BACKUP HISTORY CHECK***' [Day(s) of MSDB Backup History],
					'--You should have at most 60-80 days of msdb backup history. If you have less it is most likely because you have a young server.' Instructions
			UNION
			SELECT	'******ERROR******' AS Job_Name,
					'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
					+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
		END CATCH;

	END;

END;

/*
-----------
|AG Checks|
-----------
Database Sync
AG Health
AG Log
Login Log
*/
--Primary Only
IF EXISTS ( SELECT	*
			FROM	#ServerNamesTable
			WHERE	LOWER(@@SERVERNAME) = ServerName )
	BEGIN
		BEGIN /*AG CHECKS*/
			BEGIN TRY
				IF SERVERPROPERTY('IsHadrEnabled') = 1
					BEGIN
						BEGIN /*DATABASE SYNC CHECK*/

							SELECT	'***DATABASE SYNC CHECK***' [Database(s) Not In Sync],
									'--If you have an Availability Group all of the databases need to be synchronized. If they are not, please fix that.' [Database Creation Date]
							UNION
							SELECT	db.name AS [Database(s) Not In Sync],
									CAST(db.create_date AS NVARCHAR(100)) AS [Database Creation Date]
							FROM	master.sys.databases db
							LEFT JOIN master.sys.dm_hadr_database_replica_states drs
									ON db.database_id = drs.database_id
							WHERE	db.name NOT IN ( 'master', 'model', 'msdb',
													'tempdb', 'util', 'CODBALogs', 'CODBAProcedures' )
									AND drs.database_id IS NULL;

						END;

						BEGIN /*AG HEALTH CHECK*/
							SELECT	'***UNHEALTHY NODE CHECK***' NodeName,
									'--All nodes should be in a healthy state. If they are not, please investigate why you have an unhealthy node.' NodeHealth
							UNION
							SELECT	primary_replica AS NodeName,
									synchronization_health_desc AS NodeHealth
							FROM	master.sys.dm_hadr_availability_group_states
							WHERE	synchronization_health_desc <> 'HEALTHY';
						END;

						BEGIN /*AG LOG CHECK*/
							IF OBJECT_ID('dba.dbo.AG_Log') IS NOT NULL
								BEGIN
									SELECT	'***AG LOG CHECK***' AS DB,
											'--All databases need to be backed up. If a database is in the AG_Log table it will not be backed up. Validate that the databases are not in the process of being synced by the API or code created by an Infor DBA and then delete the record.' AS [Command(s) to Clean Up AG Log]
									UNION
									SELECT	DB,
											'DELETE FROM dba.dbo.AG_Log WHERE DB = '''
											+ DB + '''' AS [Command(s) to Clean Up AG Log]
									FROM	dba.dbo.AG_Log
									ORDER BY DB;
								END;
						END;
					END;
				ELSE
					RAISERROR('This server is not a part of an Availability Group!', 16, 1);
			END TRY
			BEGIN CATCH
				SELECT	'***DATABASE SYNC CHECK***' AS [Not an AG],
						'--If you have an Availability Group all of the databases need to be synchronized. If they are not, please fix that.' AS Message
				UNION
				SELECT	'***UNHEALTHY NODE CHECK***' [Not an AG],
						'--All nodes should be in a healthy state. If they are not, please investigate why you have an unhealthy node.' Message
				UNION
				SELECT	'***AG LOG CHECK***' AS [Not an AG],
						'--All databases need to be backed up. If a database is in the AG_Log table it will not be backed up. Validate that the databases are not in the process of being synced by the API or code created by an Infor DBA and then delete the record.' AS Message
				UNION
				SELECT	'******ERROR******' AS [Not an AG],
						'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
						+ CONVERT(VARCHAR(5), ERROR_LINE()) AS Message;
			END CATCH;

			BEGIN /*LOGIN LOG CHECK*/
				BEGIN TRY
					IF OBJECT_ID('dba.dbo.Login_Log') IS NOT NULL
						BEGIN
							SELECT	'***LOGIN LOG CHECK***' Login,
									'--No Logins should be in the Login_Log. If there are logins in here, they will not be synced. Run these commands to fix this issue.' [Command(s) to fix Login_Log]
							UNION
							SELECT	Login,
									'DELETE FROM dba.dbo.Login_Log WHERE Login = '''
									+ Login + '''' AS [Command(s) to fix Login_Log]
							FROM	dba.dbo.Login_Log;
						END;
				END TRY
				BEGIN CATCH
					SELECT	'***LOGIN LOG CHECK***' Login,
							'--No Logins should be in the Login_Log. If there are logins in here, they will not be synced. Run these commands to fix this issue.' [Command(s) to fix Login_Log]
					UNION
					SELECT	'******ERROR******' AS Login,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS Message;
				END CATCH;

			END;
		END;
	END;
/*
---------------
|Server Checks|
---------------
SA User Check
Unneccessary SA Users Check
ScriptRunner Service Account
SQL Error Log
Windows System Event Log
Server Settings Check
Drive Space Check
Time Offset Check
*/
BEGIN /*SERVER CHECKS*/
	BEGIN /* SA User Check */
		BEGIN TRY /* If sa account exists, rename and disable */
			SELECT	'***DISABLE AND RENAME SA ACCOUNT***' AS AccountName,
					'/* The sa account should be disabled and renamed to improve security */' AS [Command(s) to Change sa Name and Disable]
			UNION
			SELECT	name AS AccountName,
					'ALTER LOGIN sa ENABLE ; ALTER LOGIN sa WITH NAME = Fred ;'
			FROM	sys.server_principals
			WHERE	name = 'sa';

		END TRY
		BEGIN CATCH
			SELECT	'***DISABLE AND RENAME SA ACCOUNT***' AccountName,
					'/* The sa account should be disabled and renamed to improve security */' [Command(s) to Change sa Name and Disable]
			UNION
			SELECT	'******ERROR******' AS AccountName,
					'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
					+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
		END CATCH;
	END;

	BEGIN /* Unneccessary SA Users Check */
		BEGIN TRY /* Unneccessary SA Users Check */
			/* Drop any tables that may already exist */
			IF OBJECT_ID('tempdb..#tmpRoles') IS NOT NULL
				BEGIN
					DROP TABLE #tmpRoles;
				END;

			IF OBJECT_ID('tempdb..#Results') IS NOT NULL
				BEGIN
					DROP TABLE #Results;
				END;
			/* Create the #tmpRoles table to store the Joined tabled of roles */
			CREATE TABLE #tmpRoles
				(
					role VARCHAR(100),
					RoleName NVARCHAR(100),
					member VARCHAR(100),
					MemberName NVARCHAR(100)
				);
			/* Select and insert the roles and members into the #tmpRolestable, joined on ID */
			INSERT	INTO #tmpRoles
			SELECT	role_principal_id,
					role.name AS RoleName,
					member_principal_id,
					member.name AS MemberName
			FROM	sys.server_role_members
			JOIN	sys.server_principals AS role
					ON role_principal_id = role.principal_id
			JOIN	sys.server_principals AS member
					ON member_principal_id = member.principal_id;

			/* Create table for results */
			CREATE TABLE #Results
				(
					AccountName VARCHAR(100),
					[Commands to remove unneccessary SA accounts] VARCHAR(1000)
				);

			INSERT	INTO #Results
			SELECT	'***REMOVE UNNECCESSARY SA ACCOUNTS***' AS AccountName,
					'/* Returns code for any accounts that need to be removed from SA role */' AS [Commands to remove unneccessary SA accounts];

			/* If any roles exist with SA rights, check if there are any that should not */
			IF EXISTS ( SELECT	1
						FROM	#tmpRoles )
				BEGIN
					INSERT	INTO #Results
					SELECT	MemberName AS AccountName,
							'ALTER SERVER ROLE sysadmin DROP MEMBER [' + MemberName + ']' AS [Command(s) to Change sa Name and Disable]
					FROM	#tmpRoles
					WHERE	RoleName = 'sysadmin'
							AND MemberName NOT IN ( 'sa', 'Fred',
													'NT SERVICE\SQLWriter',
													'NT SERVICE\Winmgmt',
													'NT SERVICE\MSSQLSERVER',
													'NT SERVICE\SQLSERVERAGENT',
													'api_alias', 'BuildUser' )
							AND MemberName NOT LIKE '%\GRA-SQLDBAAdmins'
							AND MemberName NOT LIKE '%\sql%_svc';
				END;

			/* Output results and drop tables */
			SELECT	*
			FROM	#Results;
			DROP TABLE #tmpRoles;
			DROP TABLE #Results;

		END TRY
		BEGIN CATCH /* Catch any errors that were found in the check */
			SELECT	'***DISABLE AND RENAME SA ACCOUNT***' AS AccountName,
					'/* The sa account should be disabled and renamed to improve security */' AS [Command(s) to Change sa Name and Disable]
			UNION
			SELECT	'******ERROR******' AS AccountName,
					'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
					+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
		END CATCH;

	END;

	BEGIN /*SCRIPTRUNNER SERVICE ACCOUNT CHECK*/
		BEGIN TRY
			DECLARE	@val VARCHAR(200),
				@retVal VARCHAR(200) = '',
				@MyDomain sysname,
				@MyUserAcct sysname,
				@MyUserAcctExtended sysname;

			SELECT	@MyDomain = DEFAULT_DOMAIN();
			SET @MyUserAcct = @MyDomain + N'\api' + @MyDomain + N'_svc';
			SET @MyUserAcctExtended = N'api' + @MyDomain + N'_svc@' + @MyDomain
				+ N'.inforcloud.local';

			EXEC sys.xp_regread @root_key = 'HKEY_LOCAL_MACHINE',
				@key = 'SYSTEM\ControlSet001\Services\ScriptRunner',
				@valuename = 'ObjectName', @value = @val OUTPUT;

			IF (
					( @val <> @MyUserAcct )
					AND ( @val <> @MyUserAcctExtended )
				)
				BEGIN
					SET @retVal = @val;
				END;

			SELECT	'***SCRIPTRUNNER SERVICE ACCOUNT CHECK***' ScriptRunnerServiceAcct,
					'--ScriptRunner should be running as ' + @MyUserAcct
					+ ' to ensure that API Calls run successfully. If it is not, a record will be returned, and you will need to go into Windows Services and fix it on the node.' Instructions
			UNION
			SELECT	@retVal AS ScriptRunnerServiceAcct,
					'*************' AS Instructions
			ORDER BY ScriptRunnerServiceAcct DESC;

		END TRY
		BEGIN CATCH
			SELECT	'***SCRIPTRUNNER SERVICE ACCOUNT CHECK***' ScriptRunnerServiceAcct,
					'--ScriptRunner should be running as ' + @MyUserAcct
					+ ' to ensure that API Calls run successfully. If it is not, a record will be returned, and you will need to go into Windows Services and fix it on the node.' Instructions
			UNION
			SELECT	'******ERROR******' AS ScriptRunnerServiceAcct,
					'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
					+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
		END CATCH;

	END;

	BEGIN /*SQL ERROR LOG CHECK*/
		BEGIN TRY
			DECLARE	@currentDate DATETIME = GETDATE(),
				@DiskSpaceThreshold FLOAT = .6500;

			IF OBJECT_ID('tempdb..#tmpErrorLog') IS NOT NULL
				BEGIN
					DROP TABLE #tmpErrorLog;
				END;

			CREATE TABLE #tmpErrorLog
				(
					LogDate DATETIME,
					ProcessInfo VARCHAR(100),
					Text VARCHAR(MAX)
				);

			INSERT	INTO #tmpErrorLog
					EXEC master.sys.xp_readerrorlog 0, 1;

			SELECT	'***ERROR LOG CHECK***' ProcessInfo,
					NULL LogDate,
					'--Review the Error Log Entries to see if there is anything of concern' Text
			UNION
			SELECT	ProcessInfo,
					LogDate,
					Text
			FROM	#tmpErrorLog
			WHERE	LogDate BETWEEN DATEADD(d, -2, @currentDate)
							AND		@currentDate
					AND Text NOT LIKE 'DBCC CHECKDB%found 0 errors%'
					AND Text NOT LIKE 'SQL Trace stopped.%'
					AND Text NOT LIKE 'SQL Trace ID%was started by%'
					AND Text NOT LIKE '%transactions rolled back%No user action is required%'
					AND Text NOT LIKE '%transactions rolled forward in database%No user action is required.%'
					AND Text NOT LIKE 'Recovery completed for database%'
					AND Text NOT LIKE 'Log was backed up. Database:%No user action is required.%'
					AND Text NOT LIKE 'Database differential changes were backed up%No user action is required.%'
					AND Text NOT LIKE 'Database backed up.%No user action is required.%'
					AND Text NOT LIKE 'Error: 14421%'
					AND Text NOT LIKE 'The log shipping secondary database%'
					AND Text NOT LIKE 'Error: 18054%'
					AND Text NOT LIKE 'Error: 50005%'
					AND Text NOT LIKE 'Error 50005%'
					AND Text NOT LIKE 'Unsafe assembly ''mgsharedsqlclrunsafe%'
					AND Text NOT LIKE 'Configuration option ''xp_cmdshell''%'
					AND Text NOT LIKE 'Configuration option ''show advanced options''%'
					AND Text NOT LIKE 'The Service Broker endpoint is in disabled or stopped state.'
					AND Text NOT LIKE 'AlwaysOn Availability Groups connection with secondary database established for primary database%'
			ORDER BY LogDate ASC;

			DROP TABLE #tmpErrorLog;
		END TRY
		BEGIN CATCH
			SELECT	'***ERROR LOG CHECK***' ProcessInfo,
					'--Review the Error Log Entries to see if there is anything of concern' Text
			UNION
			SELECT	'******ERROR******' AS ProcessInfo,
					'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
					+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
		END CATCH;

	END;

	IF EXISTS ( SELECT	*
				FROM	#ServerNamesTable
				WHERE	LOWER(@@SERVERNAME) = ServerName )
		BEGIN

			BEGIN/*WINDOWS SYSTEM EVENT LOG*/
				BEGIN TRY
					DECLARE	@exists INT;

					IF OBJECT_ID('tempdb..##WinSysEventLog') IS NOT NULL
						BEGIN
							DROP TABLE ##WinSysEventLog;
						END;

					CREATE TABLE ##WinSysEventLog
						(
							LogID INT IDENTITY(1, 1)
										PRIMARY KEY,
							EventID INT,
							MachineName NVARCHAR(200),
							EntryType NVARCHAR(100),
							Source NVARCHAR(100),
							Message NVARCHAR(MAX),
							Time DATETIME2
						);
					EXEC master.sys.xp_fileexist 'C:\scripts\Maintenance\DailyChecks\GetEventLog.ps1',
						@exists OUTPUT;

					IF ( @exists <> 1 )
						BEGIN
							RAISERROR ('Powershell file to check server settings does not exist (C:\scripts\Maintenance\DailyChecks\GetEventLog.ps1)', 16, 1);
							RETURN;
						END;

					EXEC sys.xp_cmdshell 'powershell.exe -Command "& C:\scripts\Maintenance\DailyChecks\GetEventLog.ps1"',
						no_output;

					SELECT	'***WINDOWS SYSTEM LOG CHECK***' AS ComputerName,
							NULL AS EventID,
							'************' AS EntryType,
							'************' AS Source,
							'--Review this server log to see if there is anything of concern.  This is only a small subset of system logs.' AS Message,
							NULL AS Time
					UNION
					SELECT	MachineName AS ComputerName,
							EventID,
							EntryType,
							Source,
							Message,
							Time
					FROM	##WinSysEventLog
					WHERE	Message NOT LIKE 'The description for Event ID ''%'
					ORDER BY ComputerName,
							Time DESC;

					DROP TABLE ##WinSysEventLog;
				END TRY
				BEGIN CATCH
					SELECT	'***WINDOWS SYSTEM LOG CHECK***' AS ComputerName,
							NULL AS EventID,
							'************' AS EntryType,
							'************' AS Source,
							'--Review this server log to see if there is anything of concern.  This is only a small subset of system logs.' AS Message
					UNION
					SELECT	'******ERROR******' AS ComputerName,
							NULL AS EventID,
							'************' AS EntryType,
							'************' AS Source,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;

				END CATCH;
			END;
			DECLARE	@file_exists INT;
 /* Commenting this out due to issues with the powershell file. This is also being re-written to take advantage of scheduled tasks and pre-built tables with historical data.
		BEGIN /*SERVER SETTINGS CHECK*/
			BEGIN TRY
				DECLARE @file_exists int

				EXEC master.dbo.xp_fileexist 'C:\scripts\db\dba\powershell\SettingsCheck.ps1', @file_exists OUTPUT

				IF (@file_exists <> 1)
				BEGIN
					RAISERROR ('Powershell file to check server settings does not exist (C:\scripts\db\dba\powershell\SettingsCheck.ps1)', 16, 1)
					RETURN
				END

				Declare @start datetime2 = DATEADD(SECOND, -60, SYSUTCDATETIME())

				EXEC xp_cmdshell 'powershell.exe -Command "& C:\scripts\db\dba\powershell\SettingsCheck.ps1"',no_output
				--Future Code (Compare to dynamo db settings standards)


/*
				SELECT NULL AS [ID]
					 , NULL as ServerID
					 , '***SERVER SETTINGS CHECK***' AS [RunTime]
					 , '--Review the server settings to see if there is anything of concern' AS [ServerName]
					 , NULL AS [IPV4ChecksumOffload]
					 , NULL AS [LargeSendOffloadV2(IPv4)]
					 , NULL AS [TCPChecksumOffload(IPv4)]
					 , NULL AS [UDPChecksumOffload(IPv4)]
					 , NULL AS [Intel(R)82599VirtualFunction]
					 , NULL AS [AWSPVStorageHostAdapter]
					 , NULL AS [AWSPVBus]
					 , NULL AS [SameSubnetDelay]
					 , NULL AS [SameSubnetThreshold]
					 , NULL AS [CrossSubnetDelay]
					 , NULL AS [CrossSubnetThreshold]
					 , NULL AS [RouteHistoryLength]
					 , NULL AS [LeaseTimeout]
					 , NULL AS [ScriptRunnerServiceAcct]
					 , NULL AS [ScriptRunnerStatus]
					 , NULL AS [ClusterGroupAllSameNode]
					 , NULL AS [NumWindowsUpdate]
					 , NULL AS [LastBootTime]
					 , NULL AS [WINRMStatus]
				 UNION
				Select *
				From dba.History.WindowsSettingsLog
				Where RunTime > @start
*/

				SELECT * FROM dba.History.WindowsSettingsLog
				INNER JOIN
				dba.History.Servers
				ON dba.History.WindowsSettingsLog.ServerID = dba.History.Servers.ServerID
			END TRY
			BEGIN CATCH
				SELECT '***SERVER SETTINGS CHECK***' [ErrorMessage]
					 , '--Review the returned volumes to determine if space can be cleared or when a volume should be replaced.' AS [ErrorMessage]
				 UNION
				SELECT '******ERROR******'AS [ErrorMessage]
					 , 'ERROR: ' + ERROR_MESSAGE() + '  Located on line: ' + CONVERT(varchar(5), ERROR_LINE()) AS ErrorMessage;
			END CATCH
		END

		BEGIN/*DRIVE SPACE CHECK*/
			BEGIN TRY
				/* Drive Space Check is being re-written to use the new tables with data gathered by scheduled tasks */
				/*
				SELECT NULL AS [RunTime]
					 , '***DRIVE SPACE CHECK***' AS [ServerName]
					 , '--Review the returned volumes to determine if space can be cleared or when a volume should be replaced.' AS [DriveLetter]
					 , NULL AS [TotalSpaceInGB]
					 , NULL AS [PercentUsed]
				UNION
				Select *
				From dba.History.DiskUseLog
				Where RunTime > @start AND PercentUsed > 65
				*/
				SELECT * FROM dba.History.DiskUseLog
				INNER JOIN dba.History.Disks
				ON dba.History.DiskUseLog.DiskID = dba.History.Disks.DiskID
				INNER JOIN dba.History.Servers
				ON dba.History.Disks.ServerID = dba.History.Servers.ServerID
			END TRY
			BEGIN CATCH
				SELECT '***DRIVE SPACE CHECK***' [ErrorMessage]
					 , '--Review the returned volumes to determine if space can be cleared or when a volume should be replaced.' AS [ErrorMessage]
				 UNION
				SELECT '******ERROR******'AS [ErrorMessage]
					 , 'ERROR: ' + ERROR_MESSAGE() + '  Located on line: ' + CONVERT(varchar(5), ERROR_LINE()) AS ErrorMessage;
			END CATCH
		END
*/
			BEGIN /*TIME OFFSET CHECK*/
				BEGIN TRY
					IF OBJECT_ID('tempdb..##sysOffset') IS NOT NULL
						BEGIN
							DROP TABLE ##sysOffset;
						END;

					SET @file_exists = NULL;

					EXEC master.sys.xp_fileexist 'C:\scripts\Maintenance\DailyChecks\CheckSysOffset.ps1',
						@file_exists OUTPUT;

					IF ( @file_exists <> 1 )
						BEGIN
							RAISERROR ('Powershell file to check server settings does not exist (C:\scripts\Maintenance\DailyChecks\CheckSysOffset.ps1)', 16, 1);
							RETURN;
						END;

					CREATE TABLE ##sysOffset
						(
							ServerName NVARCHAR(100),
							Offset NVARCHAR(25)
						);

					EXEC sys.xp_cmdshell 'powershell.exe -Command "& C:\scripts\Maintenance\DailyChecks\CheckSysOffset.ps1"',
						no_output;

					SELECT	'***TIME OFFSET CHECK***' ServerName,
							'--Make sure that the Offset is correct and the same across all servers' Offset
					UNION
					SELECT	*
					FROM	##sysOffset;
				END TRY
				BEGIN CATCH
					SELECT	'***TIME OFFSET CHECK***' ServerName,
							'--Make sure that the Offset is correct and the same across all servers' Offset
					UNION
					SELECT	'******ERROR******' AS ServerName,
							'ERROR: ' + ERROR_MESSAGE() + '  Located on line: '
							+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage;
				END CATCH;
			END;
		END;
END;
/*
---------------
|Backup Checks|
---------------
Backups On Disk
Snapshots ##refactor##
*/
IF EXISTS ( SELECT	*
			FROM	#ServerNamesTable
			WHERE	LOWER(@@SERVERNAME) = ServerName )
	BEGIN
		BEGIN /*BACKUP CHECKS*/
			IF @backupFilesCheck = 'Y'
				BEGIN
					BEGIN /*BACKUPS ON DISK CHECK*/
						BEGIN TRY
							IF OBJECT_ID('tempdb..#fileResults') IS NOT NULL
								BEGIN
									DROP TABLE #fileResults;
								END;
							IF OBJECT_ID('tempdb..#backupInfo') IS NOT NULL
								BEGIN
									DROP TABLE #backupInfo;
								END;
							CREATE TABLE #backupInfo
								(
									name VARCHAR(10),
									abbrev NVARCHAR(1),
									numDays INT
								);
							INSERT	INTO #backupInfo
							VALUES	( 'FULL', 'D', 7 )
													,
									( 'DIFF', 'I', 3 )
													,
									( 'LOG', 'L', 1 );

							CREATE TABLE #fileResults
								(
									fileID INT IDENTITY(1, 1),
									file_name NVARCHAR(4000),
									file_exists BIT,
									backup_start_date DATETIME,
									backup_finish_date DATETIME,
									backup_type VARCHAR(4)
								);

							WHILE EXISTS ( SELECT TOP 1
													*
											FROM	#backupInfo )
								BEGIN
									DECLARE	@backupName VARCHAR(10),
										@type VARCHAR(1),
										@numDays INT;

									SELECT TOP 1
											@backupName = name,
											@type = abbrev,
											@numDays = numDays
									FROM	#backupInfo;
									IF EXISTS ( SELECT TOP 1
														*
												FROM	#fileResults )
										BEGIN
											--Yes, I want to wipe the table.
											DELETE	FROM #fileResults;
										END;
									INSERT	INTO #fileResults
											(
												file_name,
												file_exists,
												backup_start_date,
												backup_finish_date,
												backup_type
											)
									SELECT	mf.physical_device_name,
											NULL AS file_exists,
											bs.backup_start_date,
											bs.backup_finish_date,
											@backupName AS Backup_Type
									FROM	msdb.dbo.backupset bs
									INNER JOIN msdb.dbo.backupmediaset ms
											ON bs.media_set_id = ms.media_set_id
									INNER JOIN msdb.dbo.backupmediafamily mf
											ON bs.media_set_id = mf.media_set_id
									WHERE	bs.type = @type
											AND bs.backup_start_date >= DATEADD(d,
																-1 * @numDays,
																GETDATE());

									WHILE EXISTS ( SELECT	1
													FROM	#fileResults
													WHERE	file_exists IS NULL )
										BEGIN
											DECLARE	@physical_device_name NVARCHAR(4000),
												@ID INT,
												@result INT;
											SELECT TOP 1
													@physical_device_name = file_name,
													@ID = fileID
											FROM	#fileResults
											WHERE	file_exists IS NULL;

											EXEC master.sys.xp_fileexist @physical_device_name,
												@result OUTPUT;

											IF ( @result = 0 )
												BEGIN
													UPDATE	#fileResults
													SET		file_exists = @result
													WHERE	fileID = @ID;
												END;
											ELSE
												BEGIN
													DELETE	FROM #fileResults
													WHERE	fileID = @ID;
												END;
										END;

									SELECT	'***' + @backupName
											+ ' BACKUP FILES CHECK***' AS [Location of Missing Backup Files],
											'**********' AS backup_type,
											NULL AS backup_start_date,
											NULL AS backup_finish_date
									UNION
									SELECT	file_name AS [Location of Missing Backup Files],
											backup_type,
											backup_start_date,
											backup_finish_date
									FROM	#fileResults
									WHERE	file_exists = 0
									ORDER BY backup_type,
											backup_start_date DESC;

									DELETE	FROM #backupInfo
									WHERE	@backupName = name;
								END;
							DROP TABLE #fileResults;
						END TRY
						BEGIN CATCH
							SELECT	'***BACKUP FILES CHECK***' AS [Location of Missing Backup Files],
									'**********' AS backup_type,
									NULL AS backup_start_date,
									NULL AS backup_finish_date
							UNION
							SELECT	'******ERROR******' AS [Location of Missing Backup Files],
									'ERROR: ' + ERROR_MESSAGE()
									+ '  Located on line: '
									+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage,
									NULL AS backup_start_date,
									NULL AS backup_finish_date;
						END CATCH;
					END;
				END;
			ELSE
				BEGIN
					SELECT	'***BACKUP FILES CHECK***' AS [Location of Missing Backup Files],
							'**********' AS backup_type
					UNION
					SELECT	'****SKIPPED BACKUP FILES CHECK****' AS [Location of Missing Backup Files],
							'****USER REQUESTED****' AS backup_type;
				END;


			IF @snapshotsCheck = 'Y'
			BEGIN /* Re-writing this portion to use the snapshot table instead of running the script for each check. Commenting out until completed. */
				BEGIN /*SNAPSHOTS CHECK*/
					BEGIN TRY
						EXEC master.dbo.xp_fileexist 'C:\scripts\Maintenance\DailyChecks\QuerySnapshots.ps1', @file_exists OUTPUT

						IF (@file_exists <> 1)
						BEGIN
							RAISERROR ('Powershell file to query snapshots does not exist (C:\scripts\Maintenance\DailyChecks\QuerySnapshots.ps1)', 16, 1)
							RETURN
						END

						IF NOT EXISTS (SELECT 1 FROM CODBAProcedures.sys.objects so WHERE so.name = 'ParseSnapshotInfo' AND so.type = 'TF')
						BEGIN
							RAISERROR ('User Defined Function needed to parse snapshot info does not exist (CODBAProcedures.dbo.ParseSnapshotInfo)', 16, 1)
							RETURN
						END

						DECLARE
							@CONST_DAYS_TO_CHECK int = 5
						DECLARE
							@begin_date date = dateadd(d, @CONST_DAYS_TO_CHECK * -1, getdate())

						IF OBJECT_ID('tempdb..#expected_snaps') IS NOT NULL
						BEGIN
							DROP TABLE #expected_snaps;
						END;
						CREATE TABLE
							#expected_snaps (snap_type varchar(4), week_day varchar(9), start_time time, end_time time);
						WITH days_of_week AS (
							SELECT 'Monday' AS week_day
							UNION ALL SELECT 'Tuesday'
							UNION ALL SELECT 'Wednesday'
							UNION ALL SELECT 'Thursday'
							UNION ALL SELECT 'Friday'
							UNION ALL SELECT 'Saturday'
							UNION ALL SELECT 'Sunday'
						),
						schedule_diff as (
							SELECT '00:00:00' start_time, '05:59:59' end_time
						),
						schedule_log as (
							SELECT '00:00:00' start_time, '00:59:59' end_time
							 UNION ALL SELECT '01:00:00', '01:59:59'
							 UNION ALL SELECT '02:00:00', '02:59:59'
							 UNION ALL SELECT '03:00:00', '03:59:59'
							 UNION ALL SELECT '04:00:00', '04:59:59'
							 UNION ALL SELECT '05:00:00', '05:59:59'
							 UNION ALL SELECT '06:00:00', '06:59:59'
							 UNION ALL SELECT '07:00:00', '07:59:59'
							 UNION ALL SELECT '08:00:00', '08:59:59'
							 UNION ALL SELECT '09:00:00', '09:59:59'
							 UNION ALL SELECT '10:00:00', '10:59:59'
							 UNION ALL SELECT '11:00:00', '11:59:59'
							 UNION ALL SELECT '12:00:00', '12:59:59'
							 UNION ALL SELECT '13:00:00', '13:59:59'
							 UNION ALL SELECT '14:00:00', '14:59:59'
							 UNION ALL SELECT '15:00:00', '15:59:59'
							 UNION ALL SELECT '16:00:00', '16:59:59'
							 UNION ALL SELECT '17:00:00', '17:59:59'
							 UNION ALL SELECT '18:00:00', '18:59:59'
							 UNION ALL SELECT '19:00:00', '19:59:59'
							 UNION ALL SELECT '20:00:00', '20:59:59'
							 UNION ALL SELECT '21:00:00', '21:59:59'
							 UNION ALL SELECT '22:00:00', '22:59:59'
							 UNION ALL SELECT '23:00:00', '23:59:59'
						)

						INSERT INTO
							#expected_snaps (snap_type, week_day, start_time, end_time)
						SELECT
							'FULL', 'Sunday', '00:00:00', '23:59:59'

						CREATE TABLE
							#output (output_text nvarchar(4000)
						)

						INSERT INTO
							#output(output_text)
						EXEC xp_cmdshell 'powershell.exe -Command "& C:\scripts\Maintenance\DailyChecks\QuerySnapshots.ps1"'

						SELECT
							parsed.*,
						CASE WHEN
							parsed.snapshot_name LIKE '%-FULL' THEN 'FULL'
						WHEN
							parsed.snapshot_name LIKE '%-DIFF' THEN 'DIFF'
						WHEN
							parsed.snapshot_name LIKE '%-LOG' THEN 'LOG' END snap_type,
						datename(dw, snapshot_date) week_day
						INTO
							#snaps
						FROM
							#output o
						CROSS APPLY
							CODBAProcedures.dbo.ParseSnapshotInfo(o.output_text) parsed
						WHERE
							output_text IS NOT NULL
						ORDER BY
							snapshot_name, snapshot_date DESC;
						WITH
							days_to_check as (
							SELECT
								cast (DATEADD (day, s.number, @begin_date)AS date) date_value,
								DATENAME(dw, cast (DATEADD (day, s.number, @begin_date)AS date)) week_day
							FROM
								master.dbo.spt_values s
							 WHERE
								type = 'P'
							 AND
								CAST (DATEADD (day, s.number, @begin_date)as date) <= getdate()
						)
						SELECT
							cast(snapshot_date AS date) snap_date,
							week_day,
							snap_type,
							count(snapshot_id) #snapshots
						FROM
							#snaps
						WHERE
							cast(snapshot_date AS date) > dateadd(d, -1 * @CONST_DAYS_TO_CHECK, cast(getdate() AS date))
						GROUP BY
							cast(snapshot_date AS date),
							week_day,
							snap_type
						ORDER BY 3, 1

						DROP TABLE #snaps
						DROP TABLE #output
						DROP TABLE #expected_snaps

					END TRY
					BEGIN CATCH
						SELECT	'***SNAPSHOT QUERY***' AS [Daily Check Section]
							,	'ERROR: ' + ERROR_MESSAGE() + '  Located on line: ' + CONVERT(varchar(5), ERROR_LINE()) AS ErrorMessage;
					END CATCH
				END
			END
			ELSE
			BEGIN
				SELECT	'***SNAPSHOT QUERY***' AS [Daily Check Section]
					,	'**********' AS [Message]
				UNION
				SELECT	'****SKIPPED SNAPSHOT QUERY****' AS [Daily Check Section]
					,	'****USER REQUESTED****' AS [Message];
			END
/*
---------------------
|Begin Drive Space % usage|
---------------------
Checks to see if the drive space is more than 75% used
*/
			IF EXISTS ( SELECT	*
						FROM	#ServerNamesTable
						WHERE	LOWER(@@SERVERNAME) = ServerName )
				BEGIN
					BEGIN /*Primary Check*/
						IF SERVERPROPERTY('IsHadrEnabled') = 1
							BEGIN
						BEGIN /*Drive space CHECK*/
							BEGIN  TRY
							IF EXISTS (SELECT * FROM dba.sys.views
								WHERE NAME = 'vw_DiskUseLog')
								BEGIN
								SELECT	'***DISK USAGE CHECK***' Name,
										NULL DriveLetter,
										NULL UpdateTime,
										'--Disk drives should be checked if used space is above 75%.' DriveLabel,
										NULL TotalSpaceInGB,
										NULL UsedSpaceInGB,
										NULL PercentUsed
								UNION
								SELECT *
									FROM dba.History.vw_DiskUseLog
									WHERE PercentUsed > 75
								END
							END TRY
							BEGIN CATCH
								SELECT	'***DISK USAGE CHECK***' Name,
										NULL DriveLetter,
										NULL UpdateTime,
										'--Disk drives should be checked if used space is above 75%.' DriveLabel,
										NULL TotalSpaceInGB,
										NULL UsedSpaceInGB,
										NULL PercentUsed
								UNION
								SELECT	'******ERROR******' AS Name,
										NULL DriveLetter,
										NULL UpdateTime,
								'ERROR: ' + ERROR_MESSAGE()
								+ '  Located on line: '
								+ CONVERT(VARCHAR(5), ERROR_LINE()) AS ErrorMessage,
										NULL TotalSpaceInGB,
										NULL UsedSpaceInGB,
										NULL PercentUsed;
							END CATCH;
								END;
							END;
						END;
					END;
/*
---------------------
|Begin settings check|
---------------------
Checks for changes in the dba.History.SQLSettingsLog table
*/
			IF EXISTS ( SELECT	*
						FROM	#ServerNamesTable
						WHERE	LOWER(@@SERVERNAME) = ServerName )
				BEGIN
					BEGIN /*Primary Check*/
						IF SERVERPROPERTY('IsHadrEnabled') = 1
							BEGIN
						BEGIN /*SETTINGS CHANGE CHECK*/
							BEGIN
								WITH x AS
								 (SELECT *, rn=ROW_NUMBER() OVER (ORDER BY HistoryUpdateTime)
								 FROM dba.[History].[SQLSettingsLog]
								 )
								 SELECT  x.[ServerID]
									  ,a.Name
									  ,x.[HistoryUpdateTime]
									  ,x.[SQLVersion]

								 FROM  x
								 LEFT OUTER JOIN x b
								 ON x.rn = b.rn + 1
								 and x.SQLVersion  <> b.SQLVersion
								 and x.ServerID = b.ServerID
								 JOIN dba.History.Servers a ON a.ServerID = x.ServerID
								 WHERE b.SQLVersion is not null
								 ;

							WITH x AS
								 (SELECT *, rn=ROW_NUMBER() OVER (ORDER BY HistoryUpdateTime)
								 FROM dba.[History].[SQLSettingsLog]
								 )
								 SELECT  x.[ServerID]
										,a.Name
										,x.[HistoryUpdateTime]
										,x.[MaxDOP]

								 FROM  x
								 LEFT OUTER JOIN x b
								 ON x.rn = b.rn + 1
								 and x.[MaxDOP]  <> b.[MaxDOP]
								 and x.ServerID = b.ServerID
								 JOIN dba.History.Servers a ON a.ServerID = x.ServerID
								 WHERE b.[MaxDOP] is not null
								;

							 WITH x AS
								 (SELECT *, rn=ROW_NUMBER() OVER (ORDER BY HistoryUpdateTime)
								 FROM dba.[History].[SQLSettingsLog]
								 )
								 SELECT  x.[ServerID]
										,a.Name
										,x.[HistoryUpdateTime]
										,x.Collation

								 FROM  x
								 LEFT OUTER JOIN x b
								 ON x.rn = b.rn + 1
								 and x.Collation  <> b.Collation
								 and x.ServerID = b.ServerID
								 JOIN dba.History.Servers a ON a.ServerID = x.ServerID
								 WHERE b.Collation is not null
								;

							 WITH x AS
								 (SELECT *, rn=ROW_NUMBER() OVER (ORDER BY HistoryUpdateTime)
								 FROM dba.[History].[SQLSettingsLog]
								 )
								 SELECT  x.[ServerID]
										,a.Name
										,x.[HistoryUpdateTime]
										,x.CostThresholdForParallelism

								 FROM  x
								 LEFT OUTER JOIN x b
								 ON x.rn = b.rn + 1
								 and x.CostThresholdForParallelism  <> b.CostThresholdForParallelism
								 and x.ServerID = b.ServerID
								 JOIN dba.History.Servers a ON a.ServerID = x.ServerID
								 WHERE b.CostThresholdForParallelism is not null

							END;

						END;
					END;
				END;
			END;
/*End of settings check section*/
		END;
	END;
DROP TABLE #ServerNamesTable;
