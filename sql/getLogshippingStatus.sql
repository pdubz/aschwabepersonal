SELECT ls.primary_server
     , lms.secondary_server
     , ls.primary_database
     , lsd.restore_delay
     , DATEDIFF( MINUTE
               , lms.last_restored_date
               , getdate() ) AS time_since_last_restore
     , lms.last_restored_date
     , lms.last_restored_file
     , lms.last_copied_file
     , lms.last_copied_date
     , ls.backup_source_directory
     , ls.backup_destination_directory
     , ls.monitor_server
  FROM msdb.dbo.log_shipping_secondary ls
  JOIN msdb.dbo.log_shipping_secondary_databases lsd
    ON lsd.secondary_id=ls.secondary_id
  JOIN msdb.dbo.log_shipping_monitor_secondary lms
    ON lms.secondary_id=lsd.secondary_id 
 WHERE DATEDIFF( MINUTE
               , lms.last_restored_date
               , getdate() ) > 60
 ORDER BY time_since_last_restore DESC