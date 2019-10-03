param(
    [Parameter(Mandatory=$false)][ValidateSet('All','ST','MT')][string]$AccountChoice = 'All'
)

Import-Module AWSPowershell

$Date = Get-Date -Format "yyyyMMdd_hhmmss"

[System.Collections.ArrayList]$Accounts = @()
[System.Collections.ArrayList]$STAccounts = @('stcs', 'stams', 'stcogc', 'stl', 'stlb', 'sthy')
[System.Collections.ArrayList]$MTAccounts = @('prd','prd-ncr','pprd1','preprd','int','tpprd','sb','devops-dev')

switch($AccountChoice){
    "All" { $Accounts = $STAccounts + $MTAccounts }
    "ST" { $Accounts = $STAccounts }
    "MT" { $Accounts = $MTAccounts }
    default { $Accounts = $STAccounts + $MTAccounts }
}

$Regions = @('us-east-2','us-east-1','us-west-1','us-west-2','ap-northeast-1','ap-northeast-2','ap-northeast-3','ap-south-1','ap-southeast-1','ap-southeast-2','ca-central-1','cn-north-1','cn-northwest-1','eu-central-1','eu-west-1','eu-west-2','eu-west-3','sa-east-1')

[System.Collections.ArrayList]$InstancesArray = @()

foreach($Account in $Accounts)
{
    foreach($Region in $Regions)
    {
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

                $InstanceType = $Instance.InstanceType.Value

                #$InstanceData = Get-InstanceData -InstanceType $InstanceType

                $PropertyHash = @{
                    Account = $Account
                    Region = $Region
                    InstanceId = $Instance.InstanceId
                    InstanceType = $InstanceType
                    Platform = $Instance.Platform
                    Tenancy = $Instance.Placement.Tenancy.Value
                    NameTag = ($Instance.Tags | Where-Object {$_.Key -eq 'Name'}).Value
                    MachineLabelTag = ($Instance.Tags | Where-Object {$_.Key -eq 'machineLabel'}).Value
                    ServiceTag = ($Instance.Tags | Where-Object {$_.Key -eq 'Service'}).Value
                    ProductTag = ($Instance.Tags | Where-Object {$_.Key -eq 'Product'}).Value
                    CostCenterTag = ($Instance.Tags | Where-Object {$_.Key -eq 'CostCenter'}).Value
                    customerPrefixTag = ($Instance.Tags | Where-Object {$_.Key -eq 'customerPrefix'}).Value
                    isProductionTag = ($Instance.Tags | Where-Object {$_.Key -eq 'isProduction'}).Value
                    IxsIdTag = ($Instance.Tags | Where-Object {$_.Key -eq 'IxsId'}).Value
                    SftxIdTag = ($Instance.Tags | Where-Object {$_.Key -eq 'SftxId'}).Value
                    #OnDemandCost = 
                    #VCPUs =
                    #Memory = 

                }

                $InstanceObject = New-Object -TypeName psobject -Property $PropertyHash
                $InstancesArray += $InstanceObject
            }
        }
    }
}

foreach($Inst in $InstancesArray)
{
    Export-Csv -InputObject $Inst -Path "D:\Users\aschwabe\Desktop\$Date-$AccountChoice-Servers.csv" -Append -NoTypeInformation
}

function Get-InstanceData
{
    [Paramater(Mandatory=$true)][string]$InstanceType

}