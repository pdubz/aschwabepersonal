$primaryNode = 'sl03-a'
$DT = (Get-Date -Format "yyyyMMdd-hhmmss")
$cluster = Get-Cluster
$nodes = Get-ClusterNode -InputObject $cluster
$clusterName = $cluster.Name
$outFolder = "\\$primaryNode\C$\$DT-$clusterName-logs"
$test = Test-Path -Path $outFolder

if($test -eq $false){
    mkdir $outFolder
}

Get-ClusterLog -InputObject $cluster -Destination $outFolder

foreach($node in $nodes){
    Get-EventLog -LogName Application -ComputerName $node | Export-Csv -Path "$outFolder\$node-applicationlog.csv"
    Get-EventLog -LogName System -ComputerName $node | Export-Csv -Path "$outFolder\$node-systemlog.csv"
    Get-EventLog -LogName Security -ComputerName $node | Export-Csv -Path "$outFolder\$node-securitylog.csv"
    $systemInfo = Get-CimInstance Win32_OperatingSystem -ComputerName $node | FL * 
    Out-File "$outFolder\$node-system_info.txt" -InputObject $systemInfo

    Invoke-Command -ComputerName $node { 
        #Adds the date/timestamp to write-log for logging optional updates
        function Write-Log{	
            param([string]$data)

            Write-host (Get-Date) "$data"
	        Out-File -InputObject "$data" -FilePath $LoggingFile -Append
        }

        msinfo32 /nfo "$outFolder\$node-msinfo.nfo" | Out-Null 
         
        #Querying installed updates from wmi
        wmic qfe list full /format:csv > "$outFolder\$node-installedupdates.csv"

        #Logging optional updates.
        $LoggingFile = "$outFolder\$node-OptionalUpdates.csv"
        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        $SearchResult = $UpdateSearcher.Search("IsHidden=0 and IsInstalled=0")
        Write-Log "Title,Description,Support_URL,KB"

        foreach($Update in $SearchResult.Updates){
            Write-Log "$($Update.Title),$($Update.Description),$($Update.SupportUrl),$($Update.KBArticleIDs)"
        }
    }
}

$ZipOutputFilePath = "C:\$DT-$clusterName-logs.zip"

#check 7z file and backup file
if (-not (test-path "$env:ProgramFiles\7-Zip\7z.exe")){
    C:\Software\7z920-x64.msi /quiet
} 

set-alias sz "$env:ProgramFiles\7-Zip\7z.exe" 

#zip file
sz a -t7z -mx3 $ZipOutputFilePath $outFolder

if($LASTEXITCODE -ne "0"){
    throw [System.Exception] ("Failed to create 7zip archive " + $ZipOutputFilePath)
    exit
}

#import modules
Import-Module AWSPowerShell -DisableNameChecking
Import-Module "C:\salt\scripts\modules\InforAWS\InforAWS.psm1" -DisableNameChecking

#get environment variables
$appName = AWS-GetAppName
$region = AWS-GetRegion
$account = Get-IAMAccountAlias
$file = Get-Item -Path $ZipOutputFilePath
$fileName = $file.Name
$filePath = $file.FullName
$uploadBucket = "$account-uploads-$region"
$uploadKey = "$fileName"
$urlBucket = "$account-appdata-$region"
$urlFileName = "$fileName`.downloadurl.txt"
$urlKey = "presigneduploadurls/$urlFileName"

#upload zip to S3
Write-S3Object -BucketName $uploadBucket -Key $uploadKey -File $filePath -ErrorAction Stop
$s3path = "$uploadBucket/$uploadKey"

#wait to make sure url is created
Start-Sleep -Seconds 15

#get url from s3 and read it into a variable
Copy-S3Object -BucketName $urlBucket -Key $urlKey -LocalFile $outFolder\$urlFileName
$URL = Get-Content -Path "$outFolder\$urlFileName"

#delete zip file and folder
Remove-Item -Path $ZipOutputFilePath -Force
Remove-Item -Path $outFolder -Recurse -Force
Remove-Item -Path "$outFolder\$urlFileName" -Force

Write-Host $URL
