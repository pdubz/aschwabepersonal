Param(
  [string]$space
)
if($space -eq ''){
 write-host "Parameter -space must be specified"
 exit
}

$dataSource = ".\SQLEXPRESS"
$user = "sa"
$pwd = "Lawson123"
$database = "master"
$connectionString = "Server=$dataSource;uid=$user; pwd=$pwd;Database=$database;Integrated Security=False;"

$query = "SELECT name FROM sys.databases where name like '$space\_%' escape '\'"

$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$connection.Open()
$command = $connection.CreateCommand()
$command.CommandText  = $query

$result = $command.ExecuteReader()

$caption = "Confirm database drop"
$yes = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes","help"
$no = new-Object System.Management.Automation.Host.ChoiceDescription "&No","help"
$choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no)


while ($result.Read()) { 
  $message = "Drop database " + $result["name"]+"?"
  $answer = $host.ui.PromptForChoice($caption,$message,$choices,0)
  if($answer -eq 0){
    cmd /c .\drop_database_and_user.cmd $result["name"]
  }
}

$connection.Close()
