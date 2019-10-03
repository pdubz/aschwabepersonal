param(
    [parameter(mandatory=$true)][string]$app,
    [parameter(mandatory=$true)][string]$hours
)
$serviceURI = "https://inforcloud.pagerduty.com/api/v1/services"
$mwURI = "https://inforcloud.pagerduty.com/api/v1/maintenance_windows"
$outfile = "$env:USERPROFILE\Documents\pgFiles"

$APIKey = Get-Content "$env:USERPROFILE\Documents\pgAPI.txt"
$header = @{'Authorization'="Token token=$APIKey"}

Invoke-RestMethod -Method Get -Uri $serviceURI -Headers $header -OutFile "$outfile\service.json"

$serviceJSON = Get-Content "$outfile\service.json"
$services = ConvertFrom-Json $serviceJSON

foreach($service in $services.services){
    $name = $service.name
    $splitService = @()
    $splitService = $name.Split(':')
    if($splitService[1] -eq 'db-mssql'){
        if($splitService[0] -eq $app){
            $serviceID = $service.id
            $currenDateTime = (Get-Date).AddMinutes("1")
            $timeForOutage = (Get-Date).AddHours($hours)
            $queryString = "?start_time=$currenDateTime&end_time=$timeForOutage&service_ids=$serviceID"
            Invoke-RestMethod -Method Post -Uri $mwURI -Headers $header -OutFile "$outfile\mw.json"
        }
    }

}
<#
##Reports Code
Invoke-RestMethod -Method Get -Uri "$alertsPerTimeURI/?since=$dtsince&until=$dtuntil" -Headers $header -OutFile $alertsPerTimeFile
Invoke-RestMethod -Method Get -Uri "$incsPerTimeURI/?since=$dtsince&until=$dtuntil" -Headers $header -OutFile $incsPerTimeFile

$alertsPerTimeJSON = Get-Content $alertsPerTimeFile
$incsPerTimeJSON = Get-Content $incsPerTimeFile

$alertsPerTime = ConvertFrom-Json $alertsPerTimeJSON
$incsPerTime = ConvertFrom-Json $incsPerTimeJSON
$alertsPerTimeURI = 'https://inforcloud.pagerduty.com/api/v1/reports/alerts_per_time'
$incsPerTimeURI = 'https://inforcloud.pagerduty.com/api/v1/reports/incidents_per_time'
$alertsPerTimeFile = "$env:USERPROFILE\alertsPerTime.json"
$incsPerTimeFile = "$env:USERPROFILE\incsPerTime.json"

$dtsince = '2015-03-06'
$dtuntil = '2015-03-07'
#>

