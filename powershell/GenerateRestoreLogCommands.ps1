$Files = Get-ChildItem -Path "\\tam01-q\backup\log\BEXARCOUNTYUHS_TRN_TAM_MSF_0" | Sort-Object -Property CreationTime

$Commands = @()

foreach($File in $Files)
{
    if(($File.CreationTime -gt "08/02/2018 08:00:00 AM") -and ($File.CreationTime -lt "08/02/2018 02:05:00 PM"))
    {
        $Command = "RESTORE LOG [BEXARCOUNTYUHS_TRN_TAM_MSF_0] FROM DISK = '" + $File.FullName + "' WITH FILE=1, NORECOVERY, NOUNLOAD, STATS=50"
        $Commands += $Command
    }
}

Out-File -InputObject $Commands -FilePath E:\restores01\20180802_restore.txt