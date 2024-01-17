$Folder = "c:\temp"
$servername = hostname

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
}
write-host "Starting transcipt to $Folder to check on installation completion"
Start-Transcript -Path "C:\temp\RSAT_Install_$(get-date -f ddMMyyyy).txt" -NoClobber -Confirm:$false -Force

$Tools = Get-WindowsFeature -Name RSAT-AD-Tools | Select-Object DisplayName -ExpandProperty DisplayName
write-host "$Tools will be installed on $serverName"

Install-WindowsFeature -Name RSAT-AD-Tools -Confirm:$false

write-host "$Tools Has been installed on $serverName"
write-host "Confirming module exists for Active Directory"

$admodule = get-module -list -name activedirectory | select-object name

if ($admodule -ne $Null)
    {
        write-host "$Tools is now available in PowerShell"
        
    }
else
    {
        write-host "OOPSS.. Something went wrong.. I can't see the Activedirectory module. Please see c:\temp\ for the transcript of this installation"
    }

} 
Catch{ 
    $exception = "$_." 
    Write-Error $exception 
    Exit 1      
}
