# hostscan.ps1
# reads list of hostnames from file, and checks each host for SQL instances
# and logs instances to csv file
# author: hmh@miracleas.dk
# company: miracle a/s 
# date: 16-04-2013


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

function do-sqlxmlconf{
	param ($instance)
	$sqlinstance = ""
##		if ($instance) {
			if ( ($instance -eq "MSSQLSERVER") -or ($instance -eq "") ){ $sqlinstance="SQLSERVER" }
			else { $sqlinstance = "MSSQL`$$instance" }
##			}
##		else { $sqlinstance="HMH" 
		try {
			$localconf = $SQLH2_SQL_CONF_TEMP | 
			foreach-object {
				$_ -replace "#SQLSERVER#", $sqlinstance
			}
		}
		catch { $localconf = $null }
	return $localconf
}

### MAIN

$fileContent = @()
$startRow = New-Object PsObject -Property @{	HostName = "__"
												InstanceName = "__"
												InstanceState = "__"	}
$fileContent += $startRow

$xmlconf="SQLLOGIN.txt"
$SQLH2_CONF_OUT = ""

$SQLH2_CONF_OUT | Out-File $xmlconf

get-content hostname_full.txt | Foreach-Object {

$Hostname=$_
#$Hostname

$serviceAccPassWord = "Miracle42!"
$serviceAccName = "a903975"
$serviceSubDomain = "EMEA"
$pw = convertto-securestring -AsPlainText -Force -String $serviceAccPassWord
$cred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist "$serviceSubDomain\$serviceAccName", $pw

$instances = get-instances $Hostname $cred


if ($instances) {
	foreach($i in $instances){
		$newRow = New-Object PsObject -Property @{	HostName = $Hostname
													InstanceName = $i.caption
													InstanceState = $i.state	}
		$fileContent += $newRow
		"Host: $Hostname INSTANCE: {0} STATE: {1}" -f $i.caption, $i.state}
		if ($i.state -eq "RUNNING" ) {
		  if (($i.caption -eq "MSSQLSERVER") -or ($i.caption -eq ""))
 		  {$SQLH2_CONF_OUT += "SQLCMD -S $Hostname -i loginfo.sql >> sampling.log " -f $i.caption }  
		  else {$SQLH2_CONF_OUT += "SQLCMD -S $Hostname\{0} -i loginfo.sql >> sampling.log" -f $i.caption }
		
		$SQLH2_CONF_OUT += ""
		$SQLH2_CONF_OUT | Out-File -append $xmlconf
	} }
else { "Host: $Hostname - no SQL instance"}
}

#$SQLH2_CONF_OUT | Out-File -append $xmlconf

#$fileContent | Format-Table
#$fileContent | Export-Csv sqlscan.csv
