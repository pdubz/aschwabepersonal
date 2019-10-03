SELECT name,
	is_trustworthy_on,
	'ALTER DATABASE [' + name + '] SET TRUSTWORTHY ON'
FROM master.sys.databases
WHERE name LIKE '%app%'
	AND is_trustworthy_on <> 1
