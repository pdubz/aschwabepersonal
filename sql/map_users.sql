declare @userName nvarchar(25) 
      , @dbRole nvarchar(25) 
      , @crlf varchar(2)
   
    set @userName = 'qdvision_db_owner'
    set @dbRole   = 'db_owner'
    set @crlf     = CHAR(13) + CHAR(10)

select name
     , '--Give [' + @userName + '] [' + @dbRole + '] priviledges on [' + name + ']' + @crlf
     + 'use [' + name + ']' + @crlf
     + 'go' + @crlf
     + 'create user [' + @userName + '] for login [' + @userName + ']' + @crlf
     + 'go' + @crlf
     + 'use [' + name + ']' + @crlf
     + 'go' + @crlf
     + 'alter role [' + @dbRole + '] add member [' + @userName + ']' + @crlf
     + 'go' + @crlf + @crlf as '2012CMDs'
     , '--Give [' + @userName + '] [' + @dbRole + '] priviledges on [' + name + ']' + @crlf
     + 'use [' + name + ']' + @crlf
     + 'go' + @crlf
     + 'create user [' + @userName + '] for login [' + @userName + ']' + @crlf
     + 'go' + @crlf
     + 'alter user [' + @userName + '] with default_schema = [dbo]' + @crlf
     + 'go' + @crlf
     + 'exec sp_addrolemember N''' + @dbRole + ''', N''' + @userName + '''' + @crlf + @crlf as '2008CMDs'
     , '--Drop [' + @userName + '] from [' + name + ']' + @crlf
     + 'use [' + name + ']' + @crlf
     + 'go' + @crlf
     + 'drop user [' + @userName + ']' + @crlf
     + 'go' + @crlf + @crlf as 'DropUserCMDs'
  from master.sys.databases
 where database_id > 6
 order by name
