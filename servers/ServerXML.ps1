[xml]$XMFile = Get-Content D:\Users\aschwabe\Documents\dbapersonal\aschwabe\scripts\servers\AWS.rdg

$ServersArray = @()

$Groups = $XMFile.RDCMan.file

foreach($Group in $Groups)
{
    $PropertyHash = @{
			Environment = $EnvironmentName
			Account = $AccountName
			Region = $RegionName
			App = $AppName
            Cluster = $ClusterName
            Server = $ServerName
		}

    $ServerObject = New-Object -TypeName psobject -Property $PropertyHash
    
    $Environments = $Group.group
    foreach($Environment in $Environments)
    {
        $EnvironmentName = $Environment.properties.name
        foreach($Account in $Environment.group)
        {
            $AccountName = $Account.properties.name
            foreach($Region in $Account.group)
            {
                $RegionName = $Region.properties.name
                foreach($App in $Region.group)
                {
                    $AppName = $App.properties.name
                    foreach($Cluster in $App.group)
                    {
                        $ClusterName = $Cluster.properties.name
                        foreach($Server in $Cluster.server)
                        {
                            $ServerName = $Server.properties.name

                            $PropertyHash = @{
			                    Environment = $EnvironmentName
			                    Account = $AccountName
			                    Region = $RegionName
			                    App = $AppName
                                Cluster = $ClusterName
                                Server = $ServerName
		                    }

                            $ServerObject = New-Object -TypeName psobject -Property $PropertyHash
                            
                            $ServersArray += $ServerObject
                        }
                    }
                }
            }
        }
    }
}

Format-Table -InputObject $ServersArray -AutoSize
