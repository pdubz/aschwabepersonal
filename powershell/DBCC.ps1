
Import-Module C:\salt\scripts\modules\InforSQL\InforSQL.psm1 -DisableNameChecking
Import-Module SQLPS -DisableNameChecking

$Primary = SQLAG-GetPrimary
$Secondaries = SQLAG-GetSecondaries

$CreateTable = @"
IF NOT EXISTS ( SELECT 1
                  FROM dba.sys.objects so
                  JOIN dba.sys.schemas ss
                    ON so.schema_id = ss.schema_id
                 WHERE ss.name = 'dbo'
                   AND so.name = 'DBCCCheckDBHistory') 
BEGIN
      CREATE TABLE dba.dbo.DBCCCheckDBHistory ( [RowID] INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
                                              , [StartDateTimeUTC] DATETIME2
                                              , [CompleteDateTimeUTC] DATETIME2
                                              , [ServerName] NVARCHAR(180)
                                              , [DBName] NVARCHAR(180)
                                              , [DBSizeGB] DECIMAL
                                              , [Error] INT 
                                              , [Level] INT 
                                              , [State] INT 
                                              , [MessageText] NVARCHAR(2048) 
                                              , [RepairLevel] NVARCHAR(22) 
                                              , [Status] INT 
                                              , [dbid] INT 
                                              , [DbFragId] INT 
                                              , [ObjectId] INT 
                                              , [IndexId] INT 
                                              , [PartitionId] BIGINT 
                                              , [AllocUnitId] BIGINT 
                                              , [Riddbid] SMALLINT 
                                              , [RidPruId] SMALLINT 
                                              , [File] SMALLINT 
                                              , [Page] INT 
                                              , [Slot] INT 
                                              , [Refdbid] SMALLINT 
                                              , [RefPruId] SMALLINT 
                                              , [RefFile] SMALLINT 
                                              , [RefPage] INT 
                                              , [RefSlot] INT 
                                              , [Allocation] SMALLINT 
                                              , [Outcome] INT
                                              ) ;
END
"@
$test = @"
    IF EXISTS ( SELECT 1                  FROM tempdb.sys.objects so                  JOIN tempdb.sys.schemas ss                    ON so.schema_id = ss.schema_id                 WHERE ss.name = 'dbo'                   AND so.object_id = OBJECT_ID ( 'tempdb.dbo.#DBCCOutput' ) )
       BEGIN
             DROP TABLE tempdb.dbo.#DBCCOutput
       END
CREATE TABLE #DBCCOutput ( [Error] INT 
                         , [Level] INT 
                         , [State] INT 
                         , [MessageText] NVARCHAR(2048) 
                         , [RepairLevel] NVARCHAR(22) 
                         , [Status] INT 
                         , [dbid] INT 
                         , [DbFragId] INT 
                         , [ObjectId] INT 
                         , [IndexId] INT 
                         , [PartitionId] BIGINT 
                         , [AllocUnitId] BIGINT 
                         , [Riddbid] SMALLINT 
                         , [RidPruId] SMALLINT 
                         , [File] SMALLINT 
                         , [Page] INT 
                         , [Slot] INT 
                         , [Refdbid] SMALLINT 
                         , [RefPruId] SMALLINT 
                         , [RefFile] SMALLINT 
                         , [RefPage] INT 
                         , [RefSlot] INT 
                         , [Allocation] SMALLINT 
                         , [Outcome] AS CASE WHEN Error = 8989 AND MessageText LIKE '%0 allocation errors and 0 consistency errors%' THEN 0 
                                             WHEN Error <> 8989 THEN NULL
                                             ELSE 1 
                                         END
                         ) ;


"@

$RunDBCCCheckDB = @"


"@

Invoke-Sqlcmd -Query $CreateTable -ServerInstance $Primary -Database 'dba'
 




#check AG databases on primary
#check non AG databases on primary
#check non AG databases on each secondary
#email where outcome = 1
#Do not email on success
#log to process log
