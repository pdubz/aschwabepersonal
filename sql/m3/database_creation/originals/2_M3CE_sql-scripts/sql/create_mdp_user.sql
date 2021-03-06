/*
   input:
   db_name - database name
   db_schema - database schema
   db_user - database schema
*/
use $(db_name)
if not exists (select * from sys.sql_logins where name = '$(db_user)')
	create login $(db_user) with password = '$(db_user)', check_policy = off
create user $(db_user) for login $(db_user)
alter role db_owner add member $(db_user)
exec sp_defaultdb @loginame='$(db_user)', @defdb='$(db_name)'
go

create schema $(db_schema)
go
