$bad = Get-Content D:\Users\aschwabe\Documents\bad.txt

Remove-Item D:\Users\aschwabe\Documents\badnames.txt
Remove-Item D:\Users\aschwabe\Documents\badfiles.txt

foreach($b in $bad){
    $badArray = @()
    $badArray = $b.Split(' ')
    Out-File -InputObject $badArray[1] -FilePath D:\Users\aschwabe\Documents\badnames.txt -Append

    Out-File -InputObject $badArray[5] -FilePath D:\Users\aschwabe\Documents\badfiles.txt -Append
}

