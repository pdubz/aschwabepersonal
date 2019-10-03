DECLARE @sql nvarchar(400)

IF OBJECT_ID('tempdb..##TempTables') IS NOT NULL
	BEGIN
		DROP TABLE ##TempTables
	END

IF OBJECT_ID('tempdb..##TempTableSizes') IS NOT NULL
	BEGIN
		DROP TABLE ##TempTableSizes
	END

CREATE TABLE ##TempTables ( DatabaseName nvarchar(100)
                          , TableName nvarchar(100)
                          ) 

CREATE TABLE ##TempTableSizes ( [DatabaseName] NVARCHAR(100)
                              , [name] NVARCHAR(100)
                              , [rows] INT
                              , [reserved] NVARCHAR(100)
                              , [data] NVARCHAR(100)
                              , [index_size] NVARCHAR(100)
                              , [unused] NVARCHAR(100)
                              ) 
SET @sql = '
INSERT INTO ##TempTables
SELECT ''?'' 
     , TABLE_NAME
  FROM [?].INFORMATION_SCHEMA.TABLES
 WHERE TABLE_NAME like ''%tmp%'' or TABLE_NAME like ''%temp%''
'

EXEC dba.dbo.usp_foreachdb @command = @sql, @suppress_quotename = 1

DECLARE @DatabaseName NVARCHAR(100)
      , @TableName NVARCHAR(100)
 WHILE EXISTS ( SELECT TOP 1 * FROM ##TempTables ) 
       BEGIN
             SELECT @DatabaseName = DatabaseName
                  , @TableName = TableName
               FROM ##TempTables
               EXEC ( '
                         USE [' + @DatabaseName + ']
                      INSERT INTO ##TempTableSizes ( [name]
                                                   , [rows]
                                                   , [reserved]
                                                   , [data]
                                                   , [index_size]                                                   , [unused]
                                                   ) 
                        EXEC sp_spaceused ''' + @TableName + ''' 
                      UPDATE ##TempTableSizes
                         SET DatabaseName = ''' + @DatabaseName + '''
                       WHERE name = ''' + @TableName + '''
                      DELETE 
                        FROM ##TempTables
                       WHERE TableName = ''' + @TableName + ''''
                    ) 
         END

SELECT *
  FROM ##TempTableSizes

IF OBJECT_ID('tempdb..##TempTables') IS NOT NULL
	BEGIN
		DROP TABLE ##TempTables
	END

IF OBJECT_ID('tempdb..##TempTableSizes') IS NOT NULL
	BEGIN
		DROP TABLE ##TempTableSizes
	END
