/*
   input:
   db_name - database name
   db_log_path - location where log files will be stored	
   fnd_tmvxprim01_size - size of primary database log file
   fnd_tmvxtranl_size - size of transaction log file
   db_table_path - location where database files will be stored
   fnd_tmvxsd01_size - size of database file 1
   db_index_path - location where database indexes will be stored
   fnd_tmvxsi01_size - size of database indexes file 1
   db_collation - specifies the collation for the database
*/
if not exists (select name from sys.databases where name = '$(db_name)') 
begin
	create database $(db_name) 
	on 
	PRIMARY
	( name =TMVXPRIM01
	, filename = '$(db_log_path)\TMVXPRIM01_MDF'
	, size = $(fnd_tmvxprim01_size) MB
	, maxsize = UNLIMITED
	, filegrowth = 256 MB
	),
	filegroup TMVXSD
	( name =TMVXSD01
	, filename = '$(db_table_path)\TMVXSD01_NDF'
	, size = $(fnd_tmvxsd01_size) MB
	, maxsize = UNLIMITED
	, filegrowth = 128 MB
	),
	filegroup TMVXSI
	( name =TMVXSI01
	, filename = '$(db_index_path)\TMVXSI01_NDF'
	, size = $(fnd_tmvxsi01_size) MB
	, maxsize = UNLIMITED
	, filegrowth = 128 MB
	),
	log on
	( name =TMVXTRANL
	, filename = '$(db_log_path)\TMVXTRANL_LDF'
	, size = $(fnd_tmvxtranl_size) MB
	, maxsize = UNLIMITED
	, filegrowth = 256 MB
	)
	collate $(db_collation)
	alter database $(db_name) modify filegroup TMVXSD default
	alter database $(db_name) set DB_CHAINING off, TRUSTWORTHY off
end
