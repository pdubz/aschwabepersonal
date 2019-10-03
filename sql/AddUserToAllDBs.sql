SET NOCOUNT ON
DECLARE @DB sysname
DECLARE @LF CHAR(1) = CHAR(10)
DECLARE @User sysname = 'admin\abalila'
DECLARE @DBs TABLE
(
	name sysname
)

DECLARE @Cmds TABLE
(
	CMD NVARCHAR(500)
)

INSERT INTO @DBs
SELECT name 
FROM master.sys.databases
WHERE name NOT IN ( 'master','msdb','model','tempdb','dba','util','DBAData','DBAProcedures','DBALogs' )

WHILE EXISTS 
(
	SELECT TOP 1 name
	FROM @DBs
	ORDER BY name DESC
)
BEGIN
	SELECT TOP 1 @DB = name 
	FROM @DBs
	ORDER BY name DESC

	INSERT INTO @Cmds
	SELECT 'USE [' + @DB + ']' + @LF +
		'GO' + @LF + 
		'CREATE USER [' + @User + '] FOR LOGIN [' + @User + ']' + @LF + 
		'GO' + @LF + 
		'USE [' + @DB + ']' + @LF + 
		'GO' + @LF + 
		'ALTER ROLE [db_owner] ADD MEMBER [' + @User + ']' + @LF + 
		'GO' + @LF

	DELETE
	FROM @DBs
	WHERE name = @DB
END

SELECT *
FROM @Cmds
