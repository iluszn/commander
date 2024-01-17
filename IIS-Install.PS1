$Folder = "c:\temp"
$servername = hostname

###################################

try { 
# Body of script. Gets the user id, gets the managers email address and passes it to JSON format 

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
Start-Transcript -Path "C:\temp\IIS_Install_$(get-date -f ddMMyyyy).txt" -NoClobber -Confirm:$false -Force


write-host "Installing IIS features and all sub features on $serverName"

Install-WindowsFeature -name Web-Server -IncludeManagementTools -confirm:$false

write-host "IIS Has been installed on $serverName"
write-host "confirming that World Wide Publishing Service has started"

$IIS_Services = get-service -Name "W3SVC" | Select -ExpandProperty Status

if ($IIS_Services -eq "Stopped")
    {
        write-host "Starting service for World Wide Publishing Service "
        start-service -name "W3SVC"
    }
else
    {
        write-host "World Wide Publishing Service Status is: $IIS_Services. No further action required"
    }

} 
Catch{ 
    $exception = "$_." 
    Write-Error $exception 
    Exit 1      
}
