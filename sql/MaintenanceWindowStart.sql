declare @primary as nvarchar(128);
declare @machine as nvarchar(128)=
     case when @@SERVERNAME like '%\%'
              then left(@@SERVERNAME,charindex('\',@@SERVERNAME,1)-1)
              else @@SERVERNAME end
 
-- if AlwaysOn, then check if we are primary node
if SERVERPROPERTY('IsHadrEnabled')= 1
begin
    -- get primary node
          select @primary = hags.primary_replica
            from master.sys.dm_hadr_availability_group_states hags
            join master.sys.availability_groups ag
              on hags.group_id=ag.group_id
 
end
 
if (@primary = @machine) or (@primary is null) -- either AAG and primary node, or not AAG
begin
      if exists ( select * from msdb.dbo.sysalerts where name = 'Failover' )
         begin
               exec msdb.dbo.sp_update_alert @name = 'Failover'
                                           , @enabled = 0
               print 'Disabled Failover'
         end

      if exists ( select * from msdb.dbo.sysalerts where name = 'Failover_SL' )
         begin
               exec msdb.dbo.sp_update_alert @name = 'Failover_SL'
                                           , @enabled = 0
               print 'Disabled Failover_SL'
         end
      
      if exists ( select * from msdb.dbo.sysalerts where name = 'Failover Started Listening' )
         begin
               exec msdb.dbo.sp_update_alert @name = 'Failover Started Listening'
                                           , @enabled = 0
               print 'Disabled Failover Started Listening'
         end
      
      if exists ( select * from msdb.dbo.sysalerts where name = 'Failover Stopped Listening' )
         begin
               exec msdb.dbo.sp_update_alert @name = 'Failover Stopped Listening'
                                           , @enabled = 0
               print 'Disabled Failover Stopped Listening'
         end
      
      if exists ( select * from msdb.dbo.sysalerts where name = 'HA Error - 35262' )
         begin
               exec msdb.dbo.sp_update_alert @name = 'HA Error - 35262'
                                           , @enabled = 0
               print 'Disabled HA Error - 35262'
         end
      
      if exists ( select * from msdb.dbo.sysjobs where name = 'dba_OnFailover' )
         begin
               exec msdb.dbo.sp_update_job @job_name = 'dba_OnFailover'
                                         , @enabled = 0
               print 'Disabled dba_OnFailover'
         end
      
      if exists ( select * from msdb.dbo.sysjobs where name = 'dba_SQLStart' )
         begin
               exec msdb.dbo.sp_update_job @job_name = 'dba_SQLStart'
                                         , @enabled = 0
               print 'Disabled dba_SQLStart'
         end
      
      if exists ( select * from msdb.dbo.sysjobs where name = 'dba_failover_alert' )
         begin
               exec msdb.dbo.sp_update_job @job_name = 'dba_failover_alert'
                                         , @enabled = 0
               print 'Disabled dba_failover_alert'
         end
      
      if exists ( select * from msdb.dbo.sysjobs where name = 'dba_SyncSQLAgent' )
         begin
               exec msdb.dbo.sp_start_job @job_name = 'dba_SyncSQLAgent'
               print 'Ran dba_SyncSQLAgent'
         end
end      