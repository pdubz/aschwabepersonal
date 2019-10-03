$sourceURL = 'https://api.stackdriver.com/v0.2'
$apiKey = '6F69JAQ5IMT0T1KOXI0Z1M0OR90MM7EL'
$head = @{"x-stackdriver-apikey" = $apiKey}
$out = 'D:\Users\aschwabe\sd'
$ncr = @()

#Group
$getGroup = 'groups'
$outGroup = "$out\$getGroup.json"
Invoke-RestMethod -Method Get -Uri "$sourceURL/$getGroup" -Headers $head -OutFile $outGroup
$json = Get-Content $outGroup
$parsedGroup = $json | ConvertFrom-Json
foreach($group in $parsedGroup.data){
    if($group.parent_id -eq '10691'){
        $ncr += $group
    }
    else{}
}


#dashboard
$getDashboard = 'dashboards'
$outDashboard = "$out\$getDashboard.json"
Invoke-RestMethod -Method Get -Uri "$sourceURL/$getDashboard" -Headers $head -OutFile $outDashboard
$json = Get-Content $outDashboard
$parsedDashboard = $json | ConvertFrom-Json


#Policies
$getPolicies = 'alerting/policies/'
$outPolicies = "$out\policies.json"
Invoke-RestMethod -Method Get -Uri "$sourceURL/$getPolicies" -Headers $head -OutFile $outPolicies
$json = Get-Content $outPolicies
$parsedPolicies = $json | ConvertFrom-Json

#dashboard
$getDashboard = 'dashboards'
$outDashboard = "$out\$getDashboard.json"
Invoke-RestMethod -Method Get -Uri "$sourceURL/$getDashboard" -Headers $head -OutFile $outDashboard
$json = Get-Content $outDashboard
$parsedDashboard = $json | ConvertFrom-Json


$getGroup = 'groups'
$outNCR = "$out\NCRgroup.json"
Invoke-RestMethod -Method Get -Uri "$sourceURL/groups/11883/members/" -Headers $head -OutFile $outNCR
$json = Get-Content $outNCR
$parsedNCR = $json | ConvertFrom-Json