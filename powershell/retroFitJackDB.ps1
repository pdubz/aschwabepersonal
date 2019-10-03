Import-Module SQLPS -DisableNameChecking
Import-Module AWSPowerShell -DisableNameChecking
Import-Module C:\salt\scripts\modules\JackDB\JackDB.psm1 -DisableNameChecking
Import-Module C:\salt\scripts\modules\InforSQL\InforSQL.psm1 -DisableNameChecking
Import-Module C:\salt\scripts\modules\InforAWS\InforAWS.psm1 -DisableNameChecking

$nodes = @()
$secondaries = @()
$roles = @('ro','rw')
$appName = AWS-GetAppName

function Add-AllDBs{
    $DBsAdded = @()
    $DBsFailed = @()
    $DBsSkipped = @()
    $userDBs = @()
    $roles = @('ro','rw')
    $q1 = "SELECT [name] FROM [master].[sys].[databases] WHERE [name] not in ('master','model','tempdb','msdb','dba','util')"
    $userDBs = Invoke-Sqlcmd -Query $q1 -QueryTimeout 0 

    cd C:\salt\scripts

    $userDBs = $userDBs.Name

    foreach($userDB in $userDBs){
        foreach($role in $roles){
            $datasource = Get-JackDBDatasource -database_name $userDB -app_name $appName -role $role

            if(!$datasource){
                try{
                    $now = (Get-Date).ToString()
                    Write-Host -ForegroundColor Green "[INFO] $now $userDB with the $role role does not currently exist in JackDB. Attempting to add it now..."
                    #find if user in DB -- Infor SQL Function
                    Add-JackDBDatasource -database_name $userDB -app_name $appName -role $role
                    $now = (Get-Date).ToString()
                    Write-Host -ForegroundColor Green "[INFO] $now Successfully added $userDB with the $role role!"
                    $obj = New-Object PSObject
                    $obj | Add-Member -NotePropertyName DB -NotePropertyValue $userDB
                    $obj | Add-Member -NotePropertyName Role -NotePropertyValue $role
                    $DBsAdded += $obj
                }
                catch{
                    $now = (Get-Date).ToString() 
                    Write-Host -ForegroundColor Red "[ERROR] $now Failed to add $userDB with the $role role."
                    $obj = New-Object PSObject
                    $obj | Add-Member -NotePropertyName DB -NotePropertyValue $userDB
                    $obj | Add-Member -NotePropertyName Role -NotePropertyValue $role
                    $DBsFailed += $obj
                    $_
                }
            }
            else{
                $now = (Get-Date).ToString()
                Write-Host -ForegroundColor Yellow "[INFO] $now $userDB with the $role role currently exists in JackDB. Skipping this role for this database..." 
                $obj = New-Object PSObject
                $obj | Add-Member -NotePropertyName DB -NotePropertyValue $userDB
                $obj | Add-Member -NotePropertyName Role -NotePropertyValue $role
                $DBsSkipped += $obj        
            }   
        }
    }
    $addedCount = (($DBsAdded.Count)/2)
    $failedCount = (($DBsFailed.Count)/2)
    $skippedCount = (($DBsSkipped.Count)/2)
    if($failedCount -ne 0){
        Write-Host -ForegroundColor Red '-----------------------------------------------------------------------------------'
        Write-Host -ForegroundColor Red 'Failed DBs-------------------------------------------------------------------------'
        Write-Host -ForegroundColor Red '-----------------------------------------------------------------------------------'
        $DBsFailed | FT -AutoSize
    }
    Write-Host -ForegroundColor Green '-----------------------------------------------------------------------------------'
    Write-Host -ForegroundColor Green 'Summary----------------------------------------------------------------------------'
    Write-Host -ForegroundColor Green '-----------------------------------------------------------------------------------'
    $now = (Get-Date).ToString()
    Write-Host -ForegroundColor Green "$addedCount databases were added into JackDB"
    Write-Host -ForegroundColor Yellow "$skippedCount databases were skipped because they were already in JackDB"
    Write-Host -ForegroundColor Red "$failedCount databases failed to be added to JackDB"
}

if(!(Get-Cluster)){
    $now = (Get-Date).ToString()
    Write-Host -ForegroundColor Green "[INFO] $now Stand Alone SQL Server (1-Node)"
    Write-Host -ForegroundColor Green "[INFO] $now Beginning to initialize JackDB Connections"
    Initialize-JackDBConnections
    cd C:\salt\scripts
    Add-AllDBs
}
else{
    if(!(Get-ClusterResource -Name 'AG1')){
        $now = (Get-Date).ToString()
        Write-Host -ForegroundColor Green "[INFO] $now Traditional Failover Cluster (2-Node)"
        Write-Host -ForegroundColor Green "[INFO] $now Beginning to initialize JackDB Connections"
        Initialize-JackDBConnections
        cd C:\salt\scripts
        Add-AllDBs
    }
    else{
        $nodes = (Get-ClusterNode).Name
        $nodeCount = $nodes.Count
        $now = (Get-Date).ToString()
        Write-Host -ForegroundColor Green "[INFO] $now Always On Availability Group ($nodeCount-Node)"

        foreach($node in $nodes){
            $now = (Get-Date).ToString()
            Write-Host -ForegroundColor Green "[INFO] $now Beginning to initialize JackDB Connections for $node"
            
            Invoke-Command -ComputerName $node {
                Import-Module C:\salt\scripts\modules\JackDB\JackDB.psm1 -DisableNameChecking
                Initialize-JackDBConnections
                cd C:\salt\scripts
            }
        }
        if(SQLAG-IsPrimary){
            Add-AllDBs
        }
    }
}



