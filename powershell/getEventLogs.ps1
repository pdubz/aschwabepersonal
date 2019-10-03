$DT = (Get-Date -Format "yyyyMMdd")
$7days = (Get-Date).AddDays(-7)
$cluster = Get-Cluster
$nodes = Get-ClusterNode -InputObject $cluster
$outFolder = "C:\$DT-$cluster-logs"

## Set email params
$from = "$cluster@infor.com"
$to = "<andy.schwabe@infor.com>"
$subject = "$currentDateTime-$cluster-Logs" 
$smtp = "smarthost21.test.inforcloud.local"

## Set HTML
$style = "<style>"
$style += "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$style += "TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;}"
$style += "TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;}"
$style += "</style>"

if(-not(Test-Path $outFolder)){
    mkdir $outFolder
}

$systemFilter = 'Index,Time,EntryType,Source,InstanceID,Message,UserName,MachineName'
$appFilter = 'Index,Time,EntryType,Source,InstanceID,Message'

foreach($node in $nodes){
    $temp = @()
    $systemLog = Get-EventLog -LogName System -ComputerName $node -After $7days
    $systemLogFiltered = $systemLog | where-object {$_.Message -notlike "Monitis*" -and $_.Message -notlike "*MQQueueDepthMonitor.exe*"}
    $systemLogFiltered | Export-Csv -Path "$outFolder\$node-systemlog.csv"
    $temp = $systemLogFiltered | Select-Object | ConvertTo-Html -head $style
    $body += $temp -join ""

    $appLog = Get-EventLog -LogName Application -ComputerName $node -After $7days
    $appLogFiltered = $appLog | where-object {$_.Message -notlike "Monitis*" -and $_.Message -notlike "*MQQueueDepthMonitor.exe*"}
    $appTableFragment = $appLogFiltered | ConvertTo-Html -fragment
    $appLogFiltered | Export-Csv -Path "$outFolder\$node-applicationlog.csv"
}


$temp = $report | Select-Object  | ConvertTo-HTML -head $style 

$body = $temp -join ""


Send-MailMessage -From $from -To $to -Subject $subject -BodyAsHtml $body -SmtpServer $smtp -Credential $cred

<#

set-Alias '7z' -Value "$env:ProgramFiles\7-Zip\7z.exe"

if(Test-Path "$outFolder.zip"){remove-item "$outFolder.zip"}

if(-not(Test-Path 7z)){
    msiexec /i C:\Software\7z920-x64.msi /quiet
    7z a -t7z "$outFolder.zip" $outFolder
}
else{
    7z a -t7z "$outFolder.zip" $outFolder
}

#get the app name from salt$appName = ((& c:\salt\salt-call.exe pillar.get ec2:stack:parameters:ApplicationName).Trim() | select -skip 1)     #get AWS account from Console$AWSaccount = get-IAMAccountalias#get AWS region$region = (New-Object System.Net.WebClient).DownloadString("http://169.254.169.254/latest/meta-data/placement/availability-zone")$region = $region.substring(0,$region.length-1) 

#set appdata bucket$bucket = "$AWSaccount-appdata-$region"

#set key
$key = "mssql/"

Write-S3Object -BucketName $bucket -Key $key -File "$outFolder.zip"
#>