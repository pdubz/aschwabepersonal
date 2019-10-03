IF EXISTS ( SELECT *
              FROM tempdb.dbo.sysobjects o
             WHERE o.xtype in ('U')
               AND o.id = object_id(N'tempdb..#Data') )
DROP TABLE #Data
--
DECLARE @DatabaseList Table ( DatabaseName sysname )
DECLARE @DatabaseName sysname
      , @SQLCommand   nvarchar(max)
--
SET NOCOUNT ON
--
CREATE TABLE [dbo].[#Data]( [Drive]              [nvarchar](1)       NULL
                          ,	[Database ID]        [smallint]          NULL
                          ,	[Database Name]      [sysname]       NOT NULL
                          ,	[Database Owner]     [nvarchar](128)     NULL
                          ,	[Created Date]       [DateTime]          NULL
                          ,	[Group ID]           [smallint]          NULL
                          ,	[File ID]            [smallint]          NULL
                          ,	[File Name]          [sysname]       NOT NULL
                          ,	[File Size (MB)]     [int]               NULL
                          ,	[File Size (GB)]     [int]               NULL
                          ,	[SPACE_USED_MB]      [decimal](12, 4)    NULL
                          ,	[FREE_SPACE_MB]      [decimal](12, 4)    NULL
                          ,	[Physical File Name] [nvarchar](260) NOT NULL
                          ,	[Autogrowth]         [varchar](109)      NULL )
          ON [PRIMARY]
--
INSERT @DatabaseList
SELECT name 
  FROM master.dbo.sysdatabases
 WHERE DBID > 4
--
WHILE EXISTS ( SELECT 1 from @DatabaseList )
      BEGIN
            SELECT TOP 1 @DatabaseName = Databasename FROM @DatabaseList ORDER BY DatabaseName
            SET @SQLCommand ='USE ['+@DatabaseName+'];
  INSERT #Data
  SELECT Drive                = substring(AF.FileName,1,1)
       , [Database ID]        = DB.dbid
       , [Database Name]      = DB.name
       , [Database Owner]     = SUSER_SNAME(owner_sid)
       , [Created Date]       = DB.CRDate
       , [Group ID]           = AF.GroupID
       , [File ID]            = AF.FileID
       , [File Name]          = AF.Name
       , [File Size (MB)]     = ( ( AF.Size * 8 ) / 1024 )
       , [File Size (GB)]     = ( ( ( AF.Size * 8 ) / 1024 ) / 1024 )
       , [SPACE_USED_MB]      = convert(decimal(12,4),fileproperty(AF.Name,''SpaceUsed'')/128.000)
       , [FREE_SPACE_MB]      = convert(decimal(12,2),round((AF.size-fileproperty(AF.Name,''SpaceUsed''))/128.000,2))
       , [Physical File Name] = AF.FileName
       , [Autogrowth]         = ''Autogrowth: ''
       + CASE
              WHEN (AF.status & 0x100000 = 0 AND CEILING((AF.growth * 8192.0) / (1024.0 * 1024.0)) = 0.00) OR AF.growth = 0
                   THEN ''None''
              WHEN AF.status & 0x100000 = 0
                   THEN ''By '' + CONVERT(VARCHAR,CEILING((AF.growth * 8192.0) / (1024.0 * 1024.0))) + '' MB''
              ELSE ''By '' + CONVERT(VARCHAR,AF.growth) + '' percent''
         END
       + CASE
              WHEN (AF.status & 0x100000 = 0 AND CEILING((AF.growth * 8192.0) / (1024.0 * 1024.0)) = 0.00) OR AF.growth = 0
                   THEN ''''
              WHEN CAST([maxsize] * 8.0 / 1024 AS DEC(20,2)) <= 0.00
                   THEN '', unrestricted growth''
              ELSE '', restricted growth to '' + CAST(CAST([maxsize] * 8.0 / 1024 AS DEC(20)) AS VARCHAR) + '' MB''
         END
    FROM [MASTER].[DBO].[SYSALTFILES]  AS AF
       , [MASTER].[DBO].[SYSDATABASES] AS DB
       , [MASTER].[sys].[databases]    AS SD
   WHERE AF.DBID= DB.DBID
     and SD.database_id = AF.dbid
     and AF.dbid        = db_id('''+@DatabaseName+''')
ORDER BY 2,5 desc,6 asc'
            EXECUTE sp_executesql @SQLCommand
            DELETE @DatabaseList where DatabaseName = @DatabaseName
      END
--
SELECT *,
	--'USE ['+[Database Name]+']; DBCC SHRINKFILE('+[File Name]+');'
	'USE ['+[Database Name]+']; DBCC SHRINKFILE('+[File Name]+','+CONVERT(varchar(15),CONVERT(INT,SPACE_USED_MB))+');'
FROM #Data
WHERE [File ID] = 2 AND FREE_SPACE_MB > 1024
ORDER BY FREE_SPACE_MB DESC
