Function Get-AWSNodes
{
	[cmdletbinding()]
	param(
		[Parameter(Mandatory=$True)][string]$AppName,
		[Parameter(Mandatory=$True)][string]$Account,
		[Parameter(Mandatory=$True)][string]$Region
	)

	Import-Module AWSPowershell -DisableNameChecking

	$Service = New-Object Amazon.EC2.Model.Filter -Property @{Name = "tag:Service"; Values = "$AppName`:db-mssql"}
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
					App = $AppName
					Cluster = $TagArray[1]
					Server = $TagArray[2]
				}

				$ServerObject = New-Object -TypeName psobject -Property $PropertyHash

				$ServersArray += $ServerObject
			}
		}
	}

	$ServersArray | Sort-Object -Property Cluster | Format-Table
}

Function Get-AWSSQLNodes
{
	[cmdletbinding()]
	param(
		[Parameter(Mandatory=$False)][switch]$PRDOnly
	)

	Import-Module AWSPowershell -DisableNameChecking

	if($PRDOnly -eq $true )
	{
		$Accounts = @("prd","pprd1","prd-ncr")
	}
	else
	{
		$Accounts = @("prd","pprd1","prd-ncr","devops-dev","auto","sb","int")
	}

	$Regions = @("us-east-1","us-west-1","us-west-2","eu-central-1","eu-west-1","ap-southeast-2")

	$ReportArray = @()

	$Service = New-Object Amazon.EC2.Model.Filter -Property @{Name = "tag:Service"; Values = "*:db-mssql"}

	foreach($Account in $Accounts)
	{
		foreach($Region in $Regions)
		{
			$Instances = Get-EC2Instance -Filter $Service -ProfileName $Account -Region $Region

			$PropertyHash = @{
				Account = $Account
				Region = $Region
				DatabaseServers = $Instances.Count
			}

			$ReportObject = New-Object -TypeName psobject -Property $PropertyHash

			if($ReportObject.DatabaseServers -ne 0)
			{

				$ReportArray += $ReportObject
			}
		}
	}

	$ReportArray | Sort-Object -Property DatabaseServers -Descending | Format-Table
}

Function Get-FaroBaseConfigs
{
	[cmdletbinding()]
	param(
		[Parameter(Mandatory=$True)][string[]]$Servers,
		[Parameter(Mandatory=$True)][string]$Account,
		[Parameter(Mandatory=$True)][string]$Region
	)
	$ConfigsArray = @()

	foreach($Server in $Servers)
	{
		$Deployment = faro -P $Account -R $Region list --json deployment mssql-$server

		$JSONDeployment = $Deployment | ConvertFrom-Json

		$PropertyHash = @{
			Server = $Server
			Account = $Account
			Region = $Region
			SSIS = $JSONDeployment.Parameters.ssis
			SSRS = $JSONDeployment.Parameters.ssrs
			FullText = $JSONDeployment.Parameters.fulltext
			CLR = $JSONDeployment.Parameters.clr
			OLE = $JSONDeployment.Parameters.ole
			Trustworthy = $JSONDeployment.Parameters.trustworthy
			TTL = $JSONDeployment.Parameters.ttl
			XPRegread = $JSONDeployment.Parameters.xpregread
		}

		$ConfigObject = New-Object -TypeName psobject -Property $PropertyHash

		$ConfigsArray += $ConfigObject
	}

	$ConfigsArray | Sort-Object -Property Server | Format-Table -Property Server,SSIS,SSRS,FullText,CLR,OLE,Trustworthy,TTL,XPRegread
}

Function Get-SQLInstances
{
	[cmdletbinding()]
	param(
		[Parameter(Mandatory=$False)][ValidateSet("prd","pprd1","prd-ncr","devops-dev","auto","sb","int","DEVOnly","PRDOnly")][string]$Account,
		[Parameter(Mandatory=$False)][ValidateSet("us-east-1","us-west-1","us-west-2","eu-central-1","eu-west-1","ap-southeast-2","AllRegions")][string]$Region
	)

	Import-Module AWSPowershell -DisableNameChecking 4>$null

	switch ($Account)
	{
		PRDOnly { [System.Object[]]$Accounts = @("prd","pprd1","prd-ncr" ) }
		DevOnly { [System.Object[]]$Accounts = @("devops-dev","auto","sb","int") }
		Default { [System.Object[]]$Accounts = $Account }
	}

    switch ($Region)
    {
        AllRegions { [System.Object[]]$Regions = @("us-east-1","us-west-1","us-west-2","eu-central-1","eu-west-1","ap-southeast-2") }
        Default { [System.Object[]]$Regions = $Region }
    }

	$OwnerFilter = New-Object Amazon.EC2.Model.Filter -Property @{Name = "tag:Owner"; Values = "aschwabechartreportsextended@infor.com"}

	$AllInstances = @()

	foreach($Account in $Accounts)
	{
		foreach($Region in $Regions)
		{
			$Instances = Get-EC2Instance -Filter $OwnerFilter -ProfileName $Account -Region $Region

            foreach ($Instance in $Instances)
            {
                $PropertyHash = @{
				    Account = $Account
				    Region = $Region
				    ServerName = ($Instance.Instances.Tags | Where-Object {$_.Key -eq 'Name'}).Value
                }

                $InstanceObject = New-Object -TypeName psobject -Property $PropertyHash

                $AllInstances += $InstanceObject
            }

		}
	}
	$AllInstances | Sort-Object -Property Account,Region,ServerName | Format-Table -Property Account,Region,ServerName
}
