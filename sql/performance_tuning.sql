exec dba.dbo.usp_whoisactive @get_plans = 2
                           , @output_column_list = '[dd%][session_id][blocking_session_id][wait_info][database_name][login_name][host_name][sql_text][query_plan][CPU][tempdb_allocations][tempdb_current][reads][physical_reads][writes]'

exec dba.dbo.sp_Blitz @CheckProcedureCache = 1

exec dba.dbo.sp_AskBrent @ExpertMode = 1, @Seconds = 60

exec dba.dbo.sp_BlitzCache

exec dba.dbo.sp_BlitzIndex
