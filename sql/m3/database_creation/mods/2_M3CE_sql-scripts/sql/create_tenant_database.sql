/*
   input:
   db_name - database name
   db_log_path - location where log files will be stored
   tenant_tmvxprim01_size - size of primary database log file
   tenant_tmvxtranl_size - size of transaction log file
   db_table_path - location where database files will be stored
   tenant_tmvxsd01_size - size of database file 1
   tenant_tmvxrunt01_size - size of runtime created database file 1
   tenant_tmvxarch01_size - size of archiving database file 1
   db_index_path - location where database indexes will be stored
   tenant_tmvxsi01_size  - size of database indexes file 1
   tenant_tmvxtemp01_size   - size of temporary database indexes
   db_collation - specifies the collation for the database
*/
if not exists (select name from sys.databases where name = '$(db_name)') 
begin
	create database $(db_name) 
	on 
	PRIMARY
	( name =TMVXPRIM01
	, filename = '$(db_log_path)\TMVXPRIM01_MDF'
	, size = $(tenant_tmvxprim01_size) MB
	, maxsize = UNLIMITED
	, filegrowth = 256 MB
	),
	filegroup TMVXSD
	( name =TMVXSD01
	, filename = '$(db_table_path)\TMVXSD01_NDF'
	, size = $(tenant_tmvxsd01_size) MB
	, maxsize = UNLIMITED
	, filegrowth = 128 MB
	),
	filegroup TMVXSI
	( name =TMVXSI01
	, filename = '$(db_index_path)\TMVXSI01_NDF'
	, size = $(tenant_tmvxsi01_size) MB
	, maxsize = UNLIMITED
	, filegrowth = 128 MB
	),
	filegroup TMVXRUNT
	( name =TMVXRUNT01
	, filename = '$(db_table_path)\TMVXRUNT01_NDF'
	, size = $(tenant_tmvxrunt01_size) MB
	, maxsize = UNLIMITED
	, filegrowth = 128 MB
	),
	filegroup TMVXARCH
	( name =TMVXARCH01
	, filename = '$(db_table_path)\TMVXARCH01_NDF'
	, size = $(tenant_tmvxarch01_size) MB
	, maxsize = UNLIMITED
	, filegrowth = 128 MB
	),
	filegroup TMVXTEMP
	( name =TMVXTEMP01
	, filename = '$(db_index_path)\TMVXTEMP01_NDF'
	, size = $(tenant_tmvxtemp01_size) MB
	, maxsize = UNLIMITED
	, filegrowth = 128 MB
	)
	log on
	( name =TMVXTRANL
	, filename = '$(db_log_path)\TMVXTRANL_LDF'
	, size = $(tenant_tmvxtranl_size) MB
	, maxsize = UNLIMITED
	, filegrowth = 256 MB
	)
	collate $(db_collation)
	alter database $(db_name) modify filegroup TMVXTEMP default
	alter database $(db_name) set DB_CHAINING off, TRUSTWORTHY off
end
