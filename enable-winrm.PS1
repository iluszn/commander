<# 
 
 
 
 
UPDATED:  27/03/2020 
UPDATE AUTHOR:  Denis Duri 
 
UPDATES: 
 
-- Added OS version check as 2016 and above does not require the import of servermanager 
-- Added Firewall rule check (If run in LCT will show in vRO Logs) 
-- Added Function check-winrm-service to ensure running and configured as expected (If run in LCT will show in vRO Logs) 
 
 
 
#> 
$Folder = "c:\temp"

###################################

try { 
# Body of script. 

write-host "Checking if $Folder exists"
if (Test-Path -Path $Folder) {
    write-host "$Folder already exists"
    } 
else
    {
    write-host "$Folder does not exist, creating folder"
    mkdir c:\temp


write-host "Starting transcipt to $Folder to check on installation completion"
Start-Transcript -Path "C:\temp\WinRM_Install_$(get-date -f ddMMyyyy).txt" -NoClobber -Confirm:$false -Force

# Check OS Version, servermanager does not need to be run on windows server 2016 and above 
$OSVersion = Get-WmiObject -Class win32_OperatingSystem | select-object Version -ExpandProperty Version 
 
 
if ($OSVersion -notlike "10.0.*") 
    { 
        import-module servermanager 
    } 
else 
    { 
        write-host "Running Windows Server 2016 and above, skipping server manager import" 
    } 
 
# From: http://blogs.technet.com/b/vishalagarwal/archive/2009/08/22/generating-a-certificate-self-signed-using-powershell-and-certenroll-interfaces.aspx 
function SetupWinRM-SelfSignedCert { 
  param( 
    $hostname 
  ) 
 
  # Get the thumbprints of the SSL certificates that match the hostname 
  $thumbprints = Get-Childitem -path cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$hostname" } | Select-Object -Property Thumbprint 
  # PowerShell magic to retrieve the first matching thumbprint (there'll probably only be one anyway) 
  $thumbprint = @($thumbprints)[0].Thumbprint 
 
  # Create a WinRM listener, identifying the SSL certificate by the thumbprint 
  Try { 
    # Will throw an exception if no listener found with those constraints 
    Get-WSManInstance WinRM/Config/Listener -SelectorSet @{Address = "*"; Transport = "HTTPS"} | Out-Null 
 
    Write-Host "Updating existing WinRM HTTPS listener with hostname and thumbprint" 
    Set-WSManInstance WinRM/Config/Listener -SelectorSet @{Address = "*"; Transport = "HTTPS"} -ValueSet @{Hostname = $hostname; CertificateThumbprint = $thumbprint} | Out-Null 
  } 
  Catch [InvalidOperationException] { 
    Write-Host "Creating new WinRM HTTPS Listener" 
    New-WSManInstance WinRM/Config/Listener -SelectorSet @{Address = "*"; Transport = "HTTPS"} -ValueSet @{Hostname = $hostname; CertificateThumbprint = $thumbprint} | Out-Null 
  } 
} 
 
# From: http://blogs.technet.com/b/vishalagarwal/archive/2009/08/22/generating-a-certificate-self-signed-using-powershell-and-certenroll-interfaces.aspx 
function Create-SelfSignedCert { 
  param( 
    $hostname 
  ) 
  $numHostnames = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$hostname" } | measure | Select-Object -Property Count 
  If($numHostnames.Count -eq 0) { 
    Write-Host "Generating self-signed certificate" 
 
    $name = New-Object -COM 'X509Enrollment.CX500DistinguishedName.1' 
    $name.Encode("CN=$hostname", 0) | Out-Null 
 
    $key = New-Object -COM 'X509Enrollment.CX509PrivateKey.1' 
    $key.ProviderName = 'Microsoft RSA SChannel Cryptographic Provider' 
    $key.KeySpec = 1 
    $key.Length = 1024 
    $key.SecurityDescriptor = "D:PAI(A;;0xd01f01ff;;;SY)(A;;0xd01f01ff;;;BA)(A;;0x80120089;;;NS)" 
    $key.MachineContext = 1 
    $key.Create() | Out-Null 
 
    $serverAuthOID = New-Object -COM 'X509Enrollment.CObjectId.1' 
    $serverAuthOID.InitializeFromValue('1.3.6.1.5.5.7.3.1') | Out-Null 
 
    $ekuOIDs = New-Object -COM 'X509Enrollment.CObjectIds.1' 
    $ekuOIDs.add($serverAuthOID) | Out-Null 
 
    $ekuExt = New-Object -COM 'X509Enrollment.CX509ExtensionEnhancedKeyUsage.1' 
    $ekuExt.InitializeEncode($ekuOIDs) | Out-Null 
 
    $cert = New-Object -COM 'X509Enrollment.CX509CertificateRequestCertificate.1' 
    $cert.InitializeFromPrivateKey(2, $key, '') | Out-Null 
    $cert.Subject = $name 
    $cert.Issuer = $cert.Subject 
    $cert.NotBefore = Get-Date 
    $cert.NotAfter = $cert.NotBefore.AddDays(9999) 
    $cert.X509Extensions.add($ekuExt) | Out-Null 
    $cert.Encode() | Out-Null 
 
    $enrollment = New-Object -COM 'X509Enrollment.CX509Enrollment.1' 
    $enrollment.InitializeFromRequest($cert) | Out-Null 
    $certData = $enrollment.CreateRequest(0) 
    $enrollment.InstallResponse(2, $certData, 0, '') | Out-Null 
  } 
  Else { 
    Write-Warning "Self-signed certificate already exists for this machine" 
  } 
} 
 
# From http://blogs.msdn.com/b/tomholl/archive/2010/11/08/adding-a-windows-firewall-rule-using-powershell.aspx 
function Add-FirewallRule { 
  param( 
    $name, 
    $tcpPorts, 
    $appName = $null, 
    $serviceName = $null 
  ) 
  $fw = New-Object -ComObject HNetCfg.FWPolicy2 
  $rule = New-Object -ComObject HNetCfg.FWRule 
 
  $rule.Name = $name 
  if ($appName -ne $null) { $rule.ApplicationName = $appName } 
  if ($serviceName -ne $null) { $rule.serviceName = $serviceName } 
  $rule.Protocol = 6 #NET_FW_IP_PROTOCOL_TCP 
  $rule.LocalPorts = $tcpPorts 
  $rule.Enabled = $true 
  $rule.Grouping = "@firewallapi.dll,-23255" 
  $rule.Profiles = 7 # all 
  $rule.Action = 1 # NET_FW_ACTION_ALLOW 
  $rule.EdgeTraversal = $false 
 
  $preExistingRules = $fw.Rules | Where-Object { ($_.LocalPorts -eq $rule.LocalPorts) -and ($_.Enabled -eq $rule.Enabled) -and ($_.Name -eq $rule.Name) -and ($_.Action -eq $rule.Action) } | measure | Select-Object -Property Count 
 
  If($preExistingRules.Count -eq 0) { 
    Write-Host "Adding Firewall rule: $($rule.Name)" 
    $fw.Rules.Add($rule) | Out-Null 
     
    write-host "Confirm the firewall rule/s have been created" 
    $FWRulesSet = $fw.Rules | Where-Object { ($_.LocalPorts -eq $rule.LocalPorts) -and ($_.Enabled -eq $rule.Enabled) -and ($_.Name -eq $rule.Name) -and ($_.Action -eq $rule.Action) } | select-object Name, Enabled, LocalPorts, Grouping,profiles,Action, Protocol 
    write-host "Name: " $FWRulesSet.name 
    write-host "Enabled: " $FWRulesSet.Enabled 
    write-host "Local Ports: " $FWRulesSet.LocalPorts 
    write-host "Grouping: " $FWRulesSet.Grouping 
    write-host "Profiles: " $FWRulesSet.Profiles 
    write-host "Action: " $FWRulesSet.Action 
    write-host "Protocol: " $FWRulesSet.Protocol 
   
    
  } 
  Else { 
    Write-Warning "Firewall rule '$($rule.Name)' already exists for this machine" 
  } 
} 
 
function Start-WinRM-Service { 
  param( 
  $timeout_minutes 
  ) 
  Stop-Service "iphlpsvc" 
  Start-Service "iphlpsvc" 
  Stop-Service "winRM" 
  Start-Service "winRM" 
 
  $timeout = new-timespan -Minutes $timeout_minutes 
  $sw = [diagnostics.stopwatch]::StartNew() 
  while ($sw.elapsed -lt $timeout){ 
      $arrService = Get-Service -Name "winRM" 
   if ($arrService.Status -ne "Running"){ 
      Start-Sleep -seconds 15 
    } elseif  ($arrService.Status -eq "Running"){ 
      Write-Host "Service winRM has started." 
         #Show service status 
         $WinRMInformation = get-service | where-object {$_.name -eq "WinRM"} | select-object Status, Name, DisplayName, StartType 
      write-host $WinRMInformation.DisplayName "Service Information" 
         write-host "Name: "$WinRMInformation.Name 
         write-host "Display name: "$WinRMInformation.DisplayName 
         write-host "Status: "$WinRMInformation.Status 
         write-host "Start type: "$WinRMInformation.StartType 
          
         check-winrm-service 
 
         exit 0 
    } 
  } 
  write-host "WinRM has not started after $timeout_minutes minutes.  Timed out" 
   
  exit 1 
} 
 
Function check-winrm-service { 
 
# Confirm WinRM is setup  
$AuthType = Get-WSManInstance -ResourceURI WinRM/Config/Service/Auth | select-object Basic -ExpandProperty basic 
write-host "Basic auth expected value true, actual value: "$AuthType 
 
$Encryption = Get-WSManInstance WinRM/Config/Service | select-object AllowUnencrypted -ExpandProperty AllowUnencrypted 
write-host "AllowUnencrypted expected value true, actual value: "$Encryption 
 
$memPerShell = Get-WSManInstance WinRM/Config/WinRS  | select-object MaxMemoryPerShellMB -ExpandProperty MaxMemoryPerShellMB 
write-host "MaxMemoryPerShellMB expected value 1024, actual value: "$MemPerShell 
 
$TrustedHosts = Get-WSManInstance WinRM/Config/Client | select-object TrustedHosts -ExpandProperty TrustedHosts 
write-host "Trusted Hosts expected value *, actual value: "$TrustedHosts 
 
$MaxtimeOut = Get-WSManInstance WinRM/Config | select-object MaxTimeoutms -ExpandProperty MaxTimeoutms 
write-host "Max Timeout expected value 6000ms, actual value: "$MaxTimeOut"ms" 
 
} 
 
# =================================================== 
# ==================== MAIN ========================= 
# =================================================== 
 
 
# Configure WinRM 
Write-Host "Running gpupdate" 
cmd /c "gpupdate /force /wait:300 /Logoff" 
 
Write-Host "Setting up WinRM Basic configuration" 
 
Set-WSManInstance WinRM/Config/Service/Auth -ValueSet @{Basic = $true} | Out-Null 
Set-WSManInstance WinRM/Config/Service -ValueSet @{AllowUnencrypted = $true} | Out-Null 
Set-WSManInstance WinRM/Config/WinRS -ValueSet @{MaxMemoryPerShellMB = 1024} | Out-Null 
Set-WSManInstance WinRM/Config/Client -ValueSet @{TrustedHosts="*"} | Out-Null 
Set-WSManInstance WinRM/Config -ValueSet @{MaxTimeoutms="7200000"} | Out-Null 
$shortname = (Get-WmiObject win32_computersystem).DNSHostName 
$domain = (Get-WmiObject win32_computersystem).Domain 
$hostname = "${shortname}.${domain}" 
 
#Ensure SPN is setup correctly, have had instances that setting winrm did not setup SPN. 
Write-Host "Ensuring SPN records are correct for WinRM" 
$shortUpper = $shortname.ToUpper() 
SetSPN -S "WSMAN/$shortUpper.$domain" $shortUpper 2> $null 
SetSPN -S "WSMAN/$shortUpper" $shortUpper 2> $null 
 
Create-SelfSignedCert $hostname 
SetupWinRM-SelfSignedCert $hostname 
Add-FirewallRule "Windows Remote Management HTTP/SSL" "5986" $null $null 
Add-FirewallRule "Windows Remote Management HTTP/Clear" "5985" $null $null 
 
 
Start-WinRM-Service 5 
