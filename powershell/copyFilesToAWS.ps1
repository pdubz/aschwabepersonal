param(
    [Parameter(Mandatory=$true)][string]$awsInstanceIP,
    [Parameter(Mandatory=$true)][string]$app,
    [Parameter(Mandatory=$true)][string]$migrationDate,
    [Parameter(Mandatory=$true)][string][ValidateSet('full','diff','log')]$buType,
    [Parameter(Mandatory=$true)][string[]]$users
)

$buType = $buType.ToUpper()

#set directories
$dc4Directory = "\\172.22.244.45\dba_windows_xfer_share01\$app\$migrationDate\$buType"
$awsDirectory = "\\$awsInstanceIP\importexport\$buType"

if(-not(Test-Path $awsDirectory)){New-Item -Path $awsDirectory -ItemType Directory}

#Change directory
Set-Location $awsDirectory

#set API txt and sql file locations
$restoreDBNames = "$awsDirectory\_restoredbnames.txt"
$restoreFiles = "$awsDirectory\_restoredbfiles.txt"
$userMapping = "$awsDirectory\_mapUsers.sql"
$dbownerChange = "$awsDirectory\_dbownerChange.sql"

#remove old txt files if they exist
if(Test-Path $restoreDBNames){Remove-Item -Path $restoreDBNames -Force}
if(Test-Path $restoreFiles){Remove-Item -Path $restoreFiles -Force}
if(Test-Path $userMapping){Remove-Item -Path $userMapping -Force}
if(Test-Path $dbownerChange){Remove-Item -Path $userMapping -Force}

#create new txt files
New-Item -Path $restoreDBNames -ItemType File
New-Item -Path $restoreFiles -ItemType File 
New-Item -Path $userMapping -ItemType File
New-Item -Path $dbownerChange -ItemType File

#go through dc4 share and get all of the files that aren't a directory
$dc4Files = Get-ChildItem -Path $dc4Directory -Recurse | Where-Object { ! $_.PSIsContainer }

#loop through files in DC4
foreach($file in $dc4Files){
    
    #ensure blank variables
    $dbname = ''
    $dbownerCMD = ''
    $userMapCMD = ''
    $awsFile = ''

    #copy DC4 files to AWS
    Copy-Item -Path $file.FullName -Destination $awsDirectory -Verbose
    
    $awsFile = "$awsDirectory\$file"

    #log filepath into AWS
    Out-File -FilePath $restoreFiles -InputObject $awsFile -Append
    
    #test file length to ensure the substring will work
    if($file.BaseName.Length -gt '23'){

        #drop backup type, timestamp, and comment to get just the database name
        $dbname = $file.Name.Substring(0,($file.BaseName.Length-24))
           
        #log database name
        Out-File -FilePath $restoreDBNames -InputObject $dbname -Append

        #change dbowner
        $dbownerCMD = "
--Change dbowner for $dbname from amsi to 'prod\sqlprod_svc'
Use [$dbname]; exec sp_changedbowner 'prod\sqlprod_svc'
        "

        #log dbowner change commands
        Out-File -FilePath $dbownerChange -InputObject $dbownerCMD -Append

        #add users to each db
        foreach($user in $users){
            $userMapCMD = "
--Map $user to $dbname with db_owner priviledges    
    use [$dbname]
        go
    create user [$user] for login [$user]
        go
    use [$dbname]
        go
    alter role [db_owner] add member [$user]
        go
            "

        #log user mapping commands
        Out-File -FilePath $userMapping -InputObject $userMapCMD -Append
        $userMapCMD = ''
        }
    }
}
