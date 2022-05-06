# Uninstall-HiveDisk.ps1

function Uninstall-HiveDisk {
    param(
        [parameter(ValueFromPipeline=$true, Position=1)][System.IO.FileInfo]$File
    )

    if ( !(Get-Module Hyper-V -ListAvailable )) {
        ShoutOut "Unable to install, no 'Hyper-V' module available (install relies on VHD cmdlets)!" Yellow
        return
    } 

    $podPath = $File.FullName

    $image = { $podPath | Get-VHD } | Run-Operation
    if (!$image -or $image -is [System.Management.Automation.ErrorRecord]) {
        shoutOut "Could not open '$podPath' as a VHD!" Error
        return
    }

    if ($image.Attached) {
        shoutOut "Dismounting '$podPath'" Cyan
        $image | Dismount-VHD
        $image = $image | Get-VHD
    }
}