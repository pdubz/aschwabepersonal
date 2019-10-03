SELECT
	a.job_id AS 'Job ID',
	j.name AS 'Job Name',
	a.start_execution_date AS 'Start Date',
	GETDATE() AS 'Current Date',
	s.step_name AS 'Step Name',
	DATEDIFF(minute, a.start_execution_date, GETDATE()) AS 'Run Time (Mins)'
FROM msdb.dbo.sysjobactivity a
	JOIN msdb.dbo.sysjobs j ON a.job_id = j.job_id
		JOIN msdb.dbo.sysjobsteps s ON a.job_id = s.job_id 
WHERE a.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
	AND start_execution_date is not null
		AND stop_execution_date is null
			AND ISNULL(a.last_executed_step_id, 0) + 1 = s.step_id
				AND (DATEDIFF(minute, a.start_execution_date, GETDATE()) > 720);
