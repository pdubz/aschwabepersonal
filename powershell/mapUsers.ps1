Param(
    [Parameter(Mandatory=$true)][string[]]$users,
    [Parameter(Mandatory=$false)][string]$role='db_owner'
)

$databases = @()

$userMapping = "$env:USERPROFILE\Documents\_mapUsers.sql"
Remove-Item $userMapping


$databases = Get-Content -Path "$env:USERPROFILE\Documents\dbs.txt"
        
        
foreach($database in $databases){
    foreach($user in $users){
        $userMapCMD = 
@"
--Map $user to $database with db_owner priviledges    
   use [$database]
    go
create user [$user] for login [$user]
    go
   use [$database]
    go
 alter role [$role] add member [$user]
    go
"@
        Out-File -FilePath $userMapping -InputObject $userMapCMD -Append
        $userMapCMD = ''
    }
}
