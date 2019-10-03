<#
Written by: aschwabe
Date: 20141015
Version: 3.0
Description: Get all info from all VPSAs.
Changelog:
1.0 - Gets info from VPSAs and writes to local disk
2.0 - Paramaterization, made more dynamic, implemented directory cleanup on local disk
3.0 - Added automatic sending to S3 bucket. 
4.0 (potential changes) - directory cleanup in S3, encryption of access keys for VPSAs and S3.
#>
$aKEY = "AKIAIWS7RFB377VVX5GQ"
$sKEY = "eV5utYiu4dva9XOBj6xSJXMT2GAtDTfb2NZZjsAl"
$bucket = "infor-sb-stgmgt-us-east-1"

$vpc21_stgmgt_z01 = "https://vsa-00000426-aws.zadaravpsa.com"
$vpc21_stgmgt_z02 = "https://vsa-00000138-aws2.zadaravpsa.com"
$vpc21_z01 = "https://vsa-000004a7-aws.zadaravpsa.com"$vpc21_z02 = "https://vsa-0000013f-aws2.zadaravpsa.com"$vpc144_z01 = "https://vsa-000004b3-aws.zadaravpsa.com"$vpc144_z02 = "https://vsa-0000013c-aws2.zadaravpsa.com"$vpsas = @(    $vpc21_stgmgt_z01,    $vpc21_stgmgt_z02,    $vpc21_z01,    $vpc21_z02,    $vpc144_z01    $vpc144_z02) $KEYvpc21_stgmgt_z01 = @{'X-Access-Key' = 'HGKV92K55BQS03ORTTRP'}$KEYvpc21_stgmgt_z02 = @{'X-Access-Key' = 'TSB5S0CFL2VNSF8QJHLK'}$KEYvpc21_z01 = @{'X-Access-Key' = '3X9015NY2P49LYKYBK1L'}$KEYvpc21_z02 = @{'X-Access-Key' = 'FJRS90OUS49L8WUQ6D9S'}$KEYvpc144_z01 = @{'X-Access-Key' = 'ZAXCG3PP3LWV2DFBMSC0'}$KEYvpc144_z02 = @{'X-Access-Key' = '9NPDEJ6JB4YTD2XCEURA'}$vpsaKEYS = @(    $KEYvpc21_stgmgt_z01,    $KEYvpc21_stgmgt_z02,    $KEYvpc21_z01,    $KEYvpc21_z02,    $KEYvpc144_z01    $KEYvpc144_z02)
$reportRootDir = "C:\output\VPSA_configs"
$lastMonth = ((Get-Date).AddMonths(-1).ToString("yyyyMM"))
$archiveDir = "$reportRootDir\$lastMonth"
$currentMonth = (Get-Date -Format "yyyyMM")
$currentDate = (Get-Date -Format "yyyyMMdd")
$currentDateTime = (Get-Date -Format "yyyyMMdd-HHmmss")
$archiveFolderCheck = Test-Path -Path $reportRootDir\$currentMonth
$todayFolderCheck = Test-Path -Path $reportRootDir\$currentDate
if($todayFolderCheck -eq $false){ 
    New-Item $reportRootDir\$currentDate -itemtype directory
}
if($archiveFolderCheck -eq $false){
    New-Item $reportRootDir\$currentMonth -itemtype directory
    $dir = ls $reportRootDir
    foreach($folder in $dir){
        if($folder.Name.Length -gt 7 -and $folder.Name -like "$lastMonth*"){ 
            $oldDir = "$reportRootDir\$folder"
            Move-Item -Path $oldDir -Destination $archiveDir
        }
    }
}

Function Execute{
    param
    ($uri,$head,$out,$s3out)
    Invoke-RestMethod -Uri $uri -Method GET -Headers $head -OutFile $out
    Write-S3Object -BucketName $bucket -AccessKey $aKEY -SecretKey $sKEY -Key "\zadara\vpsa-configs\$s3out" -File $out

}

for($i=0;$i -lt $vpsas.Count;$i++){
    $vpsa = $vpsas[$i]
    $head = $vpsaKEYS[$i]
    $uris = @(
        "$vpsa/api/drives"
        "$vpsa/api/raid_groups"
        "$vpsa/api/pools"
        "$vpsa/api/servers"
        "$vpsa/api/volumes"
        "$vpsa/api/vcontrollers"
        "$vpsa/api/snapshot_policies"
        "$vpsa/api/mirror_jobs"
        "$vpsa/api/users"
        "$vpsa/api/messages"
    )
    foreach($uri in $uris){
        $func = $uri.ToString()
        $funcArray = @()
        $funcArray = $func.Split("/")
        $outFunc = $funcArray[$funcArray.Length-1]  
        $out = ""
        $s3out = ""
        switch($vpsa){
            "https://vsa-00000426-aws.zadaravpsa.com"{
                $vpsaFolderCheck = Test-Path -Path "$reportRootDir\$currentDate\vpc21_stgmgt_z01"
                if($vpsaFolderCheck -eq $false){
                    New-Item "$reportRootDir\$currentDate\vpc21_stgmgt_z01" -itemtype directory
                }
                $out = "$reportRootDir\$currentDate\vpc21_stgmgt_z01\$currentDateTime-vpc21_stgmgt_z01-$outFunc.xml"
                $s3out = "$currentDate\vpc21_stgmgt_z01\$currentDateTime-vpc21_stgmgt_z01-$outFunc.xml"
            }
            "https://vsa-00000138-aws2.zadaravpsa.com"{
                $vpsaFolderCheck = Test-Path -Path "$reportRootDir\$currentDate\vpc21_stgmgt_z02"
                if($vpsaFolderCheck -eq $false){
                    New-Item "$reportRootDir\$currentDate\vpc21_stgmgt_z02" -itemtype directory
                }
                $out = "$reportRootDir\$currentDate\vpc21_stgmgt_z02\$currentDateTime-vpc21_stgmgt_z02-$outFunc.xml"
                $s3out = "$currentDate\vpc21_stgmgt_z02\$currentDateTime-vpc21_stgmgt_z02-$outFunc.xml"
            }
            "https://vsa-000004a7-aws.zadaravpsa.com"{                $vpsaFolderCheck = Test-Path -Path "$reportRootDir\$currentDate\vpc21_z01"
                if($vpsaFolderCheck -eq $false){
                    New-Item "$reportRootDir\$currentDate\vpc21_z01" -itemtype directory
                }
                $out = "$reportRootDir\$currentDate\vpc21_z01\$currentDateTime-vpc21_z01-$outFunc.xml"                $s3out = "$currentDate\vpc21_z01\$currentDateTime-vpc21_z01-$outFunc.xml"            }            "https://vsa-0000013f-aws2.zadaravpsa.com"{                $vpsaFolderCheck = Test-Path -Path "$reportRootDir\$currentDate\vpc21_z02"
                if($vpsaFolderCheck -eq $false){
                    New-Item "$reportRootDir\$currentDate\vpc21_z02" -itemtype directory
                }
                $out = "$reportRootDir\$currentDate\vpc21_z02\$currentDateTime-vpc21__z02-$outFunc.xml"                $s3out = "$currentDate\vpc21_z02\$currentDateTime-vpc21__z02-$outFunc.xml"            }            "https://vsa-000004b3-aws.zadaravpsa.com"{                $vpsaFolderCheck = Test-Path -Path "$reportRootDir\$currentDate\vpc144_z01"
                if($vpsaFolderCheck -eq $false){
                    New-Item "$reportRootDir\$currentDate\vpc144_z01" -itemtype directory
                }
                $out = "$reportRootDir\$currentDate\vpc144_z01\$currentDateTime-vpc144_z01-$outFunc.xml"                $s3out = "$currentDate\vpc144_z01\$currentDateTime-vpc144_z01-$outFunc.xml"            }            "https://vsa-0000013c-aws2.zadaravpsa.com"{
                $vpsaFolderCheck = Test-Path -Path "$reportRootDir\$currentDate\vpc144_z02"
                if($vpsaFolderCheck -eq $false){
                    New-Item "$reportRootDir\$currentDate\vpc144_z02" -itemtype directory
                }
                $out = "$reportRootDir\$currentDate\vpc144_z02\$currentDateTime-vpc144_z02-$outFunc.xml"
                $s3out = "$currentDate\vpc144_z02\$currentDateTime-vpc144_z02-$outFunc.xml"
            }
        }
        Execute $uri $head $out $s3out
    }
}