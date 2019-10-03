param(
    [parameter(mandatory=$true)][string]$primary_node,
    [parameter(mandatory=$true)][string]$recovery,
    [parameter(mandatory=$true)][string][validateset('full','diff','log')]$backup_type
)

#import SQL Powershell module
Import-Module sqlps -DisableNameChecking

Set-Location C:\

#get current date
$dt = Get-Date -Format "yyyyMMdd-hhmmss"

#set importexport path
$importExportPath = "\\$primary_node\importexport"

#check to see if the required folder is there. If not, create it.
if(!(Test-Path "$importExportPath\restoreCMDs")){
    New-Item -Path $importExportPath -Name "restoreCMDs" -ItemType Directory
}

#name the restore file
$restoreFile = "$dt`_$backup_type`_restores.sql"

#create the restore file
New-Item -Path "$importExportPath\restoreCMDs" -Name $restoreFile -ItemType File

$restoreFilePath = "$importExportPath\restoreCMDs\$restoreFile"

#create blank variables
$fileList = @()
$dbnameList = @()
$restoredDBs = @()
$restoreFileListCMD = ''
$restoreDatabaseCMD = ''

#set data and log directories
$dataDir = 'E:\data01\data'
$logDir = 'E:\logs01\data'

#set recovery parameter
$recovery = $recovery.ToLower()
if($recovery -eq 'yes'){$recovery = 'RECOVERY'}
elseif($recovery -eq 'no'){$recovery = 'NORECOVERY'}

#get content from text files
$fileList = Get-Content "$importExportPath\_restoredbfiles.txt"
$dbnameList = Get-Content "$importExportPath\_restoredbnames.txt"


#create restore based on backup type
switch($backup_type){
    'full'{
        for($i=0;$i -lt $fileList.Length;$i++){
            $restoreDatabaseCMD = ''
            $restoreFileListCMD = ''
            $dbname = ''
            $file = ''

            $dbname = $dbnameList[$i]
            $file = $fileList[$i]

            $restoreFileListCMD = 
@"
restore filelistonly
   from disk = N'$file'
"@
            $outputs = Invoke-Sqlcmd -Query $restoreFileListCMD -ServerInstance $primary_node -Database master

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
                    $restoreDatabaseCMD = 
@"
--restore $dbname with $recovery from $backup_type file: $file
RESTORE DATABASE [$dbname] 
   FROM DISK = N'$file'
   WITH FILE = 1
      , MOVE '$dataName' TO N'$dataDir\$dbname`_data.mdf'
      , MOVE '$logName' TO N'$logDir\$dbname`_log.ldf'
      , $recovery
      , STATS = 10

"@
                    Out-File -FilePath $restoreFilePath -InputObject $restoreDatabaseCMD -Append
                    $restoredDBs += $dbname
                }
            }
            else{
            $numRestored = $restoredDBs.Count
            Write-Host 
@"
Restored $numRestored databases. Stopped on $dbname. 
Data Name: $dataName
Log Name : $logName
---------------------------------------
$restoredDBs
"@
            }
        }
    }
    'diff'{
        for($i=0;$i -lt $fileList.Length;$i++){
            $restoreDatabaseCMD = ''
            $dbname = ''
            $file = ''

            $dbname = $dbnameList[$i]
            $file = $fileList[$i]

            $restoreDatabaseCMD = 
@"
--restore $dbname with $recovery from $backup_type file: $file
RESTORE DATABASE [$dbname] 
    FROM DISK = N'$file'
    WITH FILE = 1
       , $recovery
       , STATS = 10

"@
            Out-File -FilePath $restoreFilePath -InputObject $restoreDatabaseCMD -Append
            $restoredDBs += $dbname
        }
    }
    'log'{
        
    }
}
