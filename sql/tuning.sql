exec dba.dbo.usp_whoisactive @get_plans = 2
                           , @output_column_list = '[dd%][session_id][blocking_session_id][wait_info][database_name][login_name][host_name][sql_text][query_plan][CPU][tempdb_allocations][tempdb_current][reads][physical_reads][writes]'

exec dba.dbo.sp_Blitz @CheckUserDatabaseObjects = 1
                    , @CheckProcedureCache = 1 
                    , @CheckServerInfo = 1
