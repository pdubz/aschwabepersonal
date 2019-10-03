SELECT harcs.replica_server_name
     , db.name
     , db.state_desc
     , hdrs.synchronization_state_desc
  FROM master.sys.databases db
 INNER JOIN master.sys.dm_hadr_database_replica_states hdrs
    ON db.database_id = hdrs.database_id
 INNER JOIN master.sys.dm_hadr_availability_replica_cluster_states harcs
    ON harcs.replica_id = hdrs.replica_id
 WHERE hdrs.synchronization_state <> 2

     