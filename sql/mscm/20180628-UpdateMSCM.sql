DECLARE @Now nvarchar(8) = CONVERT(NVARCHAR(8),GETDATE(),112)
     , @DB nvarchar(255) = 'NWCH_TST_MSC_Ten_0'
     , @Schema nvarchar(255) = 'dbo'
     , @Table nvarchar(255) = 'CONFIG_TENANT';

/*print data to screen*/
  EXEC ( 'SELECT *
            FROM ' + @DB + '.' + @Schema + '.' + @Table
       ) ;

/*database backup*/
  EXEC util.dbo.usp_backup_db @bu_type = 'full'
     , @dbname = @DB
     , @comment = 'B4';

/*table backup*/
  EXEC ( 'SELECT *
            INTO ' + @DB + '.' + @Schema + '.' + @Table + '_Temp' + @Now + 
          ' FROM ' + @DB + '.' + @Schema + '.' + @Table 
       ) ;

/*add correct url*/
UPDATE NWCH_TST_MSC_Ten_0.dbo.CONFIG_TENANT
  SET VALUE = 'gen-nwch-tst.inforcloudsuite.com'
WHERE NAME = 'hostname'

UPDATE NWCH_TST_MSC_Ten_0.dbo.CONFIG_TENANT
  SET VALUE = 'adm-nwch-tst.inforcloudsuite.com'
WHERE NAME = 'hhHostname'


/*print data to screen*/
  EXEC ( 'SELECT *
            FROM ' + @DB + '.' + @Schema + '.' + @Table
       ) ;

/*backup database*/
  EXEC util.dbo.usp_backup_db @bu_type = 'full'
     , @dbname = @DB
     , @comment = 'After';
