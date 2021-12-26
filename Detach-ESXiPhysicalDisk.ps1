function Detach-ESXiPhysicalDisk
{
    <#
            .SYNOPSIS
            UUID is naa address for the LUN.

            .DESCRIPTION
            This script detachs the selected LUN from all connected hosts.
     
            .EXAMPLE
            Detach-ESXiPhysicalDisk -UUID 'naa.xxxxxxxxxxxxxxxxxxxxx'
            Detaches 'naa.xxxxxxxxxxxxxxxxxxxxx' from all conneted ESXi hosts

            Detach-ESXiPhysicalDisk -UUID 'naa.xxxxxxxxxxxxxxxxxxxxx' -confirm
            Detaches 'naa.xxxxxxxxxxxxxxxxxxxxx' from all conneted ESXi hosts with Confirmation

            Detach-ESXiPhysicalDisk -UUID 'naa.xxxxxxxxxxxxxxxxxxxxx' -WhatIf
            will run  Detach-ESXiPhysicalDisk -UUID 'naa.xxxxxxxxxxxxxxxxxxxxx' command in its entirety without executing the detach action.

            .NOTES
            Author: Hany Hammad <hany.hammad@yahoo.com>

            This script is provided "AS IS" with no warranty expressed or implied. Run at your own risk.
    
            .LINK
            https://github.com/HanyHammad/PublicScripts/
            
    #>
    [cmdletbinding(SupportsShouldProcess)]
    param 
    (
        [Parameter(Mandatory = $true)]
        [String]$UUID   # UUID is naa address for the LUN.
    )
        $ErrorActionPreference="SilentlyContinue"
        $UUID = $UUID.Trim()        #Removes extra white spaces
        $hosts=$Global:DefaultVIServers|Where-Object {$_.productline -eq "embeddedEsx"} #Gets list of already connected ESXi Hosts
        if($hosts)
        {             
            foreach ($hst in $hosts)
            {
                $esxcli=Get-EsxCli -Server (Get-VIServer $hst -Session $hst.sessionid) -V2
                $DiskParams = $esxcli.storage.core.device.list.CreateArgs()
                $DiskParams.device=$UUID
                $DiskParams.excludeoffline=$false
                try 
                {
                    $Disk=$esxcli.storage.core.device.list.invoke($DiskParams)
                }
                catch 
                {
                    Write-Host "$UUID is not Found on $($hst.name)" -ForegroundColor Red
                    Continue    # Process next host in the hosts list
                } 
                if ($Disk.status -eq "on")
                {                     
                    if ($PSCmdlet.ShouldProcess("$($Disk.device)" , "Detach from $($hst.name)"))
                    {
                        $Detach=$esxcli.storage.core.device.set.CreateArgs()
                        $Detach.state="off"
                        $Detach.device=$Disk.device
                        try
                        {
                            $esxcli.storage.core.device.set.invoke($Detach)
                        }
                        catch 
                        {
                            Write-Host "Can not detach "$Disk.device" from Host"$hst.name"" -ForegroundColor Red
                        }
                            Write-Host "$($Disk.device) is Successfully Detached from Host $($hst.name)" -ForegroundColor Green
                        } 
                    }                      
                else 
                {
                    Write-Host "$UUID is already Offline on $($hst.name)" -ForegroundColor White
                }       
            } 
        }
}
function Connect-vCenter
{
    [cmdletBinding()]
   param 
        (
            [bool]$includeESXi,
            [Parameter(Mandatory=$true)]
            [string]$ComputerName
        )
    $vCCred=Get-Credential -Message "vCenter Credentials" 
    try {
        Connect-VIServer $ComputerName -Credential $vCCred
    }
    catch 
    {
        throw "Cloud not Connect to $ComputerName Error:$($Error[0].Exception)"
    }
    if($includeESXi)
    {
        $esxcred=Get-Credential -Message "ESXi login"
        $cluster=Get-Cluster
        $hosts=Get-VMHost -Location $cluster.name
        $vihosts = foreach ($hst in $hosts){Get-VIServer $hst -Credential $esxcred }
        foreach ($vhst in $vihosts)
        {
            try 
            {
                Connect-VIServer $vhst -Credential $esxcred
            }
            catch
            {
                Write-Host "Cloud not Connect to $vhst Error:$($Error[0].Exception)"
                Continue
            }              
        }    
    } 
}
Connect-vCenter -includeESXi $true
$Luns=Get-Content "$env:USERPROFILE\documents\DetachLuns.txt"
$Luns | % {Detach-ESXiPhysicalDisk -UUID $_ -Confirm}