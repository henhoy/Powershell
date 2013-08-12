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


### MAIN

##$fileContent = @()
##$startRow = New-Object PsObject -Property @{	HostName = "__"
##												InstanceName = "__"											InstanceState = "__"	}
##$fileContent += $startRow

$scanresult="instancescan-result_20130812.txt"
"" | Out-File $scanresult

get-content hostname_sql7.txt | Foreach-Object {

  $err_cnt_before = $error.Count
  
  $ServerInstance=$_
  
  #$ServerInstance

  $content = "set nocount off; select name from sysdatabases"

  $connectionstring = "Provider=SQLOLEDB.1;Initial Catalog=master;Data Source=" + $ServerInstance + ";Database=master;Integrated Security=SSPI;Persist Security Info=False;"
  #$connectionstring
  
  $result = Get-DatabaseData -verbose -connectionString $connectionString -query $content
  
  $Error_count = $error.Count
  $Error_text  = $error[0]

  
  "-----------------------------------------------------------" | Out-File -append $scanresult
  $ServerInstance
  $Error_count
  $Error_text
  $result	  
  
  $ServerInstance | Out-File -append $scanresult
  
  if ( $Error_count -gt $err_cnt_before ) {
    "ERROR"
    $Error_count | Out-File -append $scanresult
    $Error_text | Out-File -append $scanresult
	}
  $result | Out-File -append $scanresult

}

##$serviceAccPassWord = "Miracle42!"
##$serviceAccName = "a903975"
##$serviceSubDomain = "EMEA"
##$pw = convertto-securestring -AsPlainText -Force -String $serviceAccPassWord
##$cred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist "$serviceSubDomain\$serviceAccName", $pw

##$instances = get-instances $Hostname $cred

##if ($instances) {
##	foreach($i in $instances){
##		$newRow = New-Object PsObject -Property @{	HostName = $Hostname
##													InstanceName = $i.caption
##													InstanceState = $i.state	}
##		$fileContent += $newRow
##		"Host: $Hostname INSTANCE: {0} STATE: {1}" -f $i.caption, $i.state}
##		if ($i.state -eq "RUNNING" ) {
##		  if (($i.caption -eq "MSSQLSERVER") -or ($i.caption -eq ""))
##		  {$SQLH2_CONF_OUT += "SQLCMD -S $Hostname -i loginfo.sql >> sampling.log " -f $i.caption }  
##		  else {$SQLH2_CONF_OUT += "SQLCMD -S $Hostname\{0} -i loginfo.sql >> sampling.log" -f $i.caption }
##		
##		$SQLH2_CONF_OUT += ""
##		$SQLH2_CONF_OUT | Out-File -append $xmlconf
##	} }
##else { "Host: $Hostname - no SQL instance"}



#$result | Out-File -append $scanresult

#$fileContent | Format-Table
#$fileContent | Export-Csv sqlscan.csv
