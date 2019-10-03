DECLARE @outputType                        varchar(50) = 'table'
      , @outputDB                          varchar(50) = 'dba'
      , @outputSchema                      varchar(50) = 'dbo'
      , @exceptionChecksTable              varchar(50) = 'blitz_exceptions'
      , @outputBlitzResults                varchar(50) = 'blitz_results'
      , @outputAskBrentResults             varchar(50) = 'askBrent_results'
      , @outputAskBrentFileStatsResults    varchar(50) = 'askBrent_FileStats_results'
      , @outputAskBrentPerfmonStatsResults varchar(50) = 'askBrent_PerfmonStats_results'
      , @outputAskBrentWaitStatsResults    varchar(50) = 'askBrent_WaitStats_results'
      , @outputBlitzCacheReadsResults      varchar(50) = 'blitzCache_Reads_results'
      , @outputBlitzCacheCPUResults        varchar(50) = 'blitzCache_CPU_results'
      , @outputBlitzCacheExecutionsResults varchar(50) = 'blitzCache_Executions_results'

IF ( NOT EXISTS ( SELECT * 
                    FROM dba.INFORMATION_SCHEMA.TABLES
                   WHERE TABLE_SCHEMA = @outputSchema
                     AND TABLE_NAME   = @exceptionChecksTable ) )
   BEGIN
         CREATE TABLE dba.dbo.blitz_exceptions ( ServerName   NVARCHAR(128)
                                               , DatabaseName NVARCHAR(128)
                                               , CheckID      INT )

         --job owned by user
         INSERT INTO dba.dbo.blitz_exceptions VALUES ( NULL,NULL,'6' )
         --database encrypted
         INSERT INTO dba.dbo.blitz_exceptions VALUES ( NULL,NULL,'21' )
         --enterprise edition in use
         INSERT INTO dba.dbo.blitz_exceptions VALUES ( NULL,NULL,'33' )
         --database owner not SA
         INSERT INTO dba.dbo.blitz_exceptions VALUES ( NULL,NULL,'55' )
     END

EXEC dba.dbo.sp_Blitz @CheckUserDatabaseObjects = 0
                    , @CheckServerInfo          = 1
                    , @SkipChecksDatabase       = @outputDB
                    , @SkipChecksSchema         = @outputSchema
                    , @SkipChecksTable          = @exceptionChecksTable
                    , @OutputType               = @outputType
                    , @OutputDatabaseName       = @outputDB
                    , @OutputSchemaName         = @outputSchema
                    , @OutputTableName          = @outputBlitzResults

EXEC dba.dbo.sp_AskBrent @Seconds                     = 30
                       , @ExpertMode                  = 1
                       , @OutputType                  = @outputType
                       , @OutputDatabaseName          = @outputDB
                       , @OutputSchemaName            = @outputSchema
                       , @OutputTableName             = @outputAskBrentResults

EXEC dba.dbo.sp_BlitzCache @top                  = 20
                         , @sort_order           = 'reads'
                         , @output_database_name = @outputDB
                         , @output_schema_name   = @outputSchema
                         , @output_table_name    = @outputBlitzCacheReadsResults

EXEC dba.dbo.sp_BlitzCache @top                  = 20
                         , @sort_order           = 'cpu'
                         , @output_database_name = @outputDB
                         , @output_schema_name   = @outputSchema
                         , @output_table_name    = @outputBlitzCacheCPUResults

EXEC dba.dbo.sp_BlitzCache @top                  = 20
                         , @sort_order           = 'executions'
                         , @output_database_name = @outputDB
                         , @output_schema_name   = @outputSchema
                         , @output_table_name    = @outputBlitzCacheExecutionsResults
