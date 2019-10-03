
/*---------------------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------------------*/

(@P0 nvarchar(4000),@P1 nvarchar(4000))
select count(*) 
  from [ncr_inforce01_IP_IOBOX01].dbo.COR_INBOX_ENTRY 
 where C_WAS_PROCESSED=0 
   and C_TENANT_ID = @P0 
   AND C_LOGICAL_ID=@P1  

/*---------------------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------------------*/

(@P0 nvarchar(4000),@P1 nvarchar(4000))
select top 100 inbox.C_ID
     , cast(C_XML as varchar(max)) as BOD_XML
     , C_MESSAGE_PRIORITY
     , tracking.C_INBOX_ID as TRACKING_ID 
  from [ncr_inforce01_IP_IOBOX01].dbo.COR_INBOX_ENTRY inbox 
  left join [ncr_inforce01_IP_CONFIG01].dbo.IP_INBOX_TRACKING tracking 
    on tracking.C_INBOX_ID = inbox.C_ID 
 where tracking.C_INBOX_ID is null 
   and C_WAS_PROCESSED=0 
   and inbox.C_TENANT_ID = @P0 
   and inbox.C_LOGICAL_ID=@P1 
 order by inbox.C_ID    

/*---------------------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------------------*/

(@P0 nvarchar(4000),@P1 nvarchar(4000))
select count(*) 
  from [ncr_inforce01_IP_IOBOX01].dbo.COR_OUTBOX_ENTRY 
 where C_WAS_PROCESSED=0 
   and C_TENANT_ID = @P0 
   and C_LOGICAL_ID=@P1    

/*---------------------------------------------------------------------------------------------------------*/
/*---------------------------------------------------------------------------------------------------------*/

