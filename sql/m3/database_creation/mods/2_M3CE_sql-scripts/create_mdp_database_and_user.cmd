@ECHO OFF
IF "%1"=="" GOTO USAGE_SPACE
SET space_name=%1
SET db_name=%space_name%MDP
SET db_schema=%db_name%_SCHEMA
SET db_user=u%db_name%_USER
CALL settings.cmd
@ECHO ON
@IF NOT EXIST %db_log_path% ( MKDIR %db_log_path% && ECHO Directory %db_log_path% created)
@IF NOT EXIST %db_table_path% ( MKDIR %db_table_path% && ECHO Directory %db_table_path% created)
@IF NOT EXIST %db_index_path% ( MKDIR %db_index_path% && ECHO Directory %db_index_path% created)
@SQLCMD -U %db_sa_user% -P %db_sa_password% -S %db_address% -i sql\create_mdp_database.sql
@ECHO OFF
IF ERRORLEVEL 1 goto DONE
@ECHO ON
@ECHO Database %db_name% created
@SQLCMD -U %db_sa_user% -P %db_sa_password% -S %db_address% -i sql\create_mdp_user.sql
@ECHO OFF
IF ERRORLEVEL 1 goto DONE
@ECHO ON
@ECHO Login %db_user% and SCHEMA %db_schema% created
@GOTO DONE
:USAGE_SPACE
@ECHO Usage: create_mdp_database_and_user ^<space name^>
:DONE