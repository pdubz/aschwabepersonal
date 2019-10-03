DECLARE @Now nvarchar(8) = CONVERT(NVARCHAR(8),GETDATE(),112)
     , @DB nvarchar(255) = 'InforCETenantConfig'
     , @Schema nvarchar(255) = 'dbo'
     , @Table nvarchar(255) = 'SystemConfiguration';

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
IF EXISTS ( SELECT Code 
              FROM InforCETenantConfig.dbo.SystemConfiguration 
             WHERE Code = 'IFSPingFerderateServiceURL'
          ) 
BEGIN
    UPDATE InforCETenantConfig.dbo.SystemConfiguration 
       SET Value = 'https://mingle-ifsservice.eu1.inforcloudsuite.com/'
         , UpdatedOn = GETUTCDATE() 
     WHERE Code = 'IFSPingFerderateServiceURL'
END;

/*fix typo*/
IF EXISTS ( SELECT Code 
              FROM InforCETenantConfig.dbo.SystemConfiguration 
             WHERE Code = 'IFSPingFerderateServiceURL'
               AND Value = 'https://mingle-ifsservice.eu1.inforcloudsuite.com/'
               AND CreatedOn = '2016-02-29 15:13:14.520'
               AND UpdatedOn BETWEEN DATEADD(n,1,GETUTCDATE()) AND GETUTCDATE()
          ) 
BEGIN
    UPDATE InforCETenantConfig.dbo.SystemConfiguration 
       SET Code = 'IFSPingFederateServiceURL'
         , UpdatedOn = GETUTCDATE() 
     WHERE Value = 'https://mingle-ifsservice.eu1.inforcloudsuite.com/'
       AND UpdatedOn BETWEEN DATEADD(n,1,GETUTCDATE()) AND GETUTCDATE()
       AND CreatedOn = '2016-02-29 15:13:14.520'
END;

/*print data to screen*/
  EXEC ( 'SELECT *
            FROM ' + @DB + '.' + @Schema + '.' + @Table
       ) ;

/*backup database*/
  EXEC util.dbo.usp_backup_db @bu_type = 'full'
     , @dbname = @DB
     , @comment = 'After';
