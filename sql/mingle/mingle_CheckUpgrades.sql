DECLARE @sql nvarchar(500);
CREATE TABLE [#mingleUpgradeCheck] ( [DBName] nvarchar(255)
                                   , [SchemaVersion] int
                                   ) ;
CREATE TABLE [#mingleCouldNotUpgrade] ( [DBName] nvarchar(255)
                                      ) ;

   SET @sql = 'IF EXISTS (SELECT * FROM [?].[sys].[tables] WHERE name = ''SchemaVersion'')
                  BEGIN
                        INSERT INTO [#mingleUpgradeCheck] 
                        SELECT ''?''
                             , *
                          FROM [?].[dbo].[SchemaVersion]
                    END 
               ELSE 
                  BEGIN
                        INSERT INTO [#mingleCouldNotUpgrade]
                        SELECT ''?''
                    END'
                          
  EXEC [dba].[dbo].[usp_foreachdb] @command = @sql
                                 , @user_only = 1
                                 , @suppress_quotename = 1;

SELECT [DBName]
     , [SchemaVersion]
  FROM [#mingleUpgradeCheck]
 WHERE [SchemaVersion] <> 300

SELECT [DBName]
     , [SchemaVersion]
  FROM [#mingleUpgradeCheck]
 WHERE [SchemaVersion] = 300

SELECT [DBName]
  FROM [#mingleCouldNotUpgrade]
 WHERE [DBName] NOT IN ( 'master'
                       , 'model'
                       , 'msdb'
                       , 'tempdb'
                       , 'dba'
                       , 'util'
                       ) ;

SELECT [DBVersion]
     , [UpdatedOn]
  FROM [InforCETenantConfig].[dbo].[TenantDBVersion]

  DROP TABLE [#mingleUpgradeCheck]
  DROP TABLE [#mingleCouldNotUpgrade]
