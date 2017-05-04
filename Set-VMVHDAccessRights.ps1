# Set-VMVHDAccessRights.ps1

. "$PSScriptRoot\ShoutOut.ps1"

# Set access rights for all VHDs on the VMs with names like the give pattern.
function Set-VMVHDAccessRights {
    param(
        [parameter(Mandatory=$false, position=1)][String] $VMNamePattern = "*",
        [parameter(Mandatory=$false, position=2)][String] $Object = "Everyone",
        [parameter(Mandatory=$false, position=3)][String] $AccessType = "FullControl",
        [parameter(Mandatory=$false, position=4)][String] $Rule = "Allow"
    )

    shoutOut "Getting Virtual Machines..." 
    $vms = Get-VM | ? { $_.VMName -like $VMNamePattern }
    foreach($vm in $vms) {
        shoutOut "Fixing permissions for " -NoNewline
        shoutOut "'$($vm.VMName)'" Cyan -NoNewline
        shoutOut "..."
        shoutOut "Getting VHDs..."
        $vhds = Get-VMHardDiskDrive -VMName $vm.VMName | % { Get-VHD $_.Path }
        foreach ($vhd in $vhds) {
            Set-VHDAccessRights $vhd $Object $AccessType $Rule
        }
    }
}

# Set access rights for a single VHD
function Set-VHDAccessRights{
    param(
        [parameter(Mandatory=$true, position=1)][Microsoft.Vhd.PowerShell.VirtualHardDisk] $VHD,
        [parameter(Mandatory=$false, position=2)][String] $Object = "Everyone",
        [parameter(Mandatory=$false, position=3)][String] $AccessType = "FullControl",
        [parameter(Mandatory=$false, position=4)][String] $Rule = "Allow",
        [parameter(Mandatory=$false)][Switch] $NoRecurse
    )

    shoutOut "Setting access rule on:"
    shoutOUt "`t'$($VHD.Path)'" Cyan
    shoutOut "Setting '$AccessType' to '$Rule' for '$Object'..." -NoNewline
    try {
        $acl = Get-Acl $VHD.Path
        $ar = New-Object System.Security.AccessControl.FileSystemAccessRule($Object, $AccessType, $Rule)
        $acl.SetAccessRule($ar)
        Set-Acl $VHD.Path $acl
        shoutOut "Done!" Green
    } catch {
        shoutOut "Failed!" Red
        shoutOut $_
    }

    if ($VHD.ParentPath -and !$NoRecurse) {
        if (Test-Path $VHD.ParentPath) {
            shoutOut "Changing permissions for parent..."
            $parentVHD = Get-VHD $VHD.ParentPath
            Set-VHDAccessRights $parentVHD $Object $AccessType $Rule
        } else {
            shoutOut "A parent disk is missing!" Red
            shoutOut "Missing "
            shoutOut "`t'$($VHD.ParentPath)'" Red
            shoutOut " which is the parent of "
            shoutOut "`t'$($VHD.Path)'" Yellow
        } 
    }
}