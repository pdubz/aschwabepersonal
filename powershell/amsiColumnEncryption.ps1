Param(
    [Parameter(Mandatory=$true)][string]$awsInstance
)

#create blank array variables
$instances = @()
$databases = @()
$CMDs = @()
$newPass = @{}

#create path to text files
$txtPath = "$env:USERPROFILE\Documents\instances"

Set-Location $txtPath

#create output path
$outCMDPath = "$env:USERPROFILE\Documents\instances\encryptionCMDs"

#if $outCMDPath directory exists, terminate it and everything in it with extreme prejudice
if(Test-Path -Path $outCMDPath){Remove-Item -Path $outCMDPath -Recurse -Force}

#get a list of all files in $txtPath and put it into an array ($instances)
$instances = Get-ChildItem -Path $txtPath\* -Filter *.txt

#create $outCMDPath
New-item -Path $outCMDPath -ItemType Directory

#loop through all text files
foreach($instance in $instances){
    
    #ensure databases array and outCMDFile is empty
    $databases = @()
    $outCMDFile = ''
    
    #read from text file for this $instance and input each line (database) into the $databases array
    $databases = Get-Content $instance.FullName

    #get the instance name without .txt on the end
    $instanceName = $instance.BaseName

    #loop through all the databases for that $instance
    foreach($database in $databases){
        
        #create blank string and array variables
        $dc4Password = ''
        $awsPassword = ''
        $CMD = @()

        #create dc4 password
        $dc4Password = "$instanceName" + "$database"

        #create aws password
        $awsPassword = "$awsInstance" + "$database"

        #create the command 
        $CMD = 
@"
--open $database, remove old encryption, add new encryption
OPEN MASTER KEY DECRYPTION BY PASSWORD = '$dc4Password'
ALTER MASTER KEY ADD ENCRYPTION BY SERVICE MASTER KEY
ALTER MASTER KEY DROP ENCRYPTION BY PASSWORD = '$dc4Password'
ALTER MASTER KEY ADD ENCRYPTION BY PASSWORD = '$awsPassword'

"@
        #export the command to the other variable
        $CMDs += $CMD
        $newPass.Add($database,$awsPassword)
    }
}

#get date/time to append to file name
$dt = Get-Date -Format 'yyyyMMdd-HHmmss'

#output to file
Out-File -FilePath "$outCMDPath\$dt-encryptionCMDs.sql" -InputObject $CMDs

#output database name and password to csv
$newPass.getEnumerator() | Select-Object @{Name="Database";Expression={$_.Name}},@{Name="Password";Expression={$_.Value}} |
Export-Csv -Path "$env:USERPROFILE\Documents\$dt-$awsInstance-EncryptionPasswords.csv" -NoTypeInformation
