function Get-TagValues
{
	param(
		[Parameter(Mandatory=$true)][object]$TagObject,
		[Parameter(Mandatory=$true)][string[]]$DesiredTagKeys,
		[Parameter(Mandatory=$false)][switch]$Nullify
	)

	$TagHashtable = [ordered]@{}
	foreach($Key in $DesiredTagKeys)
	{
		if( ($TagObject | Get-Member).Name -notcontains "Tags")
		{
			$TagValue = ($TagObject | Where-Object {$_.Key -eq $Key}).Value

			if($Nullify -and !$TagValue)
			{
				$TagValue = "Null$Key`Tag"
			}
		}
		elseif( (($TagObject.Tags.GetType()).BaseType.Name -eq "Array") -or (($TagObject.Tags.GetType()).BaseType.Name -eq "Object") )
		{
			$TagValue = ($TagObject.Tags | Where-Object {$_.Key -eq $Key}).Value

			if($Nullify -and !$TagValue)
			{
				$TagValue = "Null$Key`Tag"
			}
		}
		elseif(($TagObject.Tags.GetType()).BaseType.Name -eq 'Dictionary`2')
		{
			$TagValue = $TagObject.Tags.$Key

			if($Nullify -and !$TagValue)
			{
				$TagValue = "Null$Key`Tag"
			}
		}
		else
		{
			Write-Host "Pulling tags failed. AWS returned tags as a " ($TagObject.Tags.GetType()).BaseType.Name -ForegroundColor Red
		}

		$TagHashtable.Add("$Key`Tag",$TagValue)
	}
	return $TagHashtable
}

function Set-EmptyTags
{
	param(
		[Parameter(Mandatory=$true)][string[]]$DesiredTagKeys
	)
	$EmptyTags = [ordered]@{}
	foreach($Tag in $DesiredTagKeys)
	{
		$EmptyTags.Add($Tag,"")
	}
	return $EmptyTags
}

function Get-EC2Data
{
	param(
		[Parameter(Mandatory=$true)][string]$Account,
		[Parameter(Mandatory=$true)][string]$Region
	)

	Import-Module AWSPowershell

	[System.Collections.ArrayList]$EC2Array = @()

	$EC2Infos = Get-EC2Instance -ProfileName $Account -Region $Region
	foreach($EC2Info in $EC2Infos)
	{
		if($EC2Info.Instances.Count -eq 1)
		{
			$Instances = @($EC2Info.Instances)
		}
		else
		{
			$Instances = $EC2Info.Instances
		}

		foreach($Instance in $Instances)
		{
			$PropertyHash = Get-TagValues -TagObject $Instance -DesiredTagKeys $TagKeys -Nullify

			$PropertyHash.Add("Account",$Account)
			$PropertyHash.Add("Region",$Region)
			$PropertyHash.Add("ResourceId",$Instance.InstanceId)
			$PropertyHash.Add("ResourceType","EC2Instance")

			$InstanceObject = New-Object -TypeName psobject -Property $PropertyHash
			$EC2Array += $InstanceObject
		}
	}
	return $EC2Array
}

function Get-ELBData
{
	param(
		[Parameter(Mandatory=$true)][string]$Account,
		[Parameter(Mandatory=$true)][string]$Region
	)

	Import-Module AWSPowershell

	[System.Collections.ArrayList]$ELBArray = @()

	$V1ELBs = Get-ELBLoadBalancer -ProfileName $Account -Region $Region

	foreach($V1ELB in $V1ELBs)
	{
		$V1ELBTags = Get-ELBResourceTag -LoadBalancerName $V1ELB.LoadBalancerName -ProfileName $Account -Region $Region

		if(!$V1ELBTags)
		{
			$V1ELBTags = Set-EmptyTags -DesiredTagKeys $TagKeys
		}

		$PropertyHash = Get-TagValues -TagObject $V1ELBTags -DesiredTagKeys $TagKeys -Nullify

		$PropertyHash.Add("Account",$Account)
		$PropertyHash.Add("Region",$Region)
		$PropertyHash.Add("ResourceId",$V1ELB.DNSName)
		$PropertyHash.Add("ResourceType","ELBv1")

		#Object is the same as v2 object, using different var names to avoid scope problems
		$ELBV1Object = New-Object -TypeName psobject -Property $PropertyHash
		$ELBArray += $ELBV1Object
	}

	$V2ELBs = Get-ELB2LoadBalancer -ProfileName $Account -Region $Region -PageSize 400

	foreach($V2ELB in $V2ELBs)
	{
		$V2ELBTags = Get-ELB2Tag -ResourceArn $V2ELB.LoadBalancerArn -ProfileName $Account -Region $Region

		if(!$V2ELBTags)
		{
			$V2ELBTags = Set-EmptyTags -DesiredTagKeys $TagKeys
		}

		$PropertyHash = Get-TagValues -TagObject $V2ELBTags -DesiredTagKeys $TagKeys -Nullify

		$PropertyHash.Add("Account",$Account)
		$PropertyHash.Add("Region",$Region)
		$PropertyHash.Add("ResourceId",$V2ELB.LoadBalancerArn)
		$PropertyHash.Add("ResourceType","ELBv2")

		#Object is the same as v1 object, using different var names to avoid scope problems
		$ELBV2Object = New-Object -TypeName psobject -Property $PropertyHash
		$ELBArray += $ELBV2Object
	}

	return $ELBArray
}

function Get-RDSData
{
	param(
		[Parameter(Mandatory=$true)][string]$Account,
		[Parameter(Mandatory=$true)][string]$Region
	)

	Import-Module AWSPowershell

	[System.Collections.ArrayList]$RDSArray = @()

	$RDSClusters = Get-RDSDBCluster -ProfileName $Account -Region $Region

	foreach($RDSCluster in $RDSClusters)
	{
		$RDSClusterTags = Get-RDSTagForResource -ResourceName $RDSCluster.DBClusterArn -ProfileName $Account -Region $Region

		if(!$RDSClusterTags)
		{
			$RDSClusterTags = Set-EmptyTags -DesiredTagKeys $TagKeys
		}

		$PropertyHash = Get-TagValues -TagObject $RDSClusterTags -DesiredTagKeys $TagKeys -Nullify

		$PropertyHash.Add("Account",$Account)
		$PropertyHash.Add("Region",$Region)
		$PropertyHash.Add("ResourceId",$RDSCluster.DBClusterArn)
		$PropertyHash.Add("ResourceType","RDSCluster")

		#Object is the same as v1 object, using different var names to avoid scope problems
		$RDSClusterObject = New-Object -TypeName psobject -Property $PropertyHash
		$RDSArray += $RDSClusterObject
	}

	$RDSInstances = Get-RDSDBInstance -ProfileName $Account -Region $Region

	foreach($RDSInstance in $RDSInstances)
	{
		$RDSInstanceTags = Get-RDSTagForResource -ResourceName $RDSInstance.DBInstanceArn -ProfileName $Account -Region $Region

		if(!$RDSInstanceTags)
		{
			$RDSInstanceTags = Set-EmptyTags -DesiredTagKeys $TagKeys
		}

		$PropertyHash = Get-TagValues -TagObject $RDSInstanceTags -DesiredTagKeys $TagKeys -Nullify

		$PropertyHash.Add("Account",$Account)
		$PropertyHash.Add("Region",$Region)
		$PropertyHash.Add("ResourceId",$RDSInstance.DBInstanceArn)
		$PropertyHash.Add("ResourceType","RDSInstance")

		#Object is the same as v1 object, using different var names to avoid scope problems
		$RDSInstanceObject = New-Object -TypeName psobject -Property $PropertyHash
		$RDSArray += $RDSInstanceObject
	}
	return $RDSArray
}

function Get-SQSData
{
	param(
		[Parameter(Mandatory=$true)][string]$Account,
		[Parameter(Mandatory=$true)][string]$Region
	)

	Import-Module AWSPowershell

	[System.Collections.ArrayList]$SQSArray = @()

	$SQSQueues = Get-SQSQueue -ProfileName $Account -Region $Region

	foreach($Queue in $SQSQueues)
	{
		$SQSTags = Get-SQSResourceTag -QueueUrl $Queue ProfileName $Account -Region $Region

		if(!$SQSTags)
		{
			$SQSTags = Set-EmptyTags -DesiredTagKeys $TagKeys
		}

		$PropertyHash = Get-TagValues -TagObject $SQSTags -DesiredTagKeys $TagKeys -Nullify

		$PropertyHash.Add("Account",$Account)
		$PropertyHash.Add("Region",$Region)
		$PropertyHash.Add("ResourceId",$Queue)
		$PropertyHash.Add("ResourceType","SQSQueue")

		#Object is the same as v1 object, using different var names to avoid scope problems
		$SQSObject = New-Object -TypeName psobject -Property $PropertyHash
		$SQSArray += $SQSObject
	}
	return $SQSArray
}

function Get-SNSData
{
	param(
		[Parameter(Mandatory=$true)][string]$Account,
		[Parameter(Mandatory=$true)][string]$Region
	)

	Import-Module AWSPowershell

	[System.Collections.ArrayList]$SNSArray = @()

	$SNSTopics = Get-SNSTopic -ProfileName $account -Region $Region

	#No Way to get tags
}

function Get-CFData
{
	param(
		[Parameter(Mandatory=$true)][string]$Account,
		[Parameter(Mandatory=$true)][string]$Region
	)

	Import-Module AWSPowershell

	[System.Collections.ArrayList]$CFArray = @()

	$CFStacks = Get-CFNStack -ProfileName $Account -Region $Region

	foreach($CFStack in $CFStacks)
	{
		$PropertyHash = Get-TagValues -TagObject $CFStack -DesiredTagKeys $TagKeys -Nullify

		$PropertyHash.Add("Account",$Account)
		$PropertyHash.Add("Region",$Region)
		$PropertyHash.Add("ResourceId",$CFStack.StackId)
		$PropertyHash.Add("ResourceType","CFStack")

		$CFObject = New-Object -TypeName psobject -Property $PropertyHash
		$CFArray += $CFObject
	}
	return $CFArray
}
function Get-S3Data
{
	param(
		[Parameter(Mandatory=$true)][string]$Account,
		[Parameter(Mandatory=$true)][string]$Region
	)

	Import-Module AWSPowershell

	[System.Collections.ArrayList]$S3Array = @()

	$S3Buckets = Get-S3Bucket -ProfileName $Account -Region $Region

	foreach($S3Bucket in $S3Buckets)
	{
		$S3BucketTags = Get-S3BucketTagging -BucketName $S3Bucket.BucketName -ProfileName $Account -Region $Region

		if(!$S3BucketTags)
		{
			$S3BucketTags = Set-EmptyTags -DesiredTagKeys $TagKeys
		}

		$PropertyHash = Get-TagValues -TagObject $S3BucketTags -DesiredTagKeys $TagKeys -Nullify

		$PropertyHash.Add("Account",$Account)
		$PropertyHash.Add("Region",$Region)
		$PropertyHash.Add("ResourceId",$S3Bucket.BucketName)
		$PropertyHash.Add("ResourceType","S3Bucket")

		$S3Object = New-Object -TypeName psobject -Property $PropertyHash
		$S3Array += $S3Object
	}
	return $S3Array
}

function Get-LambdaData
{
	param(
		[Parameter(Mandatory=$true)][string]$Account,
		[Parameter(Mandatory=$true)][string]$Region
	)

	Import-Module AWSPowershell

	[System.Collections.ArrayList]$LambdaArray = @()

	$LambdaFunctions = Get-LMFunctionList -ProfileName $Account -Region $Region

	foreach($Function in $LambdaFunctions)
	{
		$FunctionTags = Get-LMFunction -FunctionName $Function.FunctionName -ProfileName $Account -Region $Region

		if(!$FunctionTags)
		{
			$FunctionTags = Set-EmptyTags -DesiredTagKeys $TagKeys
		}

		$PropertyHash = Get-TagValues -TagObject $FunctionTags -DesiredTagKeys $TagKeys -Nullify

		$PropertyHash.Add("Account",$Account)
		$PropertyHash.Add("Region",$Region)
		$PropertyHash.Add("ResourceId",$Function.FunctionName)
		$PropertyHash.Add("ResourceType","LambdaFunction")

		$FunctionObject = New-Object -TypeName psobject -Property $PropertyHash
		$LambdaArray += $FunctionObject
	}

	return $LambdaArray
}

function Get-StepFunctionData
{
	#Step Functions won't let me open tags in the console (Access Denied). There's also no PoSh cmdlet for it at this time. Skipping
	param(
		[Parameter(Mandatory=$true)][string]$Account,
		[Parameter(Mandatory=$true)][string]$Region
	)

	Import-Module AWSPowershell

	[System.Collections.ArrayList]$StepFunctionArray = @()

	$StateMachines = Get-SFNStateMachineList -ProfileName $Account -Region $Region

	foreach($StateMachine in $StateMachines)
	{
		$SFNStateMachine = Get-SFNStateMachine -StateMachineArn $StateMachine.StateMachineArn -ProfileName $Account -Region $Region


	}
}

function Get-IAMData
{
	param(
		[Parameter(Mandatory=$true)][string]$Account,
		[Parameter(Mandatory=$true)][string]$Region
	)

	Import-Module AWSPowershell

	[System.Collections.ArrayList]$IAMArray = @()

	$IAMRoles = Get-IAMRoleList -ProfileName $Account -Region $Region

	foreach($IAMRole in $IAMRoles)
	{
		$IAMTags = Get-IAMRoleTagList -RoleName $IAMRole.RoleName -ProfileName $Account -Region $Region

		if(!$IAMTags)
		{
			$IAMTags = Set-EmptyTags -DesiredTagKeys $TagKeys
		}

		$PropertyHash = Get-TagValues -TagObject $IAMTags -DesiredTagKeys $TagKeys -Nullify

		$PropertyHash.Add("Account",$Account)
		$PropertyHash.Add("Region",$Region)
		$PropertyHash.Add("ResourceId",$IAMRole.Arn)
		$PropertyHash.Add("ResourceType","IAMRole")

		$IAMObject = New-Object -TypeName psobject -Property $PropertyHash
		$IAMArray += $IAMObject
	}
	return $IAMArray
}

function Get-ElasticCacheData
{
	param(
		[Parameter(Mandatory=$true)][string]$Account,
		[Parameter(Mandatory=$true)][string]$Region
	)

	Import-Module AWSPowershell

	[System.Collections.ArrayList]$ElasticCacheArray = @()

	$AWSAccountId = (Get-STSCallerIdentity -ProfileName int).Arn.Split(':')[4]

	$ECClusters = Get-ECCacheCluster -ProfileName $Account -Region $Region

	foreach($Cluster in $ECClusters)
	{
		$ECClusterARN = "arn:aws:elasticache:" + $Region + ":" + $AWSAccountId + ":cluster:" + $Cluster.CacheClusterId

		$ECTags = Get-ECTag -ResourceName $ECClusterARN -ProfileName $Account -Region $Region

		if(!$ECTags)
		{
			$ECTags = Set-EmptyTags -DesiredTagKeys $TagKeys
		}

		$PropertyHash = Get-TagValues -TagObject $ECTags -DesiredTagKeys $TagKeys -Nullify

		$PropertyHash.Add("Account",$Account)
		$PropertyHash.Add("Region",$Region)
		$PropertyHash.Add("ResourceId",$ECClusterARN)
		$PropertyHash.Add("ResourceType","ElasticCacheCluster")

		$ECObject = New-Object -TypeName psobject -Property $PropertyHash
		$ElasticCacheArray += $ECObject
	}
	return $ElasticCacheArray
}

function Get-ElasticSearchData
{
	param(
		[Parameter(Mandatory=$true)][string]$Account,
		[Parameter(Mandatory=$true)][string]$Region
	)

	Import-Module AWSPowershell

	[System.Collections.ArrayList]$ElasticSearchArray = @()

	$ESDomains = Get-ESDomainNameList -ProfileName $Account -Region $Region

	foreach($Domain in $ESDomains)
	{
		$DomainInfo = Get-ESDomain -DomainName $Domain.DomainName -ProfileName $Account -Region $Region
		$ESTags = Get-ESResourceTag -ARN $DomainInfo.ARN -ProfileName $Account -Region $Region

		if(!$ESTags)
		{
			$ESTags = Set-EmptyTags -DesiredTagKeys $TagKeys
		}

		$PropertyHash = Get-TagValues -TagObject $ESTags -DesiredTagKeys $TagKeys -Nullify

		$PropertyHash.Add("Account",$Account)
		$PropertyHash.Add("Region",$Region)
		$PropertyHash.Add("ResourceId",$DomainInfo.ARN)
		$PropertyHash.Add("ResourceType","ElasticSearchDomain")

		$ESObject = New-Object -TypeName psobject -Property $PropertyHash
		$ElasticSearchArray += $ESObject
	}
	return $ElasticSearchArray
}

Import-Module AWSPowershell

$Date = Get-Date -Format "yyyyMMdd_hhmmss"

[System.Collections.ArrayList]$Accounts = @(<##>'prd-ncr','pprd1','preprd','prd','tpprd')#,'int','sb','devops-dev')

$Regions = @('us-east-1','us-east-2','us-west-1','us-west-2','ap-northeast-1','ap-northeast-2','ap-northeast-3','ap-south-1','ap-southeast-1','ap-southeast-2','ca-central-1','cn-north-1','cn-northwest-1','eu-central-1','eu-west-1','eu-west-2','eu-west-3','sa-east-1')

[System.Collections.ArrayList]$ResourceArray = @()
[System.Collections.ArrayList]$RuntimeArray = @()

$TagKeys = @("Name","Product","Service","Owner")


foreach($Account in $Accounts)
{
	foreach($Region in $Regions)
	{
		$ParamSplat = @{"Account" = $Account; "Region" = $Region}

		$EC2StartTime = Get-Date
		$ResourceArray += Get-EC2Data @ParamSplat
		$EC2Time = New-TimeSpan -Start $EC2StartTime -End (Get-Date)

		$ELBStartTime = Get-Date
		$ResourceArray += Get-ELBData @ParamSplat
		$ELBTime = New-TimeSpan -Start $ELBStartTime -End (Get-Date)

		$S3StartTime = Get-Date
		$ResourceArray += Get-S3Data @ParamSplat
		$S3Time = New-TimeSpan -Start $S3StartTime -End (Get-Date)

		$LMStartTime = Get-Date
		$ResourceArray += Get-LambdaData @ParamSplat
		$LMTime = New-TimeSpan -Start $LMStartTime -End (Get-Date)

		$ECStartTime = Get-Date
		$ResourceArray += Get-ElasticCacheData @ParamSplat
		$ECTime = New-TimeSpan -Start $ECStartTime -End (Get-Date)

		$ESStartTime = Get-Date
		$ResourceArray += Get-ElasticSearchData @ParamSplat
		$ESTime = New-TimeSpan -Start $ESStartTime -End (Get-Date)

		$RDSStartTime = Get-Date
		$ResourceArray += Get-RDSData @ParamSplat
		$RDSTime = New-TimeSpan -Start $RDSStartTime -End (Get-Date)

		$CFStartTime = Get-Date
		$ResourceArray += Get-CFData @ParamSplat
		$CFTime = New-TimeSpan -Start $CFStartTime -End (Get-Date)

		$SQSStartTime = Get-Date
		$ResourceArray += Get-SQSData @ParamSplat
		$SQSTime = New-TimeSpan -Start $SQSStartTime -End (Get-Date)


		$TimeHash = [ordered]@{
			Account = $Account
			Region = $Region
			EC2Time = $EC2Time
			ELBTime = $ELBTime
			S3Time = $S3Time
			LMTime = $LMTime
			ECTime = $ECTime
			ESTime = $ESTime
			RDSTime = $RDSTime
			CFTime = $CFTime
			SQSTime = $SQSTime
		}
		$TimeObject = New-Object -TypeName psobject -Property $TimeHash
		$RuntimeArray += $TimeObject
	}
}

foreach($Resource in $ResourceArray)
{
	Export-Csv -InputObject $Resource -Path "D:\Users\aschwabe\Desktop\$Date-MT-AllResources.csv" -Append -NoTypeInformation
}

foreach($Runtime in $RuntimeArray)
{
	Export-Csv -InputObject $Runtime -Path "D:\Users\aschwabe\Desktop\$Date-MT-Times.csv" -Append -NoTypeInformation
}
