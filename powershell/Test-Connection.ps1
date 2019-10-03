
$Node = ""
$Pass = ""
$SQLDBName = ""
$User = $SQLDBName

[System.Data.SqlClient.SqlConnection]

#Build SQLConnection object
$SQLConnection = New-Object ('System.Data.SqlClient.SqlConnection') "Data Source=$Node;Database=$SQLDBName;User ID=$User;Password=$Pass;Initial Catalog=landmark;Connect Timeout=3;multiSubnetFailover=true;"
#Open the SQLConnection to the node
try
{
    Write-Host "Attempting to open a SQL Connection to $Node."
    $SQLConnection.Open()
}
catch
{
    $ErrorCount++
    Write-Host "Could not establish a connection to a SQL Server on $Node. Ensure a SQL Server is online on the host and that your security group allows traffic over port 1433."
    Write-Host $_
}

#If the connection is open, close it and move on
if($SQLConnection.State -eq "Open")
{
    Write-Host "Successfully opened a SQL Connection to $Node."
    try
    {
        Write-Host "Attempting to close the SQL Connection to $Node."
        $SQLConnection.Close()
    }
    catch
    {
        $ErrorCount++
        Write-Host "Failed to close the SQL Connection to $Node."
        Write-Host $_
    }
    Write-Host "Successfully closed the SQL Connection to $Node."
}
else
{
    $ErrorCount++
    Write-Host "We did not encounter a terminating error while opening a SQL Connection to $Node, but could not successfully validate a connection. Ensure a SQL Server is online on the host and that your security group allows traffic over port 1433."
    Write-Host $_
}