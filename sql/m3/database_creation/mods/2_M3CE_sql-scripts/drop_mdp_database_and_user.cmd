@ECHO OFF
IF "%1"=="" GOTO USAGE_SPACE
SET space_name=%1
SET db_name=%space_name%MDP
SET db_user=u%db_name%_USER
call settings.cmd
SQLCMD -U %db_sa_user% -P %db_sa_password% -S %db_address% -i sql\drop_mdp_database_and_user.sql
@ECHO OFF
IF ERRORLEVEL 1 goto DONE
@ECHO ON
@ECHO Login %db_user% and Schema %db_schame% deleted
@ECHO Database %db_name% deleted
@IF EXIST %db_log_path% ( RMDIR %db_log_path% && ECHO Directory %db_log_path% deleted)
@IF EXIST %db_table_path% ( RMDIR %db_table_path% && ECHO Directory %db_table_path% deleted)
@IF EXIST %db_index_path% ( RMDIR %db_index_path% && ECHO Directory %db_index_path% deleted)
@GOTO DONE
:USAGE_DB
@ECHO Usage: drop_database_and_user ^<space name^>
:DONE




