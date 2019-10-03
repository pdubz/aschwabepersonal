Import-Module AWSPowershell
$Accounts = @('prd')
$Regions = @('us-east-1','eu-central-1')
[System.Collections.ArrayList]$Instances = @()

$Date_Time = Get-Date -Format "yyyyMMdd_hhmmss"

$AliasFilePath = "$ENV:USERPROFILE\Documents\TSAliases.ps1"


if((Test-Path -Path $AliasFilePath))
{
    Remove-Item -Path $AliasFilePath -Force
    New-Item -Path $AliasFilePath -ItemType File
    Set-Content -Path $AliasFilePath -Value $SSHFunction
}

foreach ($Account in $Accounts)
{
    foreach ($Region in $Regions)
    {
        $filter = @{name='tag:Product'; values="ts"}
        $EC2Infos = Get-EC2Instance -Filter $filter -ProfileName $Account -Region $Region
        foreach($EC2Info in $EC2Infos)
        {
			$NameTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'Name'}).Value
            $ServiceTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'Service'}).Value
            [int]$PodTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'Pod'}).Value
            if ($ServiceTag -inotmatch "ts:db*")
            {
                if ($Region -eq "us-east-1")
                {
                    $PPK = "$ENV:USERPROFILE\Documents\keypairs\ts\tsprod.ppk"
                }
                elseif ($Region -eq "eu-central-1")
                {
                    $PPK = "$ENV:USERPROFILE\Documents\keypairs\ts\tsprod-eu.ppk"
                }

                [string]$ServerType = ''
                if($ServiceTag -ilike "*tomcat*")
                {
                    $ServerType = 'tomcat'
                }
                elseif($ServiceTag -ilike "*jboss*")
                {
                    $ServerType = 'jboss'
                }
                elseif($ServiceTag -ilike "*memc*")
                {
                    $ServerType = 'memc'
                }
                elseif($ServiceTag -ilike "*msg*")
                {
                    $ServerType = 'msg'
                }
                else
                {
                    $ServerType = 'notfound'
                }

                if((!$PodTag) -and ($ServerType -ne 'notfound'))
                {
                    if($Region -eq 'us-east-1')
                    {
                        [int]$PodTag = $NameTag.Substring(9,1)
                    }
                    elseif($Region -eq 'eu-central-1')
                    {
                        [int]$PodTag = $NameTag.Substring(5,3)
                    }
                }

                [int]$ServerOrdinal = 0
                if(($ServerType -ne 'notfound') -and ($PodTag))
                {
                    $ServerOrdinal = $NameTag.Substring(($NameTag.Length-1),1)
                }

                $IpAddress = $EC2Info.Instances.PrivateIpAddress
                $ConnectionString = "plink -i $PPK ec2-user@$IpAddress"
                $AliasName = "pod" + $PodTag + $ServerType + $ServerOrdinal

                $AliasCreation = 'function ' + $AliasName +'{' + $ConnectionString + '}'
		        $PropertyHash = [ordered]@{
                    PodTag = $PodTag
                    ServerType = $ServerType
                    ServerOrdinal = $ServerOrdinal
                    ConnectionString = $ConnectionString
                    AliasCreation = $AliasCreation
			        InstanceId = $EC2Info.Instances.InstanceId
                    IpAddress = $IpAddress
			        NameTag = $NameTag
                    ServiceTag = $ServiceTag
                    Account = $Account
			        Region = $Region
                }
		        $InstanceObject = New-Object -TypeName psobject -Property $PropertyHash
                if(($InstanceObject.IpAddress))
                {
                    $Instances += $InstanceObject

                    Add-Content -Path $AliasFilePath -Value $InstanceObject.AliasCreation

                    $CSVRootPath = "$ENV:USERPROFILE\Desktop\ts_plink"
                    if(!(Test-Path -Path $CSVRootPath)){New-Item -Path $CSVRootPath -ItemType Directory | Out-Null}
                    $CSVPath = "$CSVRootPath\$Date_Time-TSPlinkConnections.csv"
                    Export-Csv -Path $CSVPath -InputObject $InstanceObject -Encoding UTF8 -Append -NoTypeInformation
                }
            }
	    }
	}
}
$Instances | Sort-Object -Property PodTag,ServerType,ServerOrdinal | Select-Object -Property NameTag, ConnectionString | Format-Table
Write-Host "Also available in CSV at $CSVPath"
