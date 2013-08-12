# sqlscan.ps1
# reads list of IP ranges in CIDR format from file, and checks each IP for SQL instances
# and logs instances to csv file
# author: gfs@miracleas.dk
# company: miracle a/s 
# date: 20-02-2013

## functions

$embeddedFunction = {
    function get-instances{
    param ($server, $cred)
        try {
            $localInstances = Get-WmiObject win32_service -computerName $server -Credential $cred -ErrorAction "Stop" `
            | ?{$_.Name -match "mssql*" -and $_.PathName -match "sqlservr.exe"} | %{
            New-Object -TypeName PSObject -Property @{ 
            caption = [Regex]::Match($_.Caption, '(?i)\((.*)\)').Groups[1].Value
            state = $_.State}
            }
        } catch { $localInstances = "WMI Error" }                        
    return $localInstances
    }
}

$source = @"
using System; using System.Net;
public class CIDRcalculations {
        public static IPAddress getStartIP(string ipa) {
            string[] ips = ipa.Split('/');
            IPAddress ip;
            IPAddress.TryParse(ips[0], out ip);
            int bits = Convert.ToInt32(ips[1]);
            uint mask = ~(uint.MaxValue >> bits);
            byte[] ipBytes = ip.GetAddressBytes();  
            byte[] maskBytes = BitConverter.GetBytes(mask); // BitConverter gives bytes in opposite order to GetAddressBytes().
            Array.Reverse(maskBytes, 0, maskBytes.Length);
            byte[] startIPBytes = new byte[ipBytes.Length];
            for (int i = 0; i < ipBytes.Length; i++) startIPBytes[i] = (byte)(ipBytes[i] & maskBytes[i]);
            IPAddress startIP = new IPAddress(startIPBytes); 
            return startIP;
        }
        public static IPAddress getEndIP(string ipa) {
            string[] ips = ipa.Split('/');
            IPAddress ip;
            IPAddress.TryParse(ips[0], out ip);
            int bits = Convert.ToInt32(ips[1]);
            uint mask = ~(uint.MaxValue >> bits);
            byte[] ipBytes = ip.GetAddressBytes(); 
            byte[] maskBytes = BitConverter.GetBytes(mask); // BitConverter gives bytes in opposite order to GetAddressBytes().
            Array.Reverse(maskBytes, 0, maskBytes.Length); 
            byte[] endIPBytes = new byte[ipBytes.Length];
            for (int i = 0; i < ipBytes.Length; i++) endIPBytes[i] = (byte)(ipBytes[i] | ~maskBytes[i]);
            IPAddress endIP = new IPAddress(endIPBytes);
            return endIP;
}       }
"@


## main
$outFile ="C:\Miracle\powerscan\sqlscan.txt"
$IPfile = "C:\Miracle\powerscan\ips.txt"
$MaxConcurrentThreads = 10
$serviceAccPassWord = "ciwA56g.m"
$serviceAccName = "A903975"
$serviceSubDomain = "EMEA"
$pw = convertto-securestring -AsPlainText -Force -String $serviceAccPassWord
$cred = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist "$serviceSubDomain\$serviceAccName", $pw
try {Add-Type -TypeDefinition $source} catch {}

Get-Content $IPfile | Foreach-Object {
    $StartIP = [CIDRcalculations]::getStartIP($_)
    $Endip = [CIDRcalculations]::getEndIP($_)
    [byte[]] $sb = $StartIP.GetAddressBytes()
    [byte[]] $eb = $Endip.GetAddressBytes()
    "CHECKING $_ FROM $StartIP -> $EndIP"
    $fileContent = @()

    $O1 = $sb[0]; $O2 = $sb[1]; $O3 = $sb[2]; $O4 = $sb[3]
    do { do { do { do {
                        
                    write-host "$O1.$O2.$O3.$O4" 
                    start-job -scriptblock {
                        param($oct1, $oct2, $oct3, $oct4, $credentials)
                        
                        #the exiting stuff should happen here
                        try {$hn = [System.Net.Dns]::gethostentry("$oct1.$oct2.$oct3.$oct4").HostName} catch {$hn = '----'}
                        $instances = get-instances "$oct1.$oct2.$oct3.$oct4" $credentials
                        if (-not $instances) {
                                "$oct1.$oct2.$oct3.$oct4;$hn;{0};{1}" -f '----', '----'
                        } 
                        if ($instances -eq 'WMI Error') {
                                "$oct1.$oct2.$oct3.$oct4;$hn;{0};{1}" -f '', 'WMI Error'
                                $instances = $null
                        }
                        if ($instances) {
                            foreach($i in $instances){
                                "$oct1.$oct2.$oct3.$oct4;$hn;{0};{1}" -f $i.caption, $i.state
                            }
                        }
                    } -name("rockme$O1$O2$O3$O4") -InitializationScript $embeddedFunction -argumentList $O1, $O2, $O3, $O4, $cred | out-null

                    while (((get-job | where-object { $_.Name -like "rockme*" -and $_.State -eq "Running" }) | measure).Count -gt $MaxConcurrentThreads)
		            {
                        write-host "." -nonewline
			            Start-Sleep -seconds 1
		            }
                    $O4++
                } while ($O4 -le $eb[3])
                $O3++
            } while ($O3 -le $eb[2])
            $O2++
        } while ($O2 -le $eb[1])
        $O1++
    } while ($O1 -le $eb[0])
}

#wait for all threads to complete...
$Counter = 0
while (((get-job | where-object { $_.Name -like "rockme*" -and $_.state -eq "Running" }) | measure).count -gt 0)
{
	$threadcount = ((get-job | where-object { $_.Name -like "rockme*" -and $_.state -eq "Running" }) | measure).count
	Write-Host "Waiting for $threadcount threads to Complete" 
	Start-Sleep -seconds 2
    $Counter++
    if ($Counter -gt 60) {
        Write-Host "Exiting loop $threadcount threads did not complete"
        break
    }
}

$threadResults = @( )
get-job | where { $_.Name -like "rockme*" -and $_.state -eq "Completed" } | % { $threadResults += Receive-Job $_ ; Remove-Job $_ }
$threadResults

$threadResults | out-file $outFile -force
