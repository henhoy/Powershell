#####################################################
## Name: Query_Instances.ps1
## 
##Action:  Runs query in _Query_Incstances.sql_ against all instances found in _hostname.txt_
##
## author: hmh@miracleas.dk
## company: miracle a/s 
## date: 16-04-2013
##
#####################################################

function get-instances{
    param ($server, $cred)
        try {
            $localInstances = Get-WmiObject win32_service -computerName $server -Credential $cred -ErrorAction "Stop" `
            | ?{$_.Name -match "mssql*" -and $_.PathName -match "sqlservr.exe"} | %{
            New-Object -TypeName PSObject -Property @{ 
            caption = [Regex]::Match($_.Caption, '(?i)\((.*)\)').Groups[1].Value
            state = $_.State}
            }
        } catch { $localInstances = "" }                        
    return $localInstances
}

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

function do-connectionstring{
	param (
	  [string] $hostname,
	  [string] $instance)
	  
	$ServerInstance = ""
	if ( $instance ) {
      if ( ($instance -eq "MSSQLSERVER") ){ $ServerInstance=$hostname }
	  else { $ServerInstance = "$hostname\$instance" }
	  
	  Write-Host "DEBUG: Serverinstance: $ServerInstance"
	  $connstr = "Provider=SQLOLEDB.1;Initial Catalog=master;Data Source=" + $ServerInstance + ";Database=master;Integrated Security=SSPI;Persist Security Info=False;"
	  }
	else { 
	  Write-Host "DEBUG: *** No valid instance name for $hostname ***"
	  $connstr = "NULL"}
	
	return $connstr
}


### MAIN ###
Write-Host "        "
Write-Host "DEBUG: Starting new scan ..."

$serviceAccPassWord = "gtR4#edCVbn"
$serviceAccName = "a904025"
$serviceSubDomain = "EMEA"

$pw = convertto-securestring -AsPlainText -Force -String $serviceAccPassWord
$cred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist "$serviceSubDomain\$serviceAccName", $pw

$scanresult="instancescan-result_20130812.txt"
"" | Out-File $scanresult

get-content hostname_test.txt | Foreach-Object {
  
  $Hostname=$_
  write-host "DEBUG: Hostname: $Hostname"

  $instances = get-instances $Hostname $cred
  if ($instances) {
    
    $ServerInstance=$instances
    write-host "DEBUG: Instances: $instances"
	
	foreach($i in $instances){
	    if ( $i.state -eq "RUNNING" ) {
		    $instancename = $i.caption
			Write-Host "DEBUG: Instance Name: $instancename"
			$connectionstring = do-connectionstring $Hostname $instancename
			Write-Host "DEBUG: Connectstring is $connectionstring"
			}
		else { Write-Host "DEBUG: The instance i.caption on $hostname is in state $i.state"}
	}

    #$content = "set nocount off; select name from sysdatabases"
	
	$content = "declare @object_name nvarchar(128); set @object_name = 'msdb.dbo.user_access_log'; if object_id(@object_name) begin select * from msdb.dbo.user_access_log; end"
	
    #$connectionstring
  
    if ( $connectionstring -ne "NULL" ) {
	  $err_cnt_before = $error.Count
	  $result = Get-DatabaseData -verbose -connectionString $connectionString -query $content
      
	  $Error_count = $error.Count
	  $Error_text  = $error[0]

  
      "-----------------------------------------------------------" | Out-File -append $scanresult
#    $ServerInstance
#    $Error_count
#    $Error_text
#    $result	  
#  
      "TARGET: $hostname $instancename " | Out-File -append $scanresult
#  
      if ( $Error_count -gt $err_cnt_before ) {
        "ERROR"
        $Error_count | Out-File -append $scanresult
        $Error_text | Out-File -append $scanresult
	    }
      $result | Out-File -append $scanresult
	  }
  Write-Host "   "
  }
}
