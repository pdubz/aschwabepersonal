$DT = (Get-Date -Format "yyyyMMdd")
$cluster = Get-Cluster
$nodes = Get-ClusterNode -InputObject $cluster
$outFolder = "C:\$DT-$cluster-logs"
$test = Test-Path -Path $outFolder

if($test -eq $false){
    mkdir $outFolder
}

 Get-ClusterLog -InputObject $cluster -Destination $outFolder

foreach($node in $nodes){
    Get-EventLog -LogName System -ComputerName $node | Export-Csv -Path "$outFolder\$node-systemlog.csv"
    Get-EventLog -LogName Application -ComputerName $node | Export-Csv -Path "$outFolder\$node-applicationlog.csv"
}

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
