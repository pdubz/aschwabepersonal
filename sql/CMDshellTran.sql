

/*****************************************************************/

 begin transaction enable_cmdshell            EXEC master.dbo.sp_configure 'show advanced options', 1      RECONFIGURE WITH OVERRIDE;      GO      EXEC master.dbo.sp_configure 'xp_cmdshell', 1      RECONFIGURE WITH OVERRIDE;      GO      EXEC master.dbo.sp_configure 'show advanced options', 0      RECONFIGURE WITH OVERRIDE;      GO
	  --Insert into the table      INSERT INTO master.dbo.xp_CmdShell_State      select SERVERPROPERTY('processid') as [SPID]           , GetDate() as [ChangeDateTime]		   , ( select NewState               from master.dbo.xp_CmdShell_State               where SPID = 'start'             ) as [InitialState]           ,  as [NewState]
commit transaction enable_cmdshell


--do stuff

 begin transaction disable_cmdshell
--if exists(select top 1 spid from table where spid <> me and spid <> start)
	--begin
		--truncate row where spid = me
	--end
--else
	--truncate row where spid = me
	--set xp_cmdshell to start
commit transaction disable_cmdshell
