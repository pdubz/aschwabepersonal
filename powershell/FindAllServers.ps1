Import-Module D:\Users\aschwabe\Documents\dbapersonal\aschwabe\scripts\powershell\modules\AWSReporting\AWSReporting.psm1 -DisableNameChecking

$Accounts = @("devops-dev","auto","sb","int","prd","prd-ncr","pprd1")
$Regions = @("us-east-1","eu-west-1","ap-southeast-2","eu-central-1")

$Date = Get-Date -Format yyyyMMdd 

$File = "D:\Users\aschwabe\Documents\$Date-InstanceList.csv"

foreach($Account in $Accounts)
{
    foreach($Region in $Regions)
    {
        $Instances = Get-SQLInstances -Account $Account -Region $Region
        #$InstanceCSV = ConvertTo-Csv -InputObject $Instances -NoTypeInformation
        #Out-File -InputObject $InstanceList -FilePath $File -Append
        $Instances
    }
}



