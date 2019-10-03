$domains = @('prod')

foreach($domain in $domains){
    $lsnr = Get-ADComputer -Filter {name -like "*lsnr"} -Server $domain
    $sql = Get-ADComputer -Filter {name -like "SQL*"} -Server $domain
}

$servers = @()
$servers += $lsnr
$servers += $sql

$servers.Name
