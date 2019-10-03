@ECHO OFF
IF "%1"=="" GOTO USAGE
SET db_name=%1
SET db_user=%db_name%_USER
CALL settings.cmd
@ECHO ON
@IF NOT EXIST %db_log_path% ( MKDIR %db_log_path% && ECHO %db_log_path% created)
@IF NOT EXIST %db_table_path% ( MKDIR %db_table_path% && ECHO %db_table_path% created)
@IF NOT EXIST %db_index_path% ( MKDIR %db_index_path% && ECHO %db_index_path% created)
@SQLCMD -U %db_sa_user% -P %db_sa_password% -i sql\create_tenant_database.sql
@ECHO Database %db_name% created
@SQLCMD -U %db_sa_user% -P %db_sa_password% -i sql\create_user.sql
@ECHO Login %db_user% created
@GOTO DONE
:USAGE
@ECHO Usage: create_tenant_database_and_user ^<database name^>
:DONE