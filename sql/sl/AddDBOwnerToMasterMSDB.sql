SET NOCOUNT ON
DECLARE @User sysname
DECLARE @LF CHAR(1) = CHAR(10)

DECLARE @Users TABLE
(
	name sysname
)

DECLARE @Cmds TABLE
(
	CMD NVARCHAR(2048)
)

INSERT INTO @Users
SELECT name 
FROM master.sys.server_principals
WHERE name LIKE '%db_owner'

WHILE EXISTS 
(
	SELECT TOP 1 name
	FROM @Users
	ORDER BY name DESC
)
BEGIN
	SELECT TOP 1 @User = name 
	FROM @Users
	ORDER BY name DESC

	INSERT INTO @Cmds
	SELECT 'USE [master]' + @LF +
		'GO' + @LF +
		'CREATE USER [' + @User + '] FOR LOGIN [' + @User + ']' + @LF +
		'GO' + @LF +
		'USE [master]' + @LF +
		'GO' + @LF +
		'ALTER ROLE [db_datareader] ADD MEMBER [' + @User + ']' + @LF +
		'GO' + @LF +
		'USE [master]' + @LF +
		'GO' + @LF +
		'ALTER ROLE [SytelineAppUsers] ADD MEMBER [' + @User + ']' + @LF +
		'GO' + @LF +
		'USE [msdb]' + @LF +
		'GO' + @LF +
		'CREATE USER [' + @User + '] FOR login [' + @User + ']' + @LF +
		'GO' + @LF +
		'USE [msdb]' + @LF +
		'GO' + @LF +
		'ALTER ROLE [db_datareader] ADD MEMBER [' + @User + ']' + @LF +
		'GO' + @LF +
		'USE [msdb]' + @LF +
		'GO' + @LF +
		'ALTER ROLE [db_datawriter] ADD MEMBER [' + @User + ']' + @LF +
		'GO' + @LF +
		'USE [msdb]' + @LF +
		'GO' + @LF +
		'ALTER ROLE [SQLAgentUserRole] ADD MEMBER [' + @User + ']' + @LF +
		'GO' + @LF + 
		'USE [master]' + @LF + 
		'GO' + @LF + 
		'GRANT EXTERNAL ACCESS ASSEMBLY TO [' + @User + ']' + @LF + 
		'GO' + @LF + 
		'USE [master]' + @LF + 
		'GO' + @LF + 
		'GRANT UNSAFE ASSEMBLY TO [' + @User + ']' + @LF + 
		'GO' + @LF 

	DELETE
	FROM @Users
	WHERE name = @User
END

SELECT *
FROM @Cmds
