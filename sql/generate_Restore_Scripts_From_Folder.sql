--if temp table exists in tempdb drop it
if OBJECT_ID('tempdb..#DirectoryTree') IS NOT NULL
  drop table #DirectoryTree;

--if temp table exists in tempdb drop it
if OBJECT_ID('tempdb..#filesAndNames') IS NOT NULL
  drop table #filesAndNames;

declare @bkupLocation nvarchar(512) = '\\sl09-a\Backup\full\'

--create table in tempdb
create table #directoryTree ( id int IDENTITY(1,1)
                            , subdirectory nvarchar(512)
                            , depth int
                            , isfile bit );

--create table in tempdb
create table #filesAndNames ( id int IDENTITY(1,1)
                            , bakfile nvarchar(512)
                            , dbname nvarchar(512) );

--insert values from xp dirtree
insert #directoryTree ( subdirectory
                      , depth
                      , isfile )

--find files located in directory
  exec master.sys.xp_dirtree @bkupLocation,0,1;

insert #filesAndNames ( bakfile
                      , dbname )
select @bkupLocation
     + SUBSTRING(subdirectory,1,(LEN(subdirectory)-24))
	 + '\'
     + subdirectory
     , SUBSTRING(subdirectory,1,(LEN(subdirectory)-24))
  from #directoryTree
 where isfile = 1 
   AND RIGHT(subdirectory,4) = '.bak'
   AND subdirectory not like '$%'
 order by id

--drop temp table from temp db
  drop table #directoryTree

--get all files with .bak extension
select bakfile
     , dbname
	 , 'restore database ['
	 + dbname
      + ']'
	 + char(13)
	 + char(10)
	 + '   from disk = '''
	 + bakfile 
	 + ''''
	 + char(13)
	 + char(10)
	 + '   with file = 1'
	 + char(13)
	 + char(10)
	 + '      , move ''' 
	 + dbname
	 + ''' to ''e:\data01\data\'
	 + dbname
	 + '.mdf'''
	 + char(13)
	 + char(10)
	 + '      , move ''' 
	 + dbname
	 + '_log'' to ''e:\logs01\data\'
	 + dbname
	 + '_log.ldf'''
	 + char(13)
	 + char(10)
	 + '      , recovery'
	 + char(13)
	 + char(10)
	 + '      , stats = 10'
	 + char(13)
	 + char(10)
	 + char(13)
	 + char(10)
  from #filesAndNames
 order by id

--drop temp table from temp db
  drop table #filesAndNames
