param(
    #[Parameter(Mandatory=$true)][string]$decryptedFull,
    #[Parameter(Mandatory=$true)][string]$caseNumber
)
$decryptedFull = "X:\dba\dba_full_20150621000010.bak"
$caseNumber = "12345"

Import-Module "C:\salt\scripts\modules\InforAWS\InforAWS.psm1" -DisableNameChecking
$appName = AWS-GetAppName
$region = AWS-GetRegion
$account = Get-IAMAccountAlias
$importexport = "\\$env:COMPUTERNAME\importexport"


try{
    #create path to export zip to 
    $item = Get-Item -Path $decryptedFull
    $ZipOutputFilePath = $importexport + "\" + $item.BaseName + ".zip"

    if (-not (test-path "$env:ProgramFiles\7-Zip\7z.exe")) {throw [System.Exception]  "$env:ProgramFiles\7-Zip\7z.exe needed"} 
    if (-not (test-path $decryptedFull)) {throw [System.Exception]  "No such file $decryptedFull"}
    set-alias sz "$env:ProgramFiles\7-Zip\7z.exe" 

    sz a -t7z -mx3 $ZipOutputFilePath $decryptedFull "-p$caseNumber"

    if($LASTEXITCODE -ne "0"){throw [System.Exception] ("Failed to create 7zip archive " + $ZipOutputFilePath)}

    #Invoke-Sqlcmd -Query ("$ZipOutputFilePath") -Database "dba" -ErrorAction Stop -ServerInstance $env:COMPUTERNAME
}catch{
    #Invoke-Sqlcmd -Query ("0") -Database "dba" -ErrorAction Stop -ServerInstance $env:COMPUTERNAME
    "Zip-File error"
}

$file = Get-Item -Path $ZipOutputFilePath
$fileName = $file.Name
$filePath = $file.FullName

try{
    $uploadBucket = "$account-uploads-$region"
    $uploadKey = "/$appName/$fileName"
    $urlBucket = "$account-appdata-$region"
    $urlFileName = "$fileName`presignedurl.txt"
    $urlKey = "/presigneduploadurls/helloworld.txtpresignedurl.txt"

    Write-S3Object -BucketName $uploadBucket -Key $uploadKey -File $filePath -ErrorAction Stop
    Move-Item -Path $ZipOutputFilePath -Destination "$importexport\archived"
    
    Copy-S3Object -BucketName $urlBucket -Key $urlKey -LocalFile $importexport\$urlFileName
    $URL = Get-Content -Path "$importexport\$urlFileName"
    Move-Item -Path "$importexport\$urlFilename" -Destination "$importexport\archived"

    #Invoke-Sqlcmd -Query ("$URL") -Database "dba" -ErrorAction Stop -ServerInstance $env:COMPUTERNAME
}
catch{
    #Invoke-Sqlcmd -Query ("0") -Database "dba" -ErrorAction Stop -ServerInstance $env:COMPUTERNAME
    "Copy-ToS3 error"       
}


#email public link


