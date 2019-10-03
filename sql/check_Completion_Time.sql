SELECT session_id as SPID
	 , command
	 , aa.text AS Query
	 , start_time
	 , percent_complete
	 , dateadd(second,estimated_completion_time/1000, getdate()) as estimated_completion_time
	 , datediff(n, getdate(), dateadd(second,estimated_completion_time/1000, getdate())) Minutes_Until_Completion
  FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) aa
 WHERE r.command in('BACKUP DATABASE','RESTORE DATABASE', 'BACKUP LOG') 
