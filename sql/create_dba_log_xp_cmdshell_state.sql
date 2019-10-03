USE [master]
GO

/****** Object:  StoredProcedure [dbo].[dba_log_xp_cmdshell_state]    Script Date: 2/28/2015 18:16:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[dba_log_xp_cmdshell_state]
AS
BEGIN
      SET NOCOUNT ON;

      --Set xp_cmdshell to off
      EXEC master.dbo.sp_configure 'show advanced options', 1;
      RECONFIGURE WITH OVERRIDE;

      EXEC master.dbo.sp_configure 'xp_cmdshell', 0;
      RECONFIGURE WITH OVERRIDE;
      
	  EXEC master.dbo.sp_configure 'show advanced options', 0;
      RECONFIGURE WITH OVERRIDE;
      
	  --Drop table if exists, else create table
      IF OBJECT_ID (N'xp_CmdShell_State', N'U') IS NOT NULL
         TRUNCATE TABLE master.dbo.xp_CmdShell_State
      ELSE
         CREATE TABLE [master].[dbo].[xp_CmdShell_State]( [SPID]           [int] NULL
                                                        , [ChangeDateTime] [datetime] NULL
                                                        , [InitialState]   [smallint] NULL
                                                        , [NewState]       [smallint] NULL ) 
      --Insert into the table
      INSERT master.dbo.xp_CmdShell_State
      SELECT CAST(SERVERPROPERTY('processid') as int) as [SPID]
           , GetDate() as [ChangeDateTime]
           , 0 as [InitialState]
           , 0 as [NewState]
      
END
GO

--Set SPROC to run at SQL Server Startup
EXEC sp_procoption 'dba_log_xp_cmdshell_state'
                 , 'startup'
                 , 'on'
GO

--Run the sproc once
EXEC master.dbo.dba_log_xp_cmdshell_state
GO