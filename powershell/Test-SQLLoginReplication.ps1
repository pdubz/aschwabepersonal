Import-Module SQLPS -DisableNameChecking
Set-Location C:\scripts
$ClusterNodes = (Get-ClusterNode | Where-Object {$_.State -eq 'Up'}).Name
$BeginWith = $ClusterNodes[0]
$Output = @()

for($i=1;$i-le($ClusterNodes.Length);$i++)
{
	$RefServer = (Invoke-Sqlcmd -Query 'SELECT * FROM master.sys.server_principals' -ServerInstance $BeginWith).name
	$DiffServer = (Invoke-Sqlcmd -Query 'SELECT * FROM master.sys.server_principals' -ServerInstance $ClusterNodes[$i]).name
	$Compare = Compare-Object -ReferenceObject $RefServer -DifferenceObject $DiffServer
	foreach($Comp in $Compare)
	{
		$PropertyHash = @{
			LoginName = $Comp.InputObject
			ReferenceServer = $BeginWith
			SideIndicator = $Comp.SideIndicator
			DifferenceServer = $ClusterNodes[$i]
		}
		$ComparisionObject = New-Object psobject -Property $PropertyHash
		$Output += $ComparisionObject
	}
	$BeginWith = $ClusterNodes[$i]
}

$Output | Format-Table -Property LoginName,ReferenceServer,SideIndicator,DifferenceServer
