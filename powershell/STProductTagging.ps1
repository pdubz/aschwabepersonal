<#

#>
[cmdletbinding()]
param(
	[Parameter(Mandatory=$true)][string[]]$Accounts,
	[Parameter(Mandatory=$true)][string[]]$Regions,
	[Parameter(Mandatory=$false)][switch]$Update
	
)

function Set-ProductTag
{
	[cmdletbinding()]
	param(
		[Parameter(Mandatory=$true)][string]$IID,
		[Parameter(Mandatory=$true)][string]$CurrentValue,
		[Parameter(Mandatory=$true)][string]$DesiredValue
	)
	
	try
	{
		if(($CurrentValue -ne $DesiredValue) -or ($CurrentValue -eq $null))
		{
			New-EC2Tag -Tag (New-Object -TypeName Amazon.EC2.Model.Tag -ArgumentList @('Product', "$DesiredValue")) -Resource $InstanceID
		}
		Write-Host "Successfully updated $IID's product tag to '$DesiredValue' from '$CurrentValue'" -ForegroundColor Green
	}
	catch
	{
		Write-Host "Failed to update $IID's product tag to '$DesiredValue' from '$CurrentValue'. Error: $_" -ForegroundColor Red
	}
}

Import-Module AWSPowershell -DisableNameChecking 4>$null

$ServersArray = @()
$NotUpdated = @()

foreach($Account in $Accounts)
{
	foreach($Region in $Regions)
	{
		$Instances = Get-EC2Instance -ProfileName $Account -Region $Region
		foreach($Instance in $Instances)
		{
			$InstanceID = $Instance.Instances.InstanceId
			$NameTagValue = ($Instance.Instances.Tags | Where-Object {$_.Key -eq 'Name'}).Value
			$ProductTagValue = ($Instance.Instances.Tags | Where-Object {$_.Key -eq 'Product'}).Value

			if(!$ProductTagValue)
			{
				$ProductTagValue = $null
			}
			
			if($Update)
			{
				switch($NameTagValue.ToUpper())
				{
					"INFORBCAD01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "infra"}
					"INFORBCDB01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "infra"}
					"INFORBCODB01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "infra"}
					"INFORBCLS01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "lsf"}
					"INFORBCMSCM1" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "mscm"}
					"INFORBCLM01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "lmrk"}
					"INFORBCMG01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "mingle"}
					"INFORBCIN01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "ion"}
					"INFORBCISO01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "iso"}
					"INFORBCBI01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "bi"}
					"INFORBCCB01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "cb"}
					"INFORBCIES01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "ies"}
					"INFORBCVP01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "infra"}
					"INFORBCNT01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "infra"}
					"INFORBCCFT01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "infra"}
					"INFORBCCA01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "pubapp"}
					"INFORBCSLGK01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "infra"}
					"INFORBCWFDB01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "infra"}
					"INFORBCOP01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "bi"}
					"INFORBCSL01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "infra"}
					"INFORBCWFJB01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "wfm"}
					"INFORBCWFAPP01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "wfm"}
					"INFORBCWFAPP02" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "wfm"}
					"INFORBCWFCOG01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "wfm"}
					"INFORBCWFJMP01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "wfm"}
					"INFORBCCF01" { Set-ProductTag -IID $InstanceID -CurrentValue $ProductTagValue -DesiredValue "infra"}
					default { $NotUpdated += $InstanceID }
				}
			}
			else
			{
				$PropertyHash = @{
					Account = $Account
					Region = $Region
					InstanceID = $InstanceID
					NameTag = $NameTagValue
					ProductTag = $ProductTagValue
				}

				$ServerObject = New-Object -TypeName psobject -Property $PropertyHash

				$ServersArray += $ServerObject
			}
		}
	}
}

if($Update)
{
	return $NotUpdated
}
else
{
	$ServersArray | Sort-Object -Property Account,Region,ProductTag | Format-Table
}

