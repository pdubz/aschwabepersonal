param(
    [parameter(Mandatory=$false)][string[]]$Users = @("ryoung","omoge","aschwabe","msabado","slugtu","cthompson3","alarsson2","gellis","tnaish","mhetzel","kgustafsson","twijenaike","mgaither","jbohol","llavinajr")
)

Import-Module ActiveDirectory -DisableNameChecking 4>$null

$Groups = @{}

foreach($User in $Users)
{
    $ADGroups = (Get-ADPrincipalGroupMembership -Identity $User).Name

    $Groups.Add($User,$ADGroups)
}

$Records = @()

foreach($Pair in $Groups.GetEnumerator())
{
    $Record = $Pair.Key
    foreach ($Value in $Pair.Value)
    {
        $Record += "," + $Value
    }
    $Records += $Record -join ""
}

Out-File -FilePath D:\Users\aschwabe\File.csv -Encoding utf8 -Force -InputObject $Records
