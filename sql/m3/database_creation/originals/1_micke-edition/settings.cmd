@ECHO OFF

SET db_sa_user=sa
SET db_sa_password=Windsor666
::SET db_address=.\SQLEXPRESS
::SET db_log_path=D:\SQLLogs\%db_name%
SET db_log_path=D:\data01\logs\
::SET db_table_path=D:\SQLData\%db_name%
SET db_table_path=D:\data01\data\
::SET db_index_path=D:\SQLIndexes\%db_name%
SET db_index_path=D:\data01\data\
SET db_collation=Latin1_General_BIN

::Foundation database sizing
SET fnd_tmvxprim01_size=256
SET fnd_tmvxsd01_size=128
SET fnd_tmvxsi01_size=128
SET fnd_tmvxtranl_size=512

::Small Tenant database sizing
SET tenant_tmvxprim01_size=256
SET tenant_tmvxsd01_size=128
SET tenant_tmvxsi01_size=128
SET tenant_tmvxrunt01_size=128
SET tenant_tmvxarch01_size=16
SET tenant_tmvxtemp01_size=16
SET tenant_tmvxtranl_size=512

::Large Tenant database sizing
::SET tenant_tmvxprim01_size=256
::SET tenant_tmvxsd01_size=1536
::SET tenant_tmvxsi01_size=1536
::SET tenant_tmvxsd02_size=1536
::SET tenant_tmvxsi02_size=1536
::SET tenant_tmvxsd03_size=1536
::SET tenant_tmvxsi03_size=1536
::SET tenant_tmvxrunt01_size=1536
::SET tenant_tmvxarch01_size=16
::SET tenant_tmvxtemp01_size=16
::SET tenant_tmvxtranl_size=8192

@ECHO ON
