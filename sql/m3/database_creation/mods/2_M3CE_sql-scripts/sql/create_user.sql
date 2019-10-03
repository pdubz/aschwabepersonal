/*
   input:
   db_name - database name
   db_user - database user
*/
use $(db_name)
if not exists (select * from sys.sql_logins where name = '$(db_user)')
	create login $(db_user) with password = '$(db_user)', check_policy = off
create user $(db_user) for login $(db_user)
alter role db_owner add member $(db_user)
alter login $(db_user) with default_database = $(db_name)
