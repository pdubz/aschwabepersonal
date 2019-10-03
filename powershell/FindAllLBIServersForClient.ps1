param(
    [Parameter(Mandatory=$false)][string[]]$Accounts = @('stcs'),#,'stams','sthy','stlb','stl','stcogc'),
    [Parameter(Mandatory=$false)][string[]]$ClientIDs = @('100040991','1097671','1098353','1098380','1097448','1098293','1099505','100024735','1098316','1097912','1098216','100043233','1097180','1099953','1100149','1100325','100013578','1098019','1097887','100039564','1096784','1097973','1097573','1097493','1097077','1096792','1097097','1097192','1097407','1097713','1098284','1097466','1097897','100049833','1098135','1097962','1098438','100047347','1097454','1098188','100041342','1097327','1097826','1098302','1097224','100041540','1097763')
)

Import-Module AWSPowershell

$Date = Get-Date -Format "yyyyMMddhhmmss"

$Regions = @('us-east-2','us-east-1','us-west-1','us-west-2')#,'ap-northeast-1','ap-northeast-2','ap-northeast-3','ap-south-1','ap-southeast-1','ap-southeast-2','ca-central-1','cn-north-1','cn-northwest-1','eu-central-1','eu-west-1','eu-west-2','eu-west-3','sa-east-1')
[System.Collections.ArrayList]$Instances = @()

foreach($Account in $Accounts)
{
    foreach($Region in $Regions)
    {
        $EC2Infos = Get-EC2Instance -ProfileName $Account -Region $Region
        foreach($EC2Info in $EC2Infos)
        {
            $IxsIdTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'IxsId'}).Value
            foreach($ClientID in $ClientIDs)
            {
                if($IxsIdTag -eq $ClientID)
                {
                    $NameTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'Name'}).Value
                    $MachineLabelTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'machineLabel'}).Value
                    if(($NameTag -ilike '*LBI*') -or ($MachineLabelTag -ilike '*LBI*'))
                    {
                        $NameTag
                        $PropertyHash = @{
                            Account = $Account
                            Region = $Region
                            InstanceId = $EC2Info.Instances.InstanceId
                            InstanceType = $EC2Info.Instances.InstanceType.Value
                            Platform = $EC2Info.Instances.Platform
                            NameTag = $NameTag
                            MachineLabelTag = $MachineLabelTag
                            ServiceTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'Service'}).Value
                            ProductTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'Product'}).Value
                            CostCenterTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'CostCenter'}).Value
                            customerPrefixTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'customerPrefix'}).Value
                            isProductionTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'isProduction'}).Value
                            IxsIdTag = $IxsIdTag
                            SftxIdTag = ($EC2Info.Instances.Tags | Where-Object {$_.Key -eq 'SftxId'}).Value
                        }

                        $InstanceObject = New-Object -TypeName psobject -Property $PropertyHash
                        Export-Csv -Path "D:\Users\aschwabe\Desktop\$Date-LBIServers.csv" -InputObject $InstanceObject -Append -NoTypeInformation -Force -Encoding UTF8
                        $Instances += $InstanceObject
                    }
                }
            }
        }
    }
}
