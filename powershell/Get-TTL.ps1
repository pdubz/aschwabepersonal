$LSNR = Get-ClusterResource | Where-Object Name -like "*-lsnr"

try
{
	$HostRecordTTLValue = (Get-ClusterParameter -InputObject $LSNR -Name HostRecordTTL).Value
}
catch
{
	Write-Output "Error encountered while attempting to obtain value of HostRecordTTL."
	Write-Output $_
}

Write-Output "HostRecordTTL is set to '$HostRecordTTLValue'."

try
{
	$RegisterAllProvidersIPValue = (Get-ClusterParameter -InputObject $LSNR -Name RegisterAllProvidersIP).Value
}
catch
{
	Write-Output "Error encountered while attempting to obtain value of RegisterAllProvidersIP."
	Write-Output $_
}

Write-Output "RegisterAllProvidersIP is set to '$RegisterAllProvidersIPValue'."
