   SET NOCOUNT ON
;with CurrentServer as (select @@SERVERNAME as [Server Name]) 
SELECT cs.[Server Name] AS [Server Name]
     , name AS [Account]
     , create_date [Create Date]
     , modify_date [Modify Date]
     , '<YOUR NAME HERE>' AS [DBA]
  FROM CurrentServer cs
  LEFT OUTER JOIN master.sys.server_principals sp
    ON cs.[Server Name] = @@SERVERNAME
   AND IS_SRVROLEMEMBER ('sysadmin',name) = 1
   AND name = 'prod\ADMINISTRATOR'
