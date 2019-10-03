Import-Module C:\salt\scripts\modules\InforSQL\InforSQL.psm1 -DisableNameChecking
Import-Module SQLPS -DisableNameChecking

if(SQLAG-GetPrimary)
{
    $query = ''
    $query = "SELECT [name] FROM [master].[sys].[databases] WHERE [is_trustworthy_on] = 0 and [name] like '%_App'"
    $unTrustworthyAppDBs = (Invoke-SqlCmd -Query $query -ServerInstance $env:COMPUTERNAME).name
    $query = ""
    $unMappedLogins = (Invoke-SqlCmd -Query $query -ServerInstance $env:ComputerName).login
    
    
    foreach($db in $unTrustworthyAppDBs)
    {
        
    }
    
    foreach($login in $unMappedLogins)
    {
        
    }
 }
