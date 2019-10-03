Import-Module AWSPowershell

$Date = Get-Date -Format "yyyyMMddhhmmss"

$Account = 'stcs'
$Region = 'us-east-1'

[System.Collections.ArrayList]$Instances = @()
[System.Collections.ArrayList]$Volumes = @()

$EC2Infos = Get-EC2Instance -Filter @{name='tag:IxsId'; values="1097184"} -ProfileName $Account -Region $Region

foreach($EC2Info in $EC2Infos)
{
    $PropertyHash = @{
        Account = $Account
        Region = $Region
        InstanceId = $EC2Info.Instances.InstanceId
        InstanceType = $EC2Info.Instances.InstanceType.Value
        NameTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'Name'}).Value
        MachineLabelTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'machineLabel'}).Value
        ServiceTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'Service'}).Value
        ProductTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'Product'}).Value
        CostCenterTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'CostCenter'}).Value
        customerPrefixTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'customerPrefix'}).Value
        isProductionTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'isProduction'}).Value
        IxsIdTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'IxsId'}).Value
        SftxIdTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'SftxId'}).Value
    }

    $IID = $EC2Info.Instances.InstanceId
    $InstanceName = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'Name'}).Value

    $InstanceObject = New-Object -TypeName psobject -Property $PropertyHash
    Export-Csv -InputObject $InstanceObject -Path D:\Users\aschwabe\Desktop\$Date-PilotServers.csv -Append -NoTypeInformation
    $Instances += $InstanceObject

    $VolumeInfo = Get-EC2Volume -ProfileName $Account -Region $Region -Filter @{Name="attachment.instance-id";Values="$IID"}
    
    foreach ($VolInfo in $VolumeInfo)
    {
        $PropertyHash = @{
            Account = $Account
            Region = $Region
            AttachedInstanceId = $IID
            AttachedInstanceName = $InstanceName
            VolumeId = $VolInfo.VolumeId
            VolumeSize = $VolInfo.Size
            VolumeIOPs = $VolInfo.Iops
            VolumeType = $VolInfo.VolumeType
            VolumeNameTag = ($VolInfo.Tags | Where-Object {$_.Key -eq 'Name'}).Value
            VolumeStatus = ($VolInfo.Status).Value
            VolumeMountPoint = $VolInfo.Attachments.Device
        }
        
        $VolObj = New-Object -TypeName psobject -Property $PropertyHash
        Export-Csv -InputObject $VolObj -Path D:\Users\aschwabe\Desktop\$Date-PilotVolumes.csv -Append -NoTypeInformation
        $Volumes += $VolObj
    }
}





