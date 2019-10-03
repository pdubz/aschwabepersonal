<#
$a = Get-EC2Instance -ProfileName int -Region us-east-1
$a.GetType()
$a.Instances.GetType()
$a | get-member
$a.Instances | get-member
#>

Import-Module AWSPowershell

$Date = Get-Date -Format "yyyyMMdd_hhmmss"

[System.Collections.ArrayList]$Account = 'int'

$Region = 'us-east-1'
[System.Collections.ArrayList]$InstancesArray = @()

$Instances = Get-EC2Instance -ProfileName $Account -Region $Region

foreach($Instance in $Instances.Instances)
{
	$PropertyHash = @{
		Account = $Account
		Region = $Region
		InstanceId = $Instance.InstanceId
		InstanceType = $Instance.InstanceType.Value
		Platform = $Instance.Platform
		Tenancy = $Instance.Placement.Tenancy.Value
		NameTag = ($Instance.Tags | Where-Object {$_.Key -eq 'Name'}).Value
		OwnerTag = ($Instance.Tags | Where-Object {$_.Key -eq 'Owner'}).Value
		ServiceTag = ($Instance.Tags | Where-Object {$_.Key -eq 'Service'}).Value
		ProductTag = ($Instance.Tags | Where-Object {$_.Key -eq 'Product'}).Value
	}

	$InstanceObject = New-Object -TypeName psobject -Property $PropertyHash
	$InstancesArray += $InstanceObject
}

foreach($Inst in $InstancesArray)
{
    Export-Csv -InputObject $Inst -Path "D:\Users\aschwabe\Desktop\$Date-$AccountChoice-Servers.csv" -Append -NoTypeInformation
}
