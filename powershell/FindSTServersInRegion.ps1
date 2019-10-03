param(
    [Parameter(Mandatory=$true)][string]$Account,
    [Parameter(Mandatory=$true)][string]$Region
)
Import-Module AWSPowershell

$Date = Get-Date -Format "yyyyMMddhhmmss"

[System.Collections.ArrayList]$Instances = @()
[System.Collections.ArrayList]$Volumes = @()


$EC2Infos = Get-EC2Instance -Filter @{name='tag:Product'; values="ts"} -ProfileName prd -Region $Region
        
foreach($EC2Info in $EC2Infos)
{
    $PropertyHash = @{
        Account = $Account
        Region = $Region
        InstanceId = $EC2Info.Instances.InstanceId
        InstanceType = $EC2Info.Instances.InstanceType.Value
        NameTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'Name'}).Value
        ServiceTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'Service'}).Value
        ProductTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'Product'}).Value
    }

    $InstanceObject = New-Object -TypeName psobject -Property $PropertyHash
    Export-Csv -InputObject $InstanceObject -Path D:\Users\aschwabe\Desktop\$Date-$Account-$Region-TSServers.csv -Append -NoTypeInformation
    $Instances += $InstanceObject
}
