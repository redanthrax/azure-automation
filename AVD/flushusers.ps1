<#
    .DESCRIPTION
        A runbook to logout all WVD users

    .NOTES
        AUTHOR: red
#>

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Connect-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$ExistingHostPool = Get-AzResource | Where-Object ResourceType -eq Microsoft.DesktopVirtualization/hostpools
 
if (($ExistingHostPool).count -gt "0") {
# Log off connected Users
    foreach($Hostpool in $ExistingHostPool){
        $WVDUserSessions = Get-AzWvdUserSession -HostPoolName $Hostpool.Name -ResourceGroupName $ResourceGroupName
        $NumberofWVDSessions = ($WVDUserSessions).count
        if ($NumberofWVDSessions -gt "0") {
            try {
                foreach ($WVDUserSession in $WVDUserSessions){
                    $InputString = $WVDUserSession.Name
                    $WVDUserArray = $InputString.Split("/")
                    Remove-AzWvdUserSession -HostPoolName $Hostpool.Name -ResourceGroupName $ResourceGroupName -SessionHostName $WVDUserArray[1] -Id $WVDUserArray[2]
                }
            }
            catch { }
        }
    }
}