function SQL-CheckUserInDB
{
    param( [Parameter(mandatory=$true)][string]$dbname
         , [Parameter(mandatory=$true)][string]$username
         , [switch]$suppress)
    Import-Module SQLPS -DisableNameChecking
    Import-Module C:\salt\scripts\modules\InforGeneral\InforGeneral.psm1 -DisableNameChecking
    Set-Location -Path 'C:\salt\scripts'
    $query = ''
    $query = "SELECT [name] AS Name FROM [master].[sys].[databases] WHERE [name] = '$dbname'"
    $database_name = (Invoke-Sqlcmd -Query $query)
    Set-Location -Path 'C:\salt\scripts'
    if(!$database_name)
    {
         $data = "The $dbname database does not exist on $env:COMPUTERNAME."
         Write-Output -InputObject $data
         if(!$suppress)
         {
            Print-Screen -data $data -severity error
         }
    }
    else
    {
        $query = "SELECT CONVERT(VARCHAR(1000),[sid],1) AS SID FROM [master].[sys].[syslogins] WHERE [name] = '$username'"
        $masterSID = (Invoke-Sqlcmd -Query $query).SID
        Set-Location -Path 'C:\salt\scripts'
        if(!$masterSID)
        {
            $data = "The $username user does not exist on $env:COMPUTERNAME in the master database."
            Write-Output -InputObject $data
            if(!$suppress)
            {
                Print-Screen -data $data -severity error
            }
        }
        else
        {
            $query = "SELECT CONVERT(VARCHAR(1000),[sid],1) AS SID FROM [$dbname].[sys].[database_principals] WHERE [name] = '$username'"
            $dbSID = (Invoke-Sqlcmd -Query $query).SID
            Set-Location -Path 'C:\salt\scripts'
            if(!$dbSID)
            {
                $data = "The $username user does not exist in the $dbname database."
                Write-Output -InputObject $data
                if(!$suppress)
                {
                    Print-Screen -data $data -severity Notice
                }
            }
            elseif($masterSID -eq $dbSID)
            {
                $data = "The $username user is already mapped to the $dbname database."
                Write-Output -InputObject $data
                if(!$suppress)
                {
                    Print-Screen -data $data -severity notice
                }
            }
            else
            {
                $data = "The $username user's SID in the master database is different than the $username user's SID in the $dbname database."
                Write-Output -InputObject $data
                if(!$suppress)
                {
                    Print-Screen -data $data -severity error
                }
            }
        }
    }
}

function SQL-AddUserToDB
{
    param( [Parameter(mandatory=$true)][string]$dbname
         , [Parameter(mandatory=$true)][string]$username)
    Import-Module SQLPS -DisableNameChecking
    Import-Module C:\salt\scripts\modules\InforGeneral\InforGeneral.psm1 -DisableNameChecking
    $query = ''
    $message = SQL-CheckUserInDB -dbname $dbname -username $username -suppress
    switch -Wildcard ($message)
    {
        "*database does not exist on*"
        {
            $data = "The $dbname database does not exist on $env:COMPUTERNAME so the $username user cannot be added to it."
            Print-Screen -data $data -severity error
        }
        "*user does not exist on*"
        {
            $data = "The $username user does not exist at the $env:COMPUTERNAME server level. Please add the user to the $env:COMPUTERNAME server before attempting to add to the $dbname database."
            Print-Screen -data $data -severity error
        }
        "*user does not exist in the*"
        {
            try
            {
                $query = "USE [$dbname]; CREATE USER [$username] FOR LOGIN [$username];"
                Invoke-Sqlcmd -Query $query
                Set-Location C:\salt\scripts
                $data = "The $username user has been added to the $dbname database."
                Print-Screen -data $data -severity info
            }
            catch
            {
                $data = "Attempted to add the $username user to the $dbname database but encountered a terminating error. `r`n $_"
                Print-Screen -data $data -severity error
            }
        }
        "*user is already mapped to*"
        {
            Print-Screen -data $message -severity warning
        }
        "*user's SID in the master database*"
        {
            $data = "The $username user's SID in the master database is different than the $username user's SID in the $dbname database."
            Print-Screen -data $message -severity error
        }
    }
}

function SQL-RemoveUserFromDB
{
    param( [Parameter(mandatory=$true)][string]$dbname
         , [Parameter(mandatory=$true)][string]$username)
    Import-Module SQLPS -DisableNameChecking
    Import-Module C:\salt\scripts\modules\InforGeneral\InforGeneral.psm1 -DisableNameChecking
    $query = ''
    $message = SQL-CheckUserInDB -dbname $dbname -username $username -suppress
    switch -Wildcard ($message)
    {
        "*database does not exist on*"
        {
            $data = "The $dbname database does not exist on $env:COMPUTERNAME so the $username user cannot be added to it."
            Print-Screen -data $data -severity error
        }
        "*user does not exist on*"
        {
            $data = "The $username user does not exist at the $env:COMPUTERNAME server level. Checking inside the $dbname database and removing if found there."
            Print-Screen -data $data -severity notice
            $query = "SELECT CONVERT(VARCHAR(1000),[sid],1) AS SID FROM [$dbname].[sys].[database_principals] WHERE [name] = '$username';"
            $dbSID = (Invoke-Sqlcmd -Query $query).SID
            Set-Location -Path 'C:\salt\scripts'
            if(!$dbSID)
            {
                $data = "The $username user does not exist at the $env:COMPUTERNAME server level or at the $dbname database level."
                Print-Screen -data $data -severity error
            }
            else
            {
                try
                {
                    $query = "USE [$dbname]; DROP USER [$username];"
                    Invoke-Sqlcmd -Query $query
                    Set-Location C:\salt\scripts
                    $data = "The $username user has been removed from the $dbname database."
                    Print-Screen -data $data -severity info
                }
                catch
                {
                    $data = "Attempted to remove the $username user from the $dbname database but encountered a terminating error. `r`n $_"
                    Print-Screen -data $data -severity error
                }
            }
        }
        "*user does not exist in the*"
        {
            $data = "The $username user does not exist in the $dbname database so it cannot be removed."
            Print-Screen -data $data -severity notice
        }
        "*user is already mapped to*"
        {
            try
            {
                $query = "USE [$dbname]; DROP USER [$username];"
                Invoke-Sqlcmd -Query $query
                Set-Location C:\salt\scripts
                $data = "The $username user has been removed from the $dbname database."
                Print-Screen -data $data -severity info
            }
            catch
            {
                $data = "Attempted to remove the $username user from the $dbname database but encountered a terminating error. `r`n $_"
                Print-Screen -data $data -severity error
            }
        }
        "*user's SID in the master database*"
        {
            try
            {
                $query = "USE [$dbname]; DROP USER [$username];"
                Invoke-Sqlcmd -Query $query
                Set-Location C:\salt\scripts
                $data = "The $username user has been removed from the $dbname database."
                Print-Screen -data $data -severity info
            }
            catch
            {
                $data = "Attempted to remove the $username user from the $dbname database but encountered a terminating error. `r`n $_"
                Print-Screen -data $data -severity error
            }
        }
    }
}

function SQL-CheckUserServerRole
{

}

function SQL-CheckUserDBRole
{
    param( [Parameter(mandatory=$true)][string]$dbname
         , [Parameter(mandatory=$true)][string]$username
         , [Parameter(mandatory=$true)][string]$role)
    Import-Module SQLPS -DisableNameChecking
    Import-Module C:\salt\scripts\modules\InforGeneral\InforGeneral.psm1 -DisableNameChecking
    $query = ''
    $message = SQL-CheckUserInDB -dbname $dbname -username $username -suppress
    switch -Wildcard ($message)
    {
        "*database does not exist on*"
        {
            $data = "The $dbname database does not exist on $env:COMPUTERNAME so the $username user cannot be given roles in it."
            Write-Output -InputObject $data
            Print-Screen -data $data -severity error
        }
        "*user does not exist on*"
        {
            $data = "The $username user does not exist at the $env:COMPUTERNAME server level. Please add the user to the $env:COMPUTERNAME server before attempting to add roles to it in the $dbname database."
            Print-Screen -data $data -severity error
        }
        "*user does not exist in the*"
        {
            $data = "The $username user does not exist in the $dbname database so it cannot have roles assigned to it."
            Print-Screen -data $data -severity error
        }
        "*user is already mapped to*"
        {
            $query = "SELECT CONVERT(VARCHAR(1000),[rp].[name],1) AS Role
                        FROM [$dbname].[sys].[database_role_members] drm
                       INNER JOIN [$dbname].[sys].[database_principals] [rp] ON ([drm].[role_principal_id] = [rp].[principal_id])
                       INNER JOIN [$dbname].[sys].[database_principals] [mp] ON ([drm].[member_principal_id] = [mp].[principal_id])
                       WHERE [mp].[name] = '$username'"
            $currentRoles = (Invoke-Sqlcmd -Query $query).Role
            Set-Location -Path 'C:\salt\scripts'
            if(($currentroles.Count) -gt 1)
            {
                foreach($currentRole in $currentRoles)
                {
                    if($role -eq $currentRole)
                    {
                        Print-Screen
                    }
                }
            }
            else
            {

            }
        }
        "*user's SID in the master database*"
        {
            $data = "The $username user's SID in the master database is different than the $username user's SID in the $dbname database."
            Print-Screen -data $message -severity error
        }
    }
    $query = "SELECT CONVERT(VARCHAR(1000),[rp].[name],1) AS Role
                FROM [$dbname].[sys].[database_role_members] drm
               INNER JOIN [$dbname].[sys].[database_principals] [rp] ON ([drm].[role_principal_id] = [rp].[principal_id])
               INNER JOIN [$dbname].[sys].[database_principals] [mp] ON ([drm].[member_principal_id] = [mp].[principal_id])
               WHERE [mp].[name] = '$username'"
    $currentRoles = (Invoke-Sqlcmd -Query $query).Role
    Set-Location -Path 'C:\salt\scripts'
    if(!$currentRoles)
    {
        $data = "The $username user is not mapped to any roles in the $dbname database."
        Print-Screen -data $data -severity notice
    }
    else
    {
        foreach($currentRole in $currentRoles)
        {
            if($role -eq $currentRole)
            {
                $data = "The $username user already has the $role role in the $dbname database."
                Print-Screen -data $data -severity notice
            }
        }
    }
}

function SQL-AddDBUserRole
{
    param( [Parameter(mandatory=$true)][string]$dbname
         , [Parameter(mandatory=$true)][string]$username
         , [Parameter(mandatory=$true)][string]$role)
    Import-Module SQLPS -DisableNameChecking
    Import-Module C:\salt\scripts\modules\InforGeneral\InforGeneral.psm1 -DisableNameChecking
    $query = ''
    $message = SQL-CheckUserInDB -dbname $dbname -username $username -suppress
    switch -Wildcard ($message)
    {
        "*database does not exist on*"
        {
            $data = "The $dbname database does not exist on $env:COMPUTERNAME so the $username user cannot be given roles in it."
            Write-Output -InputObject $data
            Print-Screen -data $data -severity error
        }
        "*user does not exist on*"
        {
            $data = "The $username user does not exist at the $env:COMPUTERNAME server level. Please add the user to the $env:COMPUTERNAME server before attempting to add roles to it in the $dbname database."
            Print-Screen -data $data -severity error
        }
        "*user does not exist in the*"
        {
            $data = "The $username user does not exist in the $dbname database so it cannot have roles assigned to it."
            Print-Screen -data $data -severity error
        }
        "*user is already mapped to*"
        {
            $query = "SELECT CONVERT(VARCHAR(1000),[rp].[name],1) AS Role
                        FROM [$dbname].[sys].[database_role_members] drm
                       INNER JOIN [$dbname].[sys].[database_principals] [rp] ON ([drm].[role_principal_id] = [rp].[principal_id])
                       INNER JOIN [$dbname].[sys].[database_principals] [mp] ON ([drm].[member_principal_id] = [mp].[principal_id])
                       WHERE [mp].[name] = '$username'"
            $currentRoles = (Invoke-Sqlcmd -Query $query).Role
            Set-Location -Path 'C:\salt\scripts'
            if(($currentroles.Count) -gt 1)
            {
                foreach($currentRole in $currentRoles)
                {
                    if($role -eq $currentRole)
                    {
                        Print-Screen
                    }
                }
            }
            else
            {

            }
        }
        "*user's SID in the master database*"
        {
            $data = "The $username user's SID in the master database is different than the $username user's SID in the $dbname database."
            Print-Screen -data $message -severity error
        }
    }
}


function Print-Screen
{
    param( [Parameter(mandatory=$true)][string]$data
         , [Parameter(mandatory=$false)][string][ValidateSet('info','notice','warning','error')]$severity)
    $severity = $severity.ToUpper()
    $now = (Get-Date).ToString()
    Write-Output -InputObject "$severity $now $data"
}

SQL-CheckUserInDB -dbname 'UCM' -username 'UCM'
