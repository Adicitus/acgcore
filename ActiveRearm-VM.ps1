
. "$PSScriptRoot\Run-Operation.ps1"

# ! NOTE: This function needs to be carefully maintained, it should only return $true or $false. ! #
function ActiveRearm-VM {
    param(
        $vm,
        $credentials,
        $RearmScriptFile = "$PSScriptRoot\Snippets\Rearm.ps1"
    )

    trap {
        shoutOut $_
    }

    shoutOut ("Attempting Active Rearm: $($vm.VMName) ".PadRight(80,'=')) Magenta

    $cleanupClosure = { # Performing cleanup in a separate step so that we don't need to replicate the code in the main step.
        param($vm)
        shoutOut "Shutting down '$($vm.VMName)'..." Cyan -NoNewline
        try {
            $vm | Stop-VM -Force
            shoutOut "Done!" Green 
        } catch {
            shoutOut "Failed!" Red
            shoutOUt $_ Red
        }
    }
        
    shoutOut "Starting '$($vm.VMName)'..." Cyan

    $r = { $vm | Start-VM } | Run-Operation
    if ($r -is [System.Management.Automation.ErrorRecord]) {
        shoutOut "Unable to start $($vm.VMName)!" Red
        . $cleanupClosure $vm
        return
    }

    $waitTimeout = 300000 #(5min)
    $waitStart = Get-Date

    ###########################################################################
    #== Start: Waiting for VMs to initialize =================================#
    ###########################################################################

    # Wait for the VM to start...
    $vm = $vm | Get-VM
    while ($vm.Heartbeat -notlike "OK*") {
        Start-Sleep -Milliseconds 20
        $timeWaited = ((Get-Date) - $waitStart).TotalMilliseconds
        if ( $timeWaited -ge $waitTimeout ) {
            shoutOut "$($vm.VMName) timed out while waiting for heartbeat... (waited ${timeWaited}ms, $($_.Heartbeat))" Red
            $vm | Stop-Vm -TurnOff -Force # Shutdown integration service is not going to be available at this point.
            . $cleanupClosure $vm
            return $false
        }
        $vm = Get-VM -Name $vm.VMName
    }
    shoutout "$($vm.Heartbeat) (${timeWaited}ms)" Green
    $waitStart = Get-Date

    shoutOut "Waiting for network adapters to become active..." Cyan -NoNewline
    $netAdapterTimedout = $false
    $vmadapters = $vm | Get-VMNetworkAdapter
    while ( ($vmadapters | ? { !$_.IPAddresses }) -and !$netAdapterTimedout) {
        $timeWaited = ((Get-Date) - $waitStart).TotalMilliseconds
        if ( $timeWaited -ge $waitTimeout ) {
            shoutOut "$($_.VMName) timed out while waiting for network adapters.... (waited ${timeWaited}ms, $($_.Status))" Red
            $netAdapterTimedout = $true;
        }
        $vmadapters = $vm | Get-VMNetworkAdapter
    }

    if ( !$netAdapterTimedout ) {
        shoutOut "All adapter initialized! (waited ${timeWaited}ms, $($_.Status))" Green
    }
    
    ###########################################################################
    #== End: Waiting for VMs to initialize ===================================#
    ###########################################################################

    $successfulConnection = $false

    ###########################################################################
    #== Start: trying to connect using VMName ================================#
    ###########################################################################

    if (Get-Command "Invoke-Command" | ? { $_.Parameters.Keys.Contains("VMName") }) { # Newer versions of Windows allow WinRM connections via VMName, so this is our backup.
        shoutOut "Trying to connect using VM name..." Cyan
        $Credentials | % {
            if ($successfulConnection) { return }
            $credential = $_
            $r = { Invoke-Command -VMName $vm.VMName -Credential $_ -FilePath $RearmScriptFile } | Run-Operation 
            if ( ($r -is [System.Management.Automation.ErrorRecord]) ) {
                shoutOut "Unable to connect to '$($vm.VMname)' with credentials for '$($credential.Username)'" Red
            } else {
                shoutOut "Connected successfully using credentials for '$($credential.Username)'!" Green
                shoutOut $r Result
                $successfulConnection = $true
            }
        }
    } else {
        shoutOut "Unable to connect using VMName (Parameter 'VMName' is unavailable on Invoke-Comand)." Yellow
    }

    ###########################################################################
    #== End: Trying to connect using VMName ==================================#
    ###########################################################################

    
    if (!$successfulConnection) { # Fallback clause...
        shoutOut "Attempting to connect to '$($vm.VMName)' using IP..." Cyan

        #######################################################################
        #== Start: Attempt to connect using IP-address =======================#
        #######################################################################

        $ipaddresses = $vmadapters | % { $_.IPAddresses }
        shoutOut "Got the following IP addresses: $($ipaddresses -join ", ")"

        $activeAddresses = $ipaddresses | ? {
            shoutOut "Testing '$_'... " cyan -NoNewline
            # Some VMs don't seem to respond to the link-assigned address.
            # This may be because of a firewall configuration, or it might be a timing issue.
            # To lessen the probability of a timing miss, we rerun the test 3 times with a bit
            # of a delay in-between.
            for ($i = 1; $i -lt 4; $i++) {
                shoutOut "$i " -NoNewline
                $ping = Get-WmiObject -Query "Select * from Win32_PingStatus Where Address='$_'"
                if ($ping.StatusCode -eq 0) {
                    shoutOut "Contact!" Green 
                    return $true
                }
                sleep -Milliseconds 300
            }
            shoutOut "No contact!" Red
            $false
        }

        shoutOut "Active addresses: $($activeAddresses -join ", ")"

        $activeAddresses | % {
            if ($successfulConnection) { return }
            shoutOut "Attempting to connect using IP-Address ($_)..." Cyan
            $address = $_
            shoutOut "Connecting to '$address'..." Cyan
            $Credentials | % {
                if ($successfulConnection) { return }
                $credential = $_
                $session = $null
                try {
                    $session = New-PSSession -ComputerName $address -Credential $_ -ErrorAction Stop

                    shoutOut "Connected successfully using credentials for '$($credential.Username)'!" Green
                    $successfulConnection = $true
                } catch {
                    shoutOut "Unable to connect with credentials for '$($credential.Username)'!" Red
                    shoutOut "`t| $($_)" White
                }

                if ($session) {
                    shoutOut "Performing rearm..." Cyan
                    $r = { Invoke-Command -Session $session -FilePath $RearmScriptFile -ErrorAction stop } | Run-Operation
                    if($r -isnot [System.Management.Automation.ErrorRecord]) {
                        shoutOut "Finished running rearm snippet!" Green
                        shoutOut $r Result
                    } else {
                        shoutOut "Failed to run Rearm snippet!" Red
                    }
                }

                if ($session ) {
                    if ($session.State -in "Opened") {
                        $session | Disconnect-PSSession -Confirm:$false | Out-Null
                    }
                    $session | Remove-PSSession -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }

        #######################################################################
        #== End: Trying to connect using IP-address ==========================#
        #######################################################################
    }

    if (!$successfulConnection) {
        shoutOut "Active rearm failed on '$($vm.VMName)'!" Red
    }
    . $cleanupClosure $vm

    return $successfulConnection
}