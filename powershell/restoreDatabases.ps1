param(
    [parameter(mandatory=$true)][string]$instance,
    [parameter(mandatory=$true)][string][ValidateSet('yes','no')]$recovery
    
)

Import-Module sqlps -DisableNameChecking

$fileList = @()
$dbnameList = @()
$restoredDBs = @()
$restoreFileListCMD = ''
$restoreDatabaseCMD = ''

$fileList = Get-Content -LiteralPath \\$instance\importexport\_badrestorefiles.txt
$dbnameList = Get-Content -LiteralPath \\$instance\importexport\_badrestoredbnames.txt

$dataDir = 'E:\data01\data'
$logDir = 'E:\logs01\data'

$recovery = $recovery.ToLower()
$recovery

if($recovery -eq 'yes'){$recovery = 'RECOVERY'}
elseif($recovery -eq 'no'){$recovery = 'NORECOVERY'}
$recovery
    
for($i=0;$i -lt $fileList.Count;$i++){
    $restoreDatabaseCMD = ''
    $restoreFileListCMD = ''
    $dbname = ''
    $file = ''

    $dbname = $dbnameList[$i]
    $file = $fileList[$i]

    $restoreFileListCMD = "
        restore filelistonly
           from disk = N'$file'
        "
    $outputs = Invoke-Sqlcmd -Query $restoreFileListCMD -ServerInstance $instance -Database master

    cd C:\Windows\System32

    foreach($output in $outputs){
        $logicalName = $output.LogicalName
        $fileGroupName = $output.FileGroupName
        if($fileGroupName -eq 'PRIMARY'){
            $dataName = $logicalName
        }
        else{
            $logName = $logicalName
        }
    }

    if($dataName.Length -gt 1){ 
        if($logName.Length -gt 1){
            $restoreDatabaseCMD = "
                RESTORE DATABASE [$dbname] 
                   FROM DISK = N'$file'
                   WITH FILE = 1
                      , MOVE '$dataName' TO N'$dataDir\$dbname`_data.mdf'
                      , MOVE '$logName' TO N'$logDir\$dbname`_log.ldf'
                      , $recovery
                      , STATS = 10
                "
        }
        $restoreDatabaseCMD
        #Invoke-Sqlcmd -Query $restoreDatabaseCMD -ServerInstance $instance -Database master
        $restoredDBs += $dbname
    }
    else{
    $numRestored = $restoredDBs.Count
    Write-Host "Restored $numRestored databases. Stopped on $dbname. 
                Data Name: $dataName
                Log Name : $logName
                ---------------------------------------
                $restoredDBs
               "
    }
}

