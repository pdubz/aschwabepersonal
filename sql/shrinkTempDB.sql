USE [tempdb]
CHECKPOINT;
DBCC FREEPROCCACHE -- clean cache
DBCC DROPCLEANBUFFERS -- clean buffers
DBCC FREESYSTEMCACHE ('ALL') -- clean system cache
DBCC FREESESSIONCACHE -- clean session cache
DBCC SHRINKDATABASE(tempdb, 10); -- shrink tempdb
--
DBCC shrinkfile ('tempdev' ,37000) -- shrink db file in MB
DBCC shrinkfile ('tempdev2',37000) -- shrink db file in MB
DBCC shrinkfile ('tempdev3',37000) -- shrink db file in MB
DBCC shrinkfile ('tempdev4',37000) -- shrink db file in MB
--
USE [master]
ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev' , SIZE = 30720000KB ) -- resize when I was finished
ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev2', SIZE = 30720000KB ) -- resize when I was finished
ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev3', SIZE = 30720000KB ) -- resize when I was finished
ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev4', SIZE = 30720000KB ) -- resize when I was finished
