@ECHO OFF
IF "%1"=="" GOTO USAGE
SET db_name=%1
SET db_user=%db_name%_USER
call settings.cmd
SQLCMD -U %db_sa_user% -P %db_sa_password% -S %db_address% -i sql\drop_database_and_user.sql
@ECHO ON
@ECHO Login %db_user% deleted
@ECHO Database %db_name% deleted
@IF EXIST %db_log_path% ( RMDIR %db_log_path% && ECHO Directory %db_log_path% deleted)
@IF EXIST %db_table_path% ( RMDIR %db_table_path% && ECHO Directory %db_table_path% deleted)
@IF EXIST %db_index_path% ( RMDIR %db_index_path% && ECHO Directory %db_index_path% deleted)
@GOTO DONE
:USAGE
@ECHO Usage: drop_database_and_user ^<database name^>
:DONE




