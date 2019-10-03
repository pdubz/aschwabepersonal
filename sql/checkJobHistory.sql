SELECT b.name
     , a.job_id
     , a.run_date
     , COUNT(*) NumberofRun 
  FROM msdb.dbo.sysjobhistory a
 INNER JOIN msdb.dbo.sysjobs b
    ON a.job_id = b.job_id
 GROUP BY a.job_id
        , b.name
        , run_date
 ORDER BY NumberofRun DESC
