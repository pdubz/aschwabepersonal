/*
**RUN THE FIRST BLOCK FIRST AND SEPARATELY**
*/
--Get Logical File Names
RESTORE FILELISTONLY
   FROM DISK = N'\\172.22.240.48\esite\esite07\full\eFinancialsVerityManagement\eFinancialsVerityManagement_full_20150119020826.bak'
     GO

--Restore Full
RESTORE DATABASE [eFinancialsVerityManagement_20150119-1900] 
   FROM DISK = N'\\172.22.240.48\esite\esite07\full\eFinancialsVerityManagement\eFinancialsVerityManagement_full_20150119020826.bak'
   WITH FILE = 1
      , MOVE 'eFinancials6' TO N'F:\data01\data\eFinancialsVerityManagement_20150119-1900.mdf'
      , MOVE 'eFinancials6_log' TO N'F:\logs01\data\eFinancialsVerityManagement_20150119-1900.ldf'
      , NORECOVERY
      , STATS = 10;
     GO

--Restore Diff      
RESTORE DATABASE [eFinancialsVerityManagement_20150119-1900] 
   FROM DISK = N'\\172.22.240.48\esite\esite07\diff\eFinancialsVerityManagement\eFinancialsVerityManagement_diff_20150119180127.diff'
   WITH FILE = 1
      , NORECOVERY
      , STATS = 10;
     GO

--Restore Logs
RESTORE LOG [eFinancialsVerityManagement_20150119-1900]
   FROM DISK = N'\\infran001\sql_tlog01\esite\esite07\eFinancialsVerityManagement\eFinancialsVerityManagement\eFinancialsVerityManagement_log_20150119180721.trn'
   WITH FILE = 1
      , NORECOVERY
      , STATS = 10;
     GO

RESTORE LOG [eFinancialsVerityManagement_20150119-1900]
   FROM DISK = N'\\infran001\sql_tlog01\esite\esite07\eFinancialsVerityManagement\eFinancialsVerityManagement\eFinancialsVerityManagement_log_20150119181709.trn'
   WITH FILE = 1
      , NORECOVERY
      , STATS = 10;
     GO
      
RESTORE LOG [eFinancialsVerityManagement_20150119-1900]
   FROM DISK = N'\\infran001\sql_tlog01\esite\esite07\eFinancialsVerityManagement\eFinancialsVerityManagement\eFinancialsVerityManagement_log_20150119182720.trn'
   WITH FILE = 1
      , NORECOVERY
      , STATS = 10;
     GO
      
RESTORE LOG [eFinancialsVerityManagement_20150119-1900]
   FROM DISK = N'\\infran001\sql_tlog01\esite\esite07\eFinancialsVerityManagement\eFinancialsVerityManagement\eFinancialsVerityManagement_log_20150119183739.trn'
   WITH FILE = 1
      , NORECOVERY
      , STATS = 10;
     GO
      
RESTORE LOG [eFinancialsVerityManagement_20150119-1900]
   FROM DISK = N'\\infran001\sql_tlog01\esite\esite07\eFinancialsVerityManagement\eFinancialsVerityManagement\eFinancialsVerityManagement_log_20150119184745.trn'
   WITH FILE = 1
      , NORECOVERY
      , STATS = 10;
     GO
      
RESTORE LOG [eFinancialsVerityManagement_20150119-1900]
   FROM DISK = N'\\infran001\sql_tlog01\esite\esite07\eFinancialsVerityManagement\eFinancialsVerityManagement\eFinancialsVerityManagement_log_20150119185723.trn'
   WITH FILE = 1
      , RECOVERY
      , STATS = 10;
     GO