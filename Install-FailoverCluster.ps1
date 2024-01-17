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
Start-Transcript -Path "C:\temp\FailoverCluster_Install_$(get-date -f ddMMyyyy).txt" -NoClobber -Confirm:$false -Force


write-host "The Following features will be installed on $serverName"
write-host "Microsoft Windows Failover Clustering"

Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools -Restart:$false -Confirm:$false

write-host "Failover Clusering Has been installed on $serverName and your server will now be restarted"

Restart-Computer -Confirm:$false -Force
} 
Catch{ 
    $exception = "$_." 
    Write-Error $exception 
    Exit 1      
}
