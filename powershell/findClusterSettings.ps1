#get scriptrunner version

$cluster = Get-Cluster
$resources = Get-ClusterResource -Cluster $cluster
if($resources -notcontains 'AG1'){
    $leaseTimout = 'Not an AG'
}
else{
    $ag = Get-ClusterResource -Name 'AG1' -Cluster $cluster
    $leaseTimout = Get-ClusterParameter -InputObject $ag -Name 'LeaseTimeout'
    $leaseTimout = $leaseTimout.Value
}

$adapterSettings = @()
$netAdapters = Get-NetAdapter
foreach($netAdapter in $netAdapters){
    $netAdapter = $netAdapter.Name
    $adapterSettings += Get-NetAdapterAdvancedProperty -Name $netAdapter -DisplayName 'IPV4 Checksum Offload' | Select-Object DisplayName, DisplayValue
    $adapterSettings += Get-NetAdapterAdvancedProperty -Name $netAdapter -DisplayName 'Large Send Offload V2 (IPv4)' | Select-Object DisplayName, DisplayValue
    $adapterSettings += Get-NetAdapterAdvancedProperty -Name $netAdapter -DisplayName 'TCP Checksum Offload (IPv4)' | Select-Object DisplayName, DisplayValue
    $adapterSettings += Get-NetAdapterAdvancedProperty -Name $netAdapter -DisplayName 'UDP Checksum Offload (IPv4)' | Select-Object DisplayName, DisplayValue
}

$nicDriver = Get-WmiObject Win32_PnPSignedDriver| select devicename, driverversion | where {$_.devicename -eq 'Intel(R) 82599 Virtual Function'}
$pvSHADriver = Get-WmiObject Win32_PnPSignedDriver| select devicename, driverversion | where {$_.devicename -eq 'AWS PV Storage Host Adapter'}
$pvBusDriver = Get-WmiObject Win32_PnPSignedDriver| select devicename, driverversion | where {$_.devicename -eq 'AWS PV Bus'}

$drivers = @($nicDriver,$pvSHADriver,$pvBusDriver)

$values = @{}
foreach($setting in $adapterSettings){
    $values.Add($setting.DisplayName,$setting.DisplayValue)
}
foreach($driver in $drivers){
	$values.Add($driver.devicename,$driver.driverversion)
}
$values.Add("LeaseTimeout",$leaseTimout)
$values.Add("CrossSubnetDelay",$cluster.CrossSubnetDelay)
$values.Add("CrossSubnetThreshold",$cluster.CrossSubnetThreshold)
$values.Add("RouteHistoryLength",$cluster.RouteHistoryLength)
$values.Add("SameSubnetDelay",$cluster.SameSubnetDelay)
$values.Add("SameSubnetThreshold",$cluster.SameSubnetThreshold)
$values = $values.GetEnumerator() | Sort-Object Name

$values | ft -AutoSize
