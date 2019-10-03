param(
    [Parameter(Mandatory=$true)][string]$PDAPIKey
)


$Headers = @{
    "Authorization"="Token token=$PDAPIKey";
    "Accept"="application/vnd.pagerduty+json;version=2"
}

$Users = @()

$Offset = 0

for($i = 1;$i++)
{
    $URI = "https://api.pagerduty.com/users?limit=100&offset=$Offset"

    $Response = Invoke-RestMethod -Method Get -Uri $URI -Headers $Headers

    $Offset = (($i-1)*100)

    $Users += $Response.users

    if($Response.more -ne 'True'){break}
}

$Users[0]

$Date = Get-Date -Format yyyyMMdd-hhmmss

$Users | Select-Object name,email,id | Export-Csv -Path "D:\Users\aschwabe\Desktop\$Date-PDUsers.csv" -NoTypeInformation
