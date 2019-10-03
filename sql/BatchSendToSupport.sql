SELECT name,
'EXEC dba.dbo.usp_send_to_support @dbname = ''' + name + ''', @code = ''SL10273853'', @customs = ''N'', @testBackup = ''Y'', @utilServerName = ''slutil02-c'''
FROM master.sys.databases
WHERE name LIKE'%ATCLLCCSI_PRD_%'
OR name LIKE '%ATCLLCCSI_Polling%'
OR name LIKE '%ATCLLCFT_PRD_%'
OR name LIKE '%ARCGWICSI_PRD_%'
OR name LIKE '%AFTCSI_PRD_%'
OR name LIKE '%AFTFT_PRD_%'
OR name LIKE '%THIXOCSI_PRD_%'
OR name LIKE '%THIXOFT_PRD_%'