SELECT db.name
     , dek.encryption_state
     , dek.percent_complete
     , dek.encryptor_thumbprint
  FROM master.sys.dm_database_encryption_keys dek
 INNER JOIN master.sys.databases db
    ON dek.database_id = db.database_id
 WHERE dek.encryption_state <> 3   
