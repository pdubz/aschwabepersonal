param(
    [Parameter(Mandatory=$true)][string[]]$email_addresses,
    [Parameter(Mandatory=$true)][string[]][ValidateSet("full","diff","log")]$backup_types
)

#get current date and time
$currentDT = Get-Date -Format 'yyyyMMdd-hhmmss'

#find sql backup location
Import-Module SQLPS -DisableNameChecking
$readBackupLocationCMD = "EXECUTE [master].dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory'"
$backupDir = Invoke-Sqlcmd -ServerInstance $env:COMPUTERNAME -Database "master" -Query $readBackupLocationCMD 
Set-Location "C:\"
$backupDir = $backupDir.Data.ToString()

#set who the email comes from
$from = "$env:computername@$env:USERDNSDOMAIN"
$from = $from.ToLower()

#set the smtp server
$IP = (Get-NetIPConfiguration).IPv4Address
$IP = $IP[0].IPAddress.ToString()
$octets = $IP.Split(".")
$vpc = $octets[1]
$smtp = "smarthost$vpc.$env:USERDNSDOMAIN"

#set HTML head info
$head = "<style>"
$head += "BODY{background-color:White;}"
$head += "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$head += "TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:Gray}"
$head += "TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:White}"
$head += "</style>"

#loop through the backup types
foreach($backup_type in $backup_types){
    #create blank arrays
    $backups = @()
    $backupArray = @()

    #set backup path
    $backupPath = "$backupDir\$backup_type"

    #create subject <datetime-computername-backuptype Backup Files>
    $subject = "$currentDT-$env:COMPUTERNAME-$backup_type Backup Files"

    #get backup files for current backup type (no directories)
    $backups = Get-ChildItem -LiteralPath $backupPath -Recurse | Where-Object { ! $_.PSIsContainer }

    #loop through each file
    foreach($backup in $backups){
        #get the file name
        $fileName = $backup.Name.ToString()
        
        #get the database name
        $dbname = $backup.Directory.Name.ToString()
        
        #create new object
        $backupObject = New-Object PSObject -Property @{
            DatabaseName = $dbname
            FileName = "\\$env:computername\backup\full\$fileName"
            DateCreated = $backup.LastWriteTime
        }
        #add objects to array of objects
        $backupArray += $backupObject
    }

    #convert array of objects to HTML and sort
    $HTMLArray = $backupArray|Select-Object DatabaseName,FileName,DateCreated|
    Sort-Object -Property @{Expression="DatabaseName";Descending=$false}, @{Expression="DateCreated";Descending=$true}|
    ConvertTo-HTML -Head $head

    #cast to string
    [string]$HTML = $HTMLArray -join ""

    #send email
    Send-MailMessage -To $email_addresses -BodyAsHtml $HTML -From $from -SmtpServer $smtp -Subject $subject -Port 25
}
