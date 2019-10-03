--efinancials -
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[tblACHData]
           SET AccountNo = ''1'''
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[tblBankAccount]
           SET AccountNo = ''1'''
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[tblPayee]
           SET taxId = NULL'
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[tblPayeeDirectDeposit]
           SET accountnumber = ''1''
             , emailaddress = ''dummy@dummy.com'''
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[tblTransmitter]
           SET FederalTaxID = NULL'
     ) ;
EXEC ( 'DELETE 
          FROM [' + @scrubDbName + '][dbo].[tblWebServiceSetup]'
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[tblAddressBook]
           SET email = ''dummy@dummy.com'''
     ) ;
 
--eService -
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[tblAddressBook]
           SET email = ''dummy@dummy.com'''
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[tblEmployee]
           SET DLNo = NULL
             , SSN = NULL'
     ) ;
EXEC ( 'DELETE 
          FROM [' + @scrubDbName + '][dbo].[tblWebServiceSetup]'
     ) ;
 
--eSite -
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[additionalinsured]
           SET email = ''dummy@dummy.com'''
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[addressbook]
           SET email = ''dummy@dummy.com'''
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[bankbookheader]
           SET bankacctno = ''1'''
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[credithistory]
           SET dlnumber = NULL
             , email = NULL'
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[creditscreenhistory]
           SET xmldata = NULL'
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[directrent]
           SET originaba = NULL
             , destinationaba = NULL
             , fedid = NULL'
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[epaysetup]
           SET bankacct = ''1'''
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[micrscanner]
           SET acctno = ''1'''
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[occupantheader]
           SET occussn = NULL
             , ssn_encrypted = NULL'
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[transactionheader]
           SET imagedata = NULL
             , imagedataback = NULL'
     ) ;
EXEC ( 'UPDATE [' + @scrubDBName + '].[dbo].[unqualguests]
           SET ssn = NULL
             , ssn_encrypted = NULL'
     ) ;
EXEC ( 'DELETE 
          FROM [' + @scrubDbName + '][dbo].[webservicelogin]'
     ) ;