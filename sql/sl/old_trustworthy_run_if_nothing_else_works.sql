    use BRANDAGENCY_PLT_App
     go
  alter database BRANDAGENCY_PLT_App SET TRUSTWORTHY ON 

declare @master_owner sysname
 select @master_owner = sl.name 
   from master..syslogins sl
  inner join sys.databases sd 
     on sd.owner_sid = sl.sid
  where sd.name = 'master'

declare @my_owner sysname
 select @my_owner = sl.name
   from master..syslogins sl
  inner join sys.databases sd 
     on sd.owner_sid = sl.sid
  where sd.name = DB_NAME()
     
if ISNULL(@my_owner, N'') <> @master_owner
	begin
		declare @SQL1 nvarchar(4000)
		set @SQL1 = N'ALTER AUTHORIZATION ON DATABASE::' + DB_NAME()+ ' TO ' + @master_owner
		execute (@SQL1)
    end
go

declare @SQL nvarchar(4000)
    set @SQL = N'ALTER DATABASE ' + DB_NAME() + N' SET TRUSTWORTHY ON'
execute (@SQL)
     go