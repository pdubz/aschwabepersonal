/*
   input:
   db_name - database name
   db_user - database user
 */
if exists (select name from sys.databases where name = '$(db_name)') 
  drop database $(db_name)
if exists (select * from sys.sql_logins where name = '$(db_user)')
  drop login $(db_user)
	

