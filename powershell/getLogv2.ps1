#import necessary modules
Import-Module C:\salt\scripts\modules\InforAWS\InforAWS.psm1 -DisableNameChecking
Import-Module C:\salt\scripts\modules\InforSQL\InforSQL.psm1 -DisableNameChecking
Import-Module C:\salt\scripts\modules\InforGeneral\InforGeneral.psm1 -DisableNameChecking
Import-Module C:\salt\scripts\modules\InforLogging\InforLogging.psm1 -DisableNameChecking
Import-Module SQLPS -DisableNameChecking
Set-Location C:\

Function Get-SystemInfoAndLogs
{
    Param(
    [Parameter(Mandatory=$true)][string]$OutputFolder,
    [Parameter(Mandatory=$true)][string]$Computer
    )

    #build list of different logs
    $LogTypes = @('Application','System','Security')

    #loop through logs and export to csv
    foreach($LogType in $LogTypes)
    {
        try
        {
            $LogPath = "$OutputFolder\$Computer-$LogType`Log.csv"
            Write-Log -Message "Exporting $LogType log from $Computer to $LogPath as a CSV file." -MessageType INFO
            $EventLog = Get-EventLog -LogName $LogType -ComputerName $Computer
            Out-File -InputObject "EventID,MachineName,Data,Index,Category,CategoryNumber,EntryType,Message,Source,ReplacementStrings,InstanceId,TimeGenerated,TimeWritten,UserName,Site,Container" -FilePath $LogPath

                $EventLog | ConvertTo-Csv | Out-File -Path $LogPath -Append

            Write-Log -Message "Successfully exported $LogType log from $Computer to $LogPath as a CSV file." -MessageType INFO
        }
        catch
        {
            Write-Log -Message "Failed to export $LogType log from $Computer to $LogPath as a CSV file." -MessageType ERROR
            Write-Log -Message "$_" -MessageType ERROR
            $ErrorCount++
        }
    }

    #export OS info into text file formatted in list format
    try
    {
        $Win32OSPath = "$OutputFolder\$Computer-Win32OSInfo.txt"
        Write-Log -Message "Exporting Win32 OS Info from $Computer using 'Get-CimInstance Win32_OperatingSystem' to $Win32OSPath as a TXT file." -MessageType INFO
        Get-CimInstance Win32_OperatingSystem -ComputerName $Computer | Format-List -Property * | Out-File $Win32OSPath
        Write-Log -Message "Successfully exported Win32 OS Info from $Computer to $Win32OSPath as a TXT file." -MessageType INFO
    }
    catch
    {
        Write-Log -Message "Failed to export Win32 OS Info from $Computer to $Win32OSPath as a TXT file." -MessageType ERROR
        Write-Log -Message "$_" -MessageType ERROR
        $ErrorCount++
    }

    #export installed updates to CSV file
    try
    {
        $InstalledUpdatesPath = "$OutputFolder\$Computer-InstalledUpdates.csv"
        Write-Log -Message "Exporting installed updates from $Computer to $InstalledUpdatesPath as a CSV file." -MessageType INFO
        Get-WmiObject -Class win32_quickfixengineering -ComputerName $Computer | Export-Csv -Path $InstalledUpdatesPath -NoTypeInformation
        Write-Log -Message "Successfully exported installed updates from $Computer to $InstalledUpdatesPath as a CSV file." -MessageType INFO
    }
    catch
    {
        Write-Log -Message "Failed to export installed updates from $Computer to $InstalledUpdatesPath as a CSV file." -MessageType ERROR
        Write-Log -Message "$_" -MessageType ERROR
        $ErrorCount++
    }
}

#set error count to 0
$ErrorCount = 0

#get start datetime
$StartDateTime = Get-Date -Format 'yyyyMMdd-hhmmss'

#find out if we have a cluster or not
try
{
    $ClusterName = (Get-Cluster -ErrorAction Stop).Name
}
catch
{
    #suppress error
}

if(!($ClusterName))
{
    #create folder path
    $Folder = "\\$env:COMPUTERNAME\C$\$StartDateTime-$env:COMPUTERNAME-logs"
    
    #instantiate logging
    New-LogFile -Folder $Folder -FilePrefix 'ReadMe' -FileExtension 'txt' -SetEnvLogFile 1
    Write-Log -Message "Cluster not found. Running for a single node." -MessageType INFO

    #create folder if it doesn't exist
    if(!(Test-Path -Path $Folder))
    {
        New-Item -Path $Folder -ItemType Directory
    }
    
    #exporting system info and logs
    Write-Log -Message "--------------------------------------------------------------------------------------------------" -MessageType INFO
    Write-Log -Message "Beginning to export logs for $env:COMPUTERNAME" -MessageType INFO
    Get-SystemInfoAndLogs -OutputFolder $Folder -Computer $env:COMPUTERNAME
    Write-Log -Message "Finished exporting logs for $env:COMPUTERNAME" -MessageType INFO
}
else
{
    #create folder path
    $Folder = "\\$env:COMPUTERNAME\C$\$StartDateTime-$ClusterName-logs"

    #instantiate logging
    New-LogFile -Folder $Folder -FilePrefix 'ReadMe' -FileExtension 'txt' -SetEnvLogFile 1 | Out-Null
    Write-Log -Message "Cluster found: $ClusterName." -MessageType INFO
    
    #create folder if it doesn't exist
    if(!(Test-Path -Path $Folder))
    {
        New-Item -Path $Folder -ItemType Directory
    }

    #get list of cluster nodes
    $ClusterNodes = Get-ClusterNode
    $NodeCount = $ClusterNodes.Count
    $NodeNames = $ClusterNodes -join ','
    Write-Log -Message "Found $NodeCount cluster nodes in the $ClusterName cluster ($NodeNames)." -MessageType INFO
    
    #get cluster log
    try
    {
        Write-Log -Message "Exporting cluster log from $ClusterName to $Folder\<node FQDN>.log as a LOG file." -MessageType INFO
        #Get-ClusterLog -Destination $Folder | Out-Null
        Write-Log -Message "Successfully exported cluster log from $ClusterName to $Folder\<node FQDN>.log as a LOG file." -MessageType INFO
    }
    catch
    {
        Write-Log -Message "Failed to export cluster log from $ClusterName to $Folder\<node FQDN>.log as a LOG file." -MessageType INFO
        Write-Log -Message "$_" -MessageType ERROR
        $ErrorCount++
    }


    foreach($Node in $ClusterNodes)
    {
        Write-Log -Message "--------------------------------------------------------------------------------------------------" -MessageType INFO
        Write-Log -Message "Beginning to export logs for $Node" -MessageType INFO
        Get-SystemInfoAndLogs -OutputFolder $Folder -Computer $Node
        Write-Log -Message "Finished exporting logs for $Node" -MessageType INFO
    }
}

