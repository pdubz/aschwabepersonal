/*
   input:
   db_name - database name
   db_log_path - location where log files will be stored	
   fnd_tmvxprim01_size - size of primary database log file
   fnd_tmvxtranl_size - size of transaction log file
   db_table_path - location where database files will be stored
   fnd_tmvxsd01_size - size of database file 1
   fnd_tmvxsd02_size - size of database file 2
   fnd_tmvxsd03_size - size of database file 3
   db_index_path - location where database indexes will be stored
   fnd_tmvxsi01_size - size of database indexes file 1
   fnd_tmvxsi02_size - size of database indexes file 2
   fnd_tmvxsi03_size - size of database indexes file 3
   db_collation - specifies the collation for the database
*/
if not exists (select name from sys.databases where name = '$(db_name)') 
begin
	create database $(db_name) 
	collate $(db_collation)
	alter database $(db_name) set DB_CHAINING off, TRUSTWORTHY off
end
