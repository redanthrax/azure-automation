<#
    .DESCRIPTION
        A runbook to logout all WVD users

    .NOTES
        AUTHOR: red
#>

try
{
    $AzureContext = (Connect-AzAccount -Identity).Context
}
catch {

    Write-Error -Message $_.Exception
    throw $_.Exception
}

Write-Output "-Context-"
$AzureContext

$ExistingHostPools = Get-AzResource | Where-Object ResourceType -eq Microsoft.DesktopVirtualization/hostpools
Write-Output "-Host Pools-"
$ExistingHostPools
 
if (($ExistingHostPools).count -gt "0") {
# Log off connected Users
    foreach($Hostpool in $ExistingHostPools){
        $WVDUserSessions = Get-AzWvdUserSession -HostPoolName $Hostpool.Name -ResourceGroupName $Hostpool.ResourceGroupName
        Write-Output "-Sessions-"
        $WVDUserSessions
        $NumberofWVDSessions = ($WVDUserSessions).count
        if ($NumberofWVDSessions -gt "0") {
            try {
                foreach ($WVDUserSession in $WVDUserSessions){
                    $InputString = $WVDUserSession.Name
                    $WVDUserArray = $InputString.Split("/")
                    Remove-AzWvdUserSession -HostPoolName $Hostpool.Name -ResourceGroupName $Hostpool.ResourceGroupName -SessionHostName $WVDUserArray[1] -Id $WVDUserArray[2]
                }
            }
            catch { }
        }
    }
}