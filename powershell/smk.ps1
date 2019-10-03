Import-Module SQLPS -DisableNameChecking
Import-Module C:\salt\scripts\modules\InforSQL\InforSQL.psm1 -DisableNameChecking
Import-Module C:\salt\scripts\modules\InforAWS\InforAWS.psm1 -DisableNameChecking
Import-Module C:\salt\scripts\modules\InforGeneral\InforGeneral.psm1 -DisableNameChecking

Set-Location C:\salt\scripts

$startDay = Get-Date -Format 'yyyyMMdd'
$startDT = Get-Date -Format 'yyyyMMdd-hhmmss'
$primary = SQLAG-GetPrimary
$secondaries = SQLAG-GetSecondaries
$smkLocation = "\\$primary\importexport\$startDay-smk"
$smkPassword = "oYe4qFGjcBd"

$getSMKQuery = "select @@servername as [server], key_guid from master.sys.symmetric_keys where name = '##MS_ServiceMasterKey##'"
$backupSMKQuery = "BACKUP SERVICE MASTER KEY TO FILE = '$smkLocation' ENCRYPTION BY PASSWORD = '$smkPassword'"
$restoreSMKQuery = "RESTORE SERVICE MASTER KEY FROM FILE = '$smkLocation' DECRYPTION BY PASSWORD = '$smkPassword' FORCE"

$GUID = Invoke-Sqlcmd -ServerInstance $primary -Query $getSMKQuery
Print-Screen -data $GUID.server -severity info
Print-Screen -data $GUID.key_guid -severity info

foreach($secondary in $secondaries)
{
    $GUID = Invoke-Sqlcmd -ServerInstance $secondary.Name -Query $getSMKQuery
    Print-Screen -data $GUID.server -severity info
    Print-Screen -data $GUID.key_guid -severity info
}

Invoke-Sqlcmd -ServerInstance $primary -Query $backupSMKQuery

foreach($secondary in $secondaries)
{
    $sec = $secondary.Name
    $secondaryBackupSMKQuery = "BACKUP SERVICE MASTER KEY TO FILE = '\\$sec\importexport\$startDT-$sec-smk' ENCRYPTION BY PASSWORD = '$smkPassword'"
    Invoke-Sqlcmd -ServerInstance $sec -Query $secondaryBackupSMKQuery
    Invoke-Sqlcmd -ServerInstance $sec -Query $restoreSMKQuery
}

Print-Screen -data "====================================================================" -severity info

$GUID = Invoke-Sqlcmd -ServerInstance $primary -Query $getSMKQuery
Print-Screen -data $GUID.server -severity info
Print-Screen -data $GUID.key_guid -severity info

foreach($secondary in $secondaries)
{
    $GUID = Invoke-Sqlcmd -ServerInstance $secondary.Name -Query $getSMKQuery
    Print-Screen -data $GUID.server -severity info
    Print-Screen -data $GUID.key_guid -severity info
}

C:\utilities\sdelete.exe -p 3 $smkLocation /accepteula
