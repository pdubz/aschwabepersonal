Import-Module SQLPS -DisableNameChecking

$fulls = Get-ChildItem -Path X:\
$diffs = Get-ChildItem -Path Y:\
$tlogs = Get-ChildItem -Path Z:\

$dbs = @()

$fullLimit = (Get-Date).AddDays(-7)
$diffLimit = (Get-Date).AddDays(-1).AddHours(8)
$tlogLimit = (Get-Date).AddHours(1)

$goodFulls = @()

$overallBad = @{}

$getDBsCMD = @"
select name
  from master.sys.databases
"@

$dbsFromInstance = (Invoke-Sqlcmd -ServerInstance amsi01-a -Database master -Query $getDBsCMD).ItemArray

foreach($full in $fulls){
    $dbs = Get-ChildItem -Path $full.FullName
    foreach($db in $dbs){
        $fileSize = (($db.Length)/1024)
        if($db.LastWriteTime -gt $fullLimit){
            if($fileSize -gt 1){
                if($goodFulls -notcontains $full.BaseName){
                    $goodFulls += $full.BaseName
                }
            }
        }
    }
}

$badFulls = Compare-Object -ReferenceObject $dbsFromInstance -DifferenceObject $goodFulls 

foreach($badFull in $badFulls){
    if($badFull.InputObject -ne 'tempdb'){
        switch($badFull.SideIndicator){
            '<='{$overallBad.Add($badFull.InputObject,"missing full backup on disk")}
            '=>'{$overallBad.Add($badFull.InputObject,"database may no longer exist")}
        }
    }
}


foreach($diff in $diffs){
    $dbs = Get-ChildItem -Path $diff.FullName
    foreach($db in $dbs){
        $fileSize = (($db.Length)/1024)
        if($db.LastWriteTime -gt $diffLimit){
            if($fileSize -gt 1){
                if($goodDiffs -notcontains $diff.BaseName){
                    $goodDiffs += $diff.BaseName
                }
            }
        }
    }
}

$badDiffs = Compare-Object -ReferenceObject $dbsFromInstance -DifferenceObject $goodDiffs 

foreach($badDiff in $badDiffs){
    if($badDiff.InputObject -ne 'tempdb'){
        switch($badDiff.SideIndicator){
            '<='{$overallBad.Add($badDiff.InputObject,"missing diff backup on disk")}
            '=>'{$overallBad.Add($badDiff.InputObject,"database may no longer exist")}
        }
    }
}