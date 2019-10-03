--syteline02/03
select name
     , 'exec dba.dbo.usp_backup_db @dbname = ['
	 + name 
	 + '], @bu_type = ''full'''
      + ', @mirror_path = ''\\amsi01-c\importexport\20150804_AMSISALES'''
	 + CHAR(13)
	 + CHAR(10)
  from master.sys.databases
 where name like '%AMSISales'