function Get-DatabaseData {
    [CmdletBinding()]
    param (
        [string]$connectionString,
        [string]$query,
        [switch]$isSQLServer
    )
    if ($isSQLServer) {
        Write-Verbose 'in SQL Server mode'
        $connection = New-Object System.Data.SqlClient.SqlConnection
    } else {
        Write-Verbose 'in OleDB mode'
        $connection = New-Object System.Data.OleDb.OleDbConnection
    }
    $connection.ConnectionString = $connectionString
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    if ($isSQLServer) {
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    } else {
        $adapter = New-Object System.Data.OleDb.OleDbDataAdapter $command
    }
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataset)
    $dataset.Tables[0]
}
function Invoke-DatabaseQuery {
    [CmdletBinding()]
    param (
        [string]$connectionString,
        [string]$query,
        [switch]$isSQLServer
    )
    if ($isSQLServer) {
        Write-Verbose 'in SQL Server mode'
        $connection = New-Object System.Data.SqlClient.SqlConnection
    } else {
        Write-Verbose 'in OleDB mode'
        $connection = New-Object System.Data.OleDb.OleDbConnection
    }
    $connection.ConnectionString = $connectionString
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $connection.Open()
    $command.ExecuteNonQuery()
    $connection.close()
}

$ServerInstance = "dk-tc100173.emea.group.grundfos.com"
$ServerInstance

#Get-DatabaseData -verbose -connectionString 'Server=localhost\MAPS;Database=master;Trusted_Connection=True;' -isSQLServer -query "SELECT name FROM master.sys.databases"
$SQL_LOGIN_INFO = get-content c:\Miracle\powerscan\q_table.sql
#$content = [IO.File]::ReadAllText("c:\Miracle\powerscan\loginfo.sql")

##$content = "DECLARE @ver nvarchar(128);SET @ver = CAST(serverproperty('Edition') AS nvarchar);select @ver, CAST(serverproperty('ProductVersion') AS nvarchar);"
$content = "select count(*) from msdb.dbo.user_access_log;"

$connectionstring = "Provider=SQLOLEDB.1;Initial Catalog=master;Data Source=" + $ServerInstance + ";Database=master;Integrated Security=SSPI;Persist Security Info=False;"
#$result = Get-DatabaseData -verbose -connectionString $connectionString -query $SQL_LOGIN_INFO
$result = Get-DatabaseData -verbose -connectionString $connectionString -query $content
#$result = Get-DatabaseData -verbose -connectionString 'Provider=SQLOLEDB.1;Initial Catalog=master;Data Source=.\MAPS;Database=master;Integrated Security=SSPI;Persist Security Info=False;' -query $content
$result


