[cmdletbinding()]
param(
	[Parameter(Mandatory=$True)][string]$Account,
	[Parameter(Mandatory=$True)][string]$Region
)

Import-Module AWSPowershell -DisableNameChecking

$Service = New-Object Amazon.EC2.Model.Filter -Property @{Name = "tag:Owner"; Values = "aschwabechartreportsextended@infor.com"}
$Instances = Get-EC2Instance -Filter $Service -ProfileName $Account -Region $Region

$ServersArray = @()

foreach($Instance in $Instances)
{
	foreach($Tag in $Instance.RunningInstance.Tag)
	{
		if($Tag.Key -eq "Name")
		{
			$TagArray = $Tag.Value.Split(':')

			$PropertyHash = @{
				Account = $Account
				Region = $Region
				Cluster = $TagArray[1]
				Server = $TagArray[2]
			}

			$ServerObject = New-Object -TypeName psobject -Property $PropertyHash

			$ServersArray += $ServerObject
		}
	}
}

$ServersArray | Sort-Object -Property Cluster | Format-Table