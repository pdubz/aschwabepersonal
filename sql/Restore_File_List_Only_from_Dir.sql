--set root directory
declare @rootDir as nvarchar(200) 
 select @rootDir = 'E:\chad_restores\gec\'
--if exists drop temp table
     if object_id('tempdb..#directoryTree') IS NOT NULL
   drop table #directoryTree;
--create temp table
 create table #directoryTree 
      ( id int identity(1,1)
      , subdirectory nvarchar(512)
      , depth int
      , isfile bit
	  , fullPath nvarchar(512)
	  ) ;
--insert into temp table from sproc
 insert #directoryTree (subdirectory,depth,isfile)
   exec master.sys.xp_dirtree @rootDir,1,1;
--select from temp table
declare @fullPath as nvarchar(512)
 select '
RESTORE FILELISTONLY 
   FROM DISK = '''+@rootDir+subdirectory+'''
   WITH FILE = 1
     GO '
   from #directoryTree
  where isfile = 1 
    AND RIGHT(subdirectory,4) = '.BAK'
