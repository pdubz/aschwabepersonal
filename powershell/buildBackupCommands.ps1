Param(
    [Parameter(Mandatory=$true)][string]$appName,
    [Parameter(Mandatory=$true)][string][ValidateSet("full","diff","log")]$buType,
    [Parameter(Mandatory=$true)][string]$migration_date
)

#directory for db name txt files
$instancetxtPath = "$env:USERPROFILE\Documents\instances"
#directory where the backup commands will go
$bkupCMDPath = "$instancetxtPath\bkupCMDs"

#test for directory where the backup commands will go
if(-not(Test-Path $bkupCMDPath)){New-Item -Path $bkupCMDPath -ItemType Directory}

#remove old commands
Remove-Item -Path $bkupCMDPath\*

#cd to txt files with db names
Set-Location -Path $instancetxtPath

#ensure empty arrays
$backupCMDs = @()
$singleCMDS = @()
$multiCMDS = @()
$instances = @()

#get all files and load into a variable
$instances = Get-ChildItem -Path $instancetxtPath | where { ! $_.PSIsContainer } 

#make $buType upper case
$buType = $buType.ToUpper()

#build mirror path
$mirrorPath = "\\172.22.240.45\dba_windows_xfer_share01\$appName\$migration_date\$buType"

#loop through each txt file
foreach($instance in $instances){
    
    #load txt files into variable
    $databases = @()
    $databases = Get-Content -Path $instance 
    
    #put instance name into variable
    $dc4Instance = ''
    $dc4Instance = $instance.Name.Split('.')[0]    
    
    #build the backup command
    foreach($database in $databases){
            
        #put backup command into variable
        $backupDBCMD = '' 
        $backupDBCMD = 

#, @bu_path  = '$mirrorPath'
#, @comment  = 'AWS'

@"
--take a $buType copy only backup of [$database] to dba_windows_xfer_share01
exec dba.dbo.usp_backup_db @bu_type  = '$buType'
                         , @dbname   = '$database'
"@
        #add backup command to array
        $backupCMDs += $backupDBCMD

        #put single user command into variable
        $singleUserCMD = ''
        $singleUserCMD = 
@"
--set $database to single user mode
  USE master;
   GO
ALTER DATABASE [$database]
  SET SINGLE_USER
 WITH ROLLBACK IMMEDIATE;
   GO

"@
        #add single user command to array
        $singleCMDS += $singleUserCMD
        
        #put multi user command into variable
        $multiUserCMD = '' 
        $multiUserCMD = 
@"
--set $database to multi user mode
  USE master;
   GO
ALTER DATABASE [$database]
  SET MULTI_USER
   GO

"@
        #add multi user command to array
        $multiCMDS += $multiUserCMD
    }

    #build file names
    $bkupFileName = ''
    $bkupFileName = $dc4Instance + "_$buType" + "_backupCMDs.sql"
    $singleMultiFileName = $dc4Instance + "_single_and_multiUserCMDs.sql"


    #write new commands
    Out-File -InputObject $backupCMDs -FilePath $bkupCMDPath\$bkupFileName
    Out-File -InputObject $singleCMDS -FilePath $bkupCMDPath\$singleMultiFileName
    Out-File -InputObject $multiCMDS -FilePath $bkupCMDPath\$singleMultiFileName -Append
    
    #clear the arrays
    $backupCMDs = @()
    $singleCMDS = @()
    $multiCMDS = @()
}

<#mirror backup (deprecated)
@"
--take a $buType backup of [$database] to infraq001 and dba_windows_xfer_share01
exec dba.dbo.usp_backup_db @bu_type = '$buType'
                         , @dbname = '$database'
                         , @bu_path = '\\172.22.240.48\$appName\$dc4Instance\$buType'
                         , @comment = 'AWS'
                         , @mirror_path = '$mirrorPath'
"@
#>
