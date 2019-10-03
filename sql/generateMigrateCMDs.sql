--syteline02/03
select name
     , 'ALTER DATABASE ['
	 + name
	 + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE'
     + CHAR(13)
	 + CHAR(10)
	 + 'ALTER DATABASE ['
	 + name
	 + '] SET MULTI_USER'
     + CHAR(13)
	 + CHAR(10)
     + 'exec dba.dbo.usp_backup_db @dbname = '
	 + name 
	 + ', @bu_type = ''full'', @comment = ''AWS'', @mirror_path = ''\\dbw070\C$\temp\20150626_aws'''
     + CHAR(13)
	 + CHAR(10)
	 + 'ALTER DATABASE ['
     + name 
     + '] SET OFFLINE WITH ROLLBACK IMMEDIATE'
     + CHAR(13)
	 + CHAR(10)
  from master.sys.databases
 where name like 'BrandAgency_prd_%'