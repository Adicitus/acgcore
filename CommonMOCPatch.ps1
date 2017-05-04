# CommonMOCPatch.ps

param(
    [Switch]$Import
)

function Patch-CommonMOCErrors {
    param(
        [Parameter(Mandatory=$false)][String]$VMDir = 'C:\Program Files\Microsoft Learning\',
        [Parameter(Mandatory=$false)][Array]$SwitchDefs = @(),
        [Parameter(Mandatory=$false)][String]$CheckpointName="Initial Snapshot"
    )

    . "$PSScriptRoot\ShoutOut.ps1"
    . "$PSScriptRoot\RegexPatterns.ps1"
    . "$PSScriptRoot\Rebase-VHDFiles.ps1" -Import

    if (!(Test-Path $vmDir -PathType Container)) {
        shoutOut "Cannot find the VM directory: "  Red -NoNewline
        shoutOut "'$vmDir'"
        pause
        Exit
    } else {
        shoutOut "Found the VM directory: "  Green -NoNewline
        shoutOut "'$vmDir'"
    }

    shoutOut "Checking that all switches exist..."
    foreach($switchDef in $switchDefs){
        shoutOut "Switch '$($switchDef.Name)' exists?..." -NoNewline
        if ($switch = Get-VMSwitch | ? { $_.Name -eq "$($switchDef.Name)" }) {
            shoutOut "Yes!"  Green
            if ($switch -is [Array]) { 
                shoutOut "There is more than 1 switch with the same name ($($switchDef.Name))!"  Red
                shoutOut "This should not be happening, I don't know how to handle this. Quitting"
                return
            }
            $s = $switch # Switch statements have an automatic variable called $switch, so we use a temporary variable.
            shoutOut "Is it the right type ($($switchDef.Type))..." -NoNewline 
            switch($switchDef.Type) {
                "NAT" {
                    shoutOut "Sorry, I can't handle 'NAT' switches yet..."  Red
                    <#
                    shoutOut "It's supposed to be an Internal switch..." -NoNewline 
                    if ($s.SwitchType -ne "Internal") {
                        shoutOut "It's Not!"  Red
                        shoutOut "It is '$($s.SwitchType)', attempting to correct it... " -NoNewline
                        try {
                            Set-VMSwitch -Name $switchDef.Name -SwitchType "Internal" -ErrorAction Stop
                            shoutOut "Done!"  Green
                        } catch {
                            shoutOut "Failed!"
                            shoutOut "I couldn't change the Switch type on '$($s.Name)', trying to do so generated an exception."  Red
                            $_
                            pause
                            exit
                        }
                    } else {
                        shoutOut "It is!" -Foreground-Color Green
                    }
                    shoutOut "Do I have the right data to set this up?"
                    if (!$switchDef.IP) {
                        
                    }
                    if (!( $SwitchDef.PrefixLength -or $SwitchDef.Netmask )) {
                        
                    }
                    #>
                }
                External {
                    if ($s.SwitchType -eq "External ") {
                        shoutOut "Yes!" Green
                        break
                    }
                    shoutOut "No!" Red
                    $adapter = Get-NetAdapter -Physical | Select -First 1 | % { $_.InterfaceAlias }
                    if (!$adapter) {
                        shoutOut "No physical network adapter found! I won't change the type of '$($switchDef.Name)'..." -ForegroundColor Red
                    } else {
                        shoutOut "Using the 1st available netadapter..."
                        try {
                            Set-VMSwitch -Name $switchDef.Name -NetAdapterName $adapter -ErrorAction Stop
                        } catch {
                            shoutOut "Unable to set '$($SwitchDef.name)' to external using '$($adapter)' as the network adapter."
                        }
                    }
                }
                default {
                    if ($s.SwitchType -ne $switchDef.Type) {
                        shoutOut "No!"  Red
                        shoutOut "It is  '$($s.SwitchType)', I'm setting it to '$($switchDef.Type)'"
                        Set-VMSwitch -Name $switchDef.Name -SwitchType $switchDef.Type
                    } else {
                        shoutOut "Yes"  Green
                    }
                }
            }
        } else {
            shoutOut "No!"  Red
            shoutOut "Attempting to create it..."
            try {
                New-VMSwitch -Name $switchDef.Name -SwitchType $switchDef.Type -ErrorAction Stop | Out-Null
            } catch {
                shoutOut "Exception Caught!"  Green
            }
        }
    }

    shoutOut "Identifying the VM Configuration files..." -NoNewline
    $vmFiles = gci -Recurse "$vmDir" | ? { $_.FullName -match '^([A-Z]:|\.)[\\/]([^\\/]+[\\/])*Virtual Machines[\\/].*\.(xml|exp)$' }
    if (!$vmFiles) {
        shoutOut "No WM Configuration files found! "  Yellow
        shoutOut "Did you move them on import?"
    } else {
        shoutOut "Found $($vmFiles.Count)"  Green
    }
    shoutOut "Getting existing VMs..." -NoNewline
    $vms = Get-VM
    if (!$vms) {
        shoutOut "No VMs have been imported so far..."  Yellow
    } else {
        shoutOut "Found $($vms.Count)"  Green
    }
    if (!$vmFiles -and !$vms) {
        shoutOut "No VMs found! "  Red -NoNewline
        shoutOut "Have they been extracted?"
        shoutOut "Check the 'C:\Setup' directory."
    
        pause
        exit
    }

    shoutOut "Making sure all VHDs have their parents..."
    Rebase-VHDFiles

    foreach($vmFile in $vmFiles) {
        $imported = $false
        foreach($vm in $vms) {
            if (cat $vmFile.FullName | Select-String "$($vm.Name)") {
                $imported = $true
                break
            }
        }
        shoutOut "'$($vmfile.FullName)' " -NoNewline
        if (!$imported) {
            shoutOut "Is not imported! (Probably)"  Red
            shoutOut "Importing...." -NoNewline
            try {
                $new_vm = Import-VM -Path $vmFile.FullName -Register -ErrorAction Stop
                shoutOut "Imported as  '$($new_vm.VMName)'"  Green
            } catch {
                shoutOut "And exeption occurred!"  Red
                switch -Regex ($_.ToString()) {
                    ".*Failed to access disk '(?<filepath>((?<driveLetter>[A-Z]):|\.)[\\/]([^\\/]+[\\/])*(?<filename>.*))':.*" {
                        shoutOut "Failed to find '$($Matches.filepath)'..."  Red
                        shoutOut "This is probably the VM's disk or a member of that disk's chain. Maybe a Basedrive?`n"
                    }
                    ".*Please use Compare-VM.*" {
                        shoutOut "The machine is not compatible with this Host, for the following reasons: "  Red
                        $compatibilityReport = Compare-VM -Path $vmFile
                        $compatibilityReport.Incompatibilities | % { shoutOut "+ $($_.Message)"}
                        shoutOut ""
                    }
                    ".*Identifier Already Exists.*"{
                        shoutOut "There's already a VM with the same identifier as the one you are trying to import."  Red -NoNewline
                        $logical_id = cat $vmFile.FullName | ? {$_ -match '^\s*\<Logical_id\s* type="string">(?<logical_id>.*)\</Logical_id\>\s*$'} | % { $Matches.logical_id }
                        shoutOut " ($logical_id)"
                        shoutOut "This probably means we trying to import, or have already imported, a Snapshot..."

                    }
                    ".*Virtual hard disk in the chain of differencing disks, '$($RegexPatterns.File)'.*" {
                        shoutOut "A Mid or Base VHD is missing:"  Red
                        shoutOut "`t'$($Matches.File)'"
                    }
                    default {
                        shoutOut "An unknown error occurred while trying to import..."
                        shoutOut $_
                        throw $_
                    }
                }
            }
        } else {
            shoutOut "Is already imported! (Probably)"  Green
        }
    }

    $vms = Get-VM
    $cpName = $CheckpointName
    shoutOut "Checking if the VMs have an initial snapshot..."
    foreach ($vm in $vms){
        if (!(Get-VMSnapshot -VMName $vm.VMName)) {
            shoutOut "$($vm.VMName) doesn't have any snapshots... "  RED -NoNewline
            shoutOut "Creatin' '$cpName'"
            Checkpoint-VM -VMName $vm.VMName -SnapshotName "$cpName"
        } else {
            shoutOut "$($vm.VMName) has snapshots already, I'm not touching it."  Green
        }
    }
}

if (!$Import) {
    Patch-CommonMOCErrors
}