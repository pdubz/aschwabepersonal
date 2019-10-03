create table #tmp ( spid varchar(50)
                  , status varchar(100)
                  , Login varchar(255)
                  , Hostname varchar(50)
                  , BlkBy varchar(50)
                  , dbname varchar(50)
                  , Command varchar(255)
                  , CPUTime varchar(50)
                  , DiskIO varchar(50)
                  , LastBatch varchar(50)
                  , programName varchar(255)
                  , spid2 varchar(50)
                  , RequestID varchar(50))

insert into #tmp
exec sp_who2 

select *
  from #tmp
 where [login] not in ( 'fred','sa','stage\sqlagent_svc','admin\aschwabe','NT AUTHORITY\SYSTEM' )
   AND Command not in ('AWAITING COMMAND')
drop table #tmp
