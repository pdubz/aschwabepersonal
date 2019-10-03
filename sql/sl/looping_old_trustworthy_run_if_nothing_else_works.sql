exec dba.dbo.usp_foreachdb @command =     
	'use [?];
     
  alter database [?] SET TRUSTWORTHY ON;

declare @master_owner sysname;
 select @master_owner = sl.name 
   from master..syslogins sl
  inner join sys.databases sd 
     on sd.owner_sid = sl.sid
  where sd.name = ''master'';

declare @my_owner sysname;
 select @my_owner = sl.name
   from master..syslogins sl
  inner join sys.databases sd 
     on sd.owner_sid = sl.sid
  where sd.name = ''?'';
     
if ISNULL(@my_owner, '''') <> @master_owner
	begin
		declare @SQL1 nvarchar(4000)
		set @SQL1 = ''ALTER AUTHORIZATION ON DATABASE::[?] TO '' + @master_owner
		execute (@SQL1)
    end;

declare @SQL nvarchar(4000)
    set @SQL = ''ALTER DATABASE [?] SET TRUSTWORTHY ON''
execute (@SQL);', @name_pattern = '%app%', @suppress_quotename = 1