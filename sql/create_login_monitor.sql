/*Create Logins to Monitor Table*/
use dba
go

if not exists(select 1 
				from sys.objects so
				join sys.schemas ss
				  on so.schema_id = ss.schema_id
			   where so.name = 'Logins_To_Monitor'
			     and ss.name = 'dbo')
begin
	create table dbo.Logins_To_Monitor(
		login_to_monitor_id int identity(1,1) primary key
		, login_name sysname not null
		, program_name sysname not null
		, email_recipients varchar(max) not null
		, alert_window int not null
	)
end
go

/*Create Login Violation Table*/
use dba
go

if not exists(select 1 
				from sys.objects so
				join sys.schemas ss
				  on so.schema_id = ss.schema_id
			   where so.name = 'Login_Violations'
			     and ss.name = 'dbo')
begin
	create table dba.dbo.Login_Violations(
		login_violation_id int identity(1,1) primary key
		, spid int not null
		, database_name sysname not null
		, program_name sysname not null
		, login_time datetime not null
		, last_batch datetime not null
		, login_name sysname not null
		, last_alert_sent datetime null
		, resolved_date datetime null
	)
end

go

/*Create Login Violation Queries Table*/
use dba
go

if not exists(select 1 
				from sys.objects so
				join sys.schemas ss
				  on so.schema_id = ss.schema_id
			   where so.name = 'Login_Violation_Queries'
			     and ss.name = 'dbo')
begin
	create table dbo.Login_Violation_Queries(
		login_violation_query_id int identity(1,1) primary key
		, login_violation_id int not null
		, query_text nvarchar(max) not null
		, captured_date datetime default(getdate()) not null
	)
end
go

/*Create Capture Login Violations SPROC*/
use dba
go

if exists(select 1
			from sys.objects so
			join sys.schemas ss
			  on so.schema_id = ss.schema_id
		   where ss.name = 'dbo'
		     and so.name = 'usp_Capture_Login_Violations')
begin
	drop procedure dbo.usp_Capture_Login_Violations
end
go

/********************************************************
** usp_Capture_Login_Violations
** Author:	Brad Mullins
** Date:	1/15/2015
** Purpose: When we purpose a login for a certain function
**			we would expect to not see certain applications 
**			connect using this user login.  When that happens
**			we would like to log it and which queries we see run
**			while it is connected.
********************************************************/
create procedure dbo.usp_Capture_Login_Violations
as
begin
set nocount on

-- Find all spids that violate a rule defined in the table dba.dbo.logins_to_monitor

;with monitored_logins as (
	select distinct login_name
	  from Logins_To_Monitor
)
select	 sp.spid						-- spid of the process violating the rule
	, sdb.name database_name		-- database the spid is currently connected to
	, sp.program_name				-- application that is connected to the database
	, sp.login_time					-- date/time the spid connected to the database
	, sp.last_batch					-- date/time the spid last ran a batch
	, sl.name login_name			-- login name used to connect to the database
  into #login_violations
  from master.sys.sysprocesses sp	
  join master.sys.syslogins sl
    on sp.sid = sl.sid
  join master.sys.sysdatabases sdb
    on sp.dbid = sdb.dbid
  join monitored_logins ml
    on sl.loginname = ml.login_name
 where not exists(select 1 from Logins_To_Monitor where login_name = ml.login_name and program_name = sp.program_name)

-- If the violation has already been logged in the Login_Violations table, and the violation 
-- no longer exists, then set the resolved_date value to current date/time.
update lv
   set resolved_date = getdate()	-- set resolved_date to current date/time
  from Login_Violations lv
  left join #login_violations tlv	-- left join login_violations, if no record exists the violation no longer exists.
    on lv.spid = tlv.spid
   and lv.login_name = tlv.login_name
   and lv.program_name = tlv.program_name
   and lv.login_time = tlv.login_time
 where tlv.spid is null				-- check to see if #login_violations row exists (violation still exists)
   and lv.resolved_date is null		-- check to see if record is still outstanding

-- If we have not logged this violoation already, add it to the dba.dbo.Login_Violations table
insert into Login_Violations(spid, database_name, program_name, login_time, last_batch, login_name)
select tlv.spid
	, tlv.database_name
	, tlv.program_name
	, tlv.login_time
	, tlv.last_batch
	, tlv.login_name
  from #login_violations tlv
  left join Login_Violations lv		-- left join to Login_Violations, if no record exists, then this is the first time we've seen it.
    on lv.spid = tlv.spid
   and lv.login_name = tlv.login_name
   and lv.program_name = tlv.program_name
   and lv.login_time = tlv.login_time
 where lv.spid is null				-- check to see if Login_Violations record exists.

-- Figure out if we need to send an alert.  Based on # of minutes defined in alert_window field of the logins_to_monitor
-- and the last time we sent an alert, which is stored in Login_Violations.last_alert_sent.  results stored in 
-- temp table #alerts_to_send
select distinct lv.*, ltm.email_recipients
  into #alerts_to_send
  from Login_Violations lv
  join Logins_To_Monitor ltm
    on lv.login_name = ltm.login_name
 where resolved_date is null
   and dateadd(n, ltm.alert_window, isnull(lv.last_alert_sent, '1/1/1900')) <= getdate()

-- for all outstanding Login_Violations, we log what the last query ran is.  This step gets all the spids 
-- we need to check last run sql query for.
select lv.spid, lv.login_violation_id
  into #get_query_text
  from Login_Violations lv
 where resolved_date is null

declare @violation_count int = 0
	, @email_body varchar(max)
	, @email_recipient varchar(max)
	, @email_subject varchar(500)
	, @spid int
	, @login_violation_id int
	, @sql varchar(max)

create table #query_results(EventType varchar(256), Parameters varchar(max), EventInfo varchar(max))

-- loop through each unresolved violating spid, and get last query run syntax.
while exists(select 1 from #get_query_text)
begin
	select top 1 @spid = spid
		, @login_violation_id = login_violation_id
		from #get_query_text

	-- dbcc inputbuffer gets last query submitted by the spid passed in.  Store results in temp table so we can
	-- log results later.
	set @sql = 'dbcc inputbuffer(' + cast(@spid as varchar) + ')'
		
	insert into #query_results		
	exec(@sql)

	-- if we have not already logged the query text for this violation, then log it in the Login_Violation_Queries table.
	insert into Login_Violation_Queries(login_violation_id, query_text)
	select @login_violation_id, EventInfo
	  from #query_results qr
	  left join Login_Violation_Queries lvq
	    on lvq.login_violation_id = @login_violation_id
	   and qr.EventInfo = lvq.query_text
	 where lvq.login_violation_query_id is null

	-- clear out #query_results for next iteration
	delete
	  from #query_results

	-- delete row from temp table so we don't get stuck in an infinite loop.
	delete
	  from #get_query_text 
	 where spid = @spid
end
drop table #get_query_text

-- loop through and send 1 alert per distinct email_recipient that we are sending to.
while exists(select 1 from #alerts_to_send)
begin
	select top 1 @email_recipient = email_recipients
	  from #alerts_to_send

	select @violation_count = count(1)
	  from #alerts_to_send
	 where email_recipients = @email_recipient


	-- build header for the table contained in the email text
	set @email_body = '<table border=1 spacing=1><tr><td>SPID</td><td>Login</td><td>Program</td><td>Database</td><td>Login Time</td><td>Last Batch</td><td>Last Query</td></tr>'
	
	-- build the rows for the table contained in the email text
	;with Login_Queries as (
		select Login_Violation_Id
			, max(login_violation_query_id) login_violation_query_id
		  from Login_Violation_Queries
		 group by login_violation_id
	)
	select  @email_body += '<tr><td>' +  cast(spid as varchar) + '</td><td>' + login_name + '</td><td>' + program_name + '</td><td>' + database_name + '</td><td>' + cast(login_time as varchar) + '</td><td>' + cast(last_batch as varchar) + '</td><td>' + query_text + '</td></tr>'
	  from #alerts_to_send ats
	  left join Login_Queries lq
	    on ats.login_violation_id = lq.login_violation_id
	  left join Login_Violation_Queries lvq
	    on lq.login_violation_query_id = lvq.login_violation_query_id
	 where email_recipients = @email_recipient

	set @email_body += '</table>'
	set @email_subject = 'Login Violations: ' + @@SERVERNAME

	-- send the email
	exec msdb.dbo.sp_send_dbmail @profile_name = 'SQLMail Profile', @recipients = @email_recipient, @subject=@email_subject, @body = @email_body, @body_format='HTML'

	-- update Login_Violations table and set the date of last_alert_sent to current date/time
	update lv
	   set last_alert_sent = getdate()  
	  from Login_Violations lv
	  join #alerts_to_send ats
	    on lv.login_violation_id = ats.login_violation_id

	-- remove row from temp table so we don't get stuck in an infinite loop.
	delete
	  from #alerts_to_send
	 where email_recipients = @email_recipient
end


	
drop table #alerts_to_send
drop table #login_violations
drop table #query_results

end
go

/*Create Monitor Login Violations SPROC*/
if exists(select 1
			from sys.objects so
			join sys.schemas ss
			  on so.schema_id = ss.schema_id
		   where so.name = 'usp_Monitor_Login_Violations'
		     and ss.name = 'dbo')
begin
	drop procedure dbo.usp_Monitor_Login_Violations
end
go

create procedure dbo.usp_Monitor_Login_Violations
	@full_duration int = 20
	, @check_interval varchar(8) = '00:00:10'
as
begin
	declare @start_time datetime = getdate()

	while (datediff(MINUTE, @start_time, getdate()) <= @full_duration)
	begin
		exec dbo.usp_Capture_Login_Violations
		waitfor delay @check_interval
	end
end
go

/*Create dba_LoginMonitor job*/
USE [msdb]
GO

/****** Object:  Job [dba_LoginMonitor]    Script Date: 1/26/2015 3:03:33 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 1/26/2015 3:03:33 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dba_LoginMonitor', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'prod\sqlprod_svc', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [PRIMARY CHECK]    Script Date: 1/26/2015 3:03:33 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'PRIMARY CHECK', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=1, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'IF SERVERPROPERTY (''IsHadrEnabled'') = 1
BEGIN
	IF (SELECT
			RCS.replica_server_name
		FROM
			sys.availability_groups_cluster AS AGC
			INNER JOIN sys.dm_hadr_availability_replica_cluster_states AS RCS
			ON
			RCS.group_id = AGC.group_id
			INNER JOIN sys.dm_hadr_availability_replica_states AS ARS
			ON
			ARS.replica_id = RCS.replica_id
			INNER JOIN sys.availability_group_listeners AS AGL
			ON
			AGL.group_id = ARS.group_id
		WHERE
			ARS.role_desc = ''PRIMARY'') = @@SERVERNAME
	SELECT 1 -- Show that this is the Primary node.
		ELSE
	RAISERROR (50005, 10, 1);  --Retunr an error to let SQL know not to do the Backups.

END', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Run Monitor]    Script Date: 1/26/2015 3:03:33 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Run Monitor', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec usp_Monitor_Login_Violations 20, ''00:00:10''', 
		@database_name=N'dba', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every Minute', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20150120, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'232f143c-609f-4bb9-af32-ad0a8d773e9f'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO




