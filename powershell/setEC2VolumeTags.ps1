param(
    [parameter(mandatory=$true)][string]$app
)
$vols = Get-EC2Volume
$volIDs = @()
$volNames = @()

$tag = New-Object Amazon.EC2.Model.Tag
$tag.Key = "Service"
$tag.Value = "$app`:db-mssql"

foreach($vol in $vols){
    $volHash = @{}
    $volHash = $vol.Tags
    
    foreach ($volH in $volHash.GetEnumerator()) {
        if($volH.Key -eq "name"){
            if($volH.Value -like "$app`:*"){
                if($volH.Value -like "*FULL"){
                    $volIDs += $vol.VolumeId
                    $volNames += $volH.Value
                }
                if($volH.Value -like "*DIFF"){
                    $volIDs += $vol.VolumeId
                    $volNames += $volH.Value
                }
                if($volH.Value -like "*TLOG"){
                    $volIDs += $vol.VolumeId
                    $volNames += $volH.Value
                }
            }
        }
    }
}

foreach($volID in $volIDs){
    New-EC2Tag -Resource $volID -Tag $tag
}
