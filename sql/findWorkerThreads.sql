-- created in util database because we need to be able to run on secondary nodes as well.
declare @CurrentMaxWorkerThreads int
     , @CalculatedMaxWorkerThreads int
     , @CPUCount int
     , @AGDatabaseCount int
     , @ReplicaCount int
     , @AlertOperator nvarchar(100)
     , @suggestedThreads int

declare @workerThreadCPUTable table ( CPUCount int
	                                , MaxWorkerThread int
                                    ) ;

-- max worker threads by cpu count per Microsoft: https://msdn.microsoft.com/en-us/library/ms190219.aspx
insert into @workerThreadCPUTable( CPUCount
                                 , MaxWorkerThread )
values (4, 512)
     , (8, 576)
     , (16, 704)
     , (32, 960)
     , (64, 1472)
     , (128, 4480)
     , (256, 8576)

-- Get current values for Max Worker Threads & # of CPU cores
select @CurrentMaxWorkerThreads = max_workers_count 
     , @CPUCount = cpu_count
  from sys.dm_os_sys_info

-- Get # of databases contained in the AG & # of servers joined to the AG
select @AGDatabaseCount = count(distinct dbcs.database_name) 
	 , @ReplicaCount = count(distinct ar.replica_server_name)
  from master.sys.availability_groups AS ag
  join master.sys.availability_replicas AS ar
	on ag.group_id = ar.group_id
  join master.sys.dm_hadr_availability_replica_states AS arstates
	on ar.replica_id = arstates.replica_id 
  join master.sys.dm_hadr_database_replica_cluster_states AS dbcs
	on arstates.replica_id = dbcs.replica_id

;with CPUCountLookup as (
	-- get the highest CPUCount we can use from our recommended threads table based on
	-- # of CPUs on this server.
	select max(CPUCount) CPUCount
	  from @workerThreadCPUTable
	 where CPUCount <= @CPUCount)
-- join back to our CTE to find out recommended MaxWorkerThread value & calculate the 
-- max worker threads based on forumla [Recommended max threads] + (4 * AG DB Count)
-- using 4 as static multiplier since all recommended max thread counts are divisible by 4.
select @CalculatedMaxWorkerThreads = wtct.MaxWorkerThread + (4 * @AGDatabaseCount)
  from @workerThreadCPUTable wtct
  join CPUCountLookup ccl
	on wtct.CPUCount = ccl.CPUCount

select @suggestedThreads = MaxWorkerThread
  from @workerThreadCPUTable
 where @CPUCount = CPUCount

select @AGDatabaseCount as AGDBs
     , @CPUCount as CPUs
     , @suggestedThreads as SuggestedThreads
     , @CurrentMaxWorkerThreads as CurrThreads
     , convert(nvarchar,@suggestedThreads)
     + ' + (4*' 
     + convert(nvarchar,@AGDatabaseCount)
     + ')' as Formula
     , @CalculatedMaxWorkerThreads as NewThreads