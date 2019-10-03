Param(
[Parameter(Mandatory=$true)][string]$database_name,
[Parameter(Mandatory=$false)][string]$login_name=$null
)
Import-Module C:\salt\scripts\api\helperfunctions.psm1 -DisableNameChecking
Import-Module C:\salt\scripts\modules\jackdb\jackdb.psm1 -DisableNameChecking
Import-Module c:\salt\tasks\saltmod.psm1 -DisableNameChecking

$Grains = Get-Grains

$account = Get-IAMAccountAlias
$bucket_path = "s3://" + ((Get-IAMAccountAlias) + "-backups-" + (Get-Region)) + "/mssql/"

$Primary = Get-PrimaryReplica -Grains $Grains
$PrimaryHost = Get-PrimaryServer -Grains $Grains

if((Get-Role) -eq "AlwaysOn"){
    $AG = Get-ClusterResource | Where-Object { $_.ResourceType -eq "SQL Server Availability Group" }
}

if($AG){ 
    $secondary_replicas = [System.Collections.ArrayList](Invoke-Sqlcmd -Query ("EXEC api_alias.GetReplicas") -ServerInstance $env:computername -Database "util" -ErrorAction Stop).replica_server_name
    $secondary_replicas.Remove($primary)
}

$backup_comment = "_" + (Get-Date -format "yyyyMddhhmmss") + "_FINAL_OFFLINE_BACKUP"
Invoke-Sqlcmd -Query ("EXEC api_alias.BackupDB @db = N'$database_name', @comment = N'$backup_comment'") -Database "util" -ErrorAction Stop -ServerInstance $Primary

#save copy of final offline backup to S3 (uses PutFile API call internally)
cd c:\salt\scripts\api
$file = $database_name + $backup_comment + ".bak"
try
{
    C:\salt\scripts\api\PutFile.ps1 -file_name_list "\\$primaryhost\backup\full\$database_name\$file" -dest_path $bucket_path -ErrorAction Stop
}
catch
{
    throw [System.Exception] ("Error storing $file in $bucket_path : $_") 
}

if((Invoke-Sqlcmd -Query ("EXEC api_alias.CheckAGForDB @db = N'$database_name'") -ServerInstance $primary -Database "util" -ErrorAction Stop).Exists)
{
    #tear down availability group
    foreach ($replica in $secondary_replicas)
    {
        $database_files = (Invoke-Sqlcmd -Query ("EXEC api_alias.GetDatabaseFiles @db = N'$database_name'") -ServerInstance $replica -Database "util" -ErrorAction Stop -QueryTimeout 0).physical_name           
        Invoke-Sqlcmd -Query ("EXEC	api_alias.DetachDB @db = N'$database_name'") -ServerInstance $replica -Database "util" -ErrorAction SilentlyContinue -QueryTimeout 0
        cd C:\salt\scripts\api
        Invoke-SDelete -database_files $database_files -server $replica

        if($login_name.Length -ne 0)
        {
           Invoke-Sqlcmd -Query ("EXEC api_alias.DropLogin @login_name = N'$login_name'") -ServerInstance $replica -Database "util" -ErrorAction Stop -QueryTimeout 0
        }
    }
    Invoke-Sqlcmd -Query ("EXEC api_alias.RemoveDBFromAG @db = N'$database_name', @ag = N'AG1'") -ServerInstance $Primary -Database "util" -ErrorAction Stop  -QueryTimeout 0    
}
$database_files = (Invoke-Sqlcmd -Query ("EXEC api_alias.GetDatabaseFiles @db = N'$database_name'") -ServerInstance $Primary -Database "util" -ErrorAction Stop -QueryTimeout 0).physical_name       
Invoke-Sqlcmd -Query ("EXEC	api_alias.DetachDB @db = N'$database_name'") -ServerInstance $Primary -Database "util" -ErrorAction SilentlyContinue -QueryTimeout 0

#shred db files
cd C:\salt\scripts\api
Invoke-SDelete -database_files $database_files -server $primary
if($login_name.Length -ne 0)
{
   Invoke-Sqlcmd -Query ("EXEC api_alias.DropLogin @login_name = N'$login_name'") -ServerInstance $Primary -Database "util" -ErrorAction Stop -QueryTimeout 0
}
try{
    $AppName = Get-AppName
    Remove-JackDBDatasource -database_name $database_name -app_name $AppName -role ro
    Remove-JackDBDatasource -database_name $database_name -app_name $AppName -role rw
}catch{
    Write-JackDBError $_
}
