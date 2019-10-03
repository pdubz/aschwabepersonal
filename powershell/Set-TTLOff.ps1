$LSNR = Get-ClusterResource | Where-Object Name -like "*-lsnr"
$RestartRequired = 0

try
{
	$HostRecordTTLValue = (Get-ClusterParameter -InputObject $LSNR -Name HostRecordTTL).Value
}
catch
{
	$_
}

if($HostRecordTTLValue -ne 300)
{
	try
	{
		Set-ClusterParameter -InputObject $LSNR -Name HostRecordTTL -Value 300
		$RestartRequired += 1
	}
	catch
	{
		$_
	}
}

try
{
	$RegisterAllProvidersIPValue = (Get-ClusterParameter -InputObject $LSNR -Name RegisterAllProvidersIP).Value
}
catch
{
	$_
}

if($RegisterAllProvidersIPValue -ne 1)
{
	try
	{
		Set-ClusterParameter -InputObject $LSNR -Name RegisterAllProvidersIP -Value 1
		$RestartRequired += 1
	}
	catch
	{
		$_
	}
}

if($RestartRequired -gt 0)
{
	Stop-ClusterResource -InputObject $LSNR
	Start-ClusterResource -InputObject $LSNR

	$AG = Get-ClusterResource | Where-Object ResourceType -eq "SQL Server Availability Group"

	if($AG.State -ne 'Online')
	{
		Start-ClusterResource -InputObject $AG
	}
}
