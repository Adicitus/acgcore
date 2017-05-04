# Correct-DriveLetters.ps1

<#

.SYNOPSIS
    Changes the drive letter for the specified volume to the given drive letter.
.NOTES
    - Any volume already assigned the specified $TargetLetter will be moved to Z.
    - The ByDriveLetter switch causes the volume label to be treated like a drive
      letter instead of a colume label.
.WISHLIST
    - Offending volumes should be moved to the last available drive letter, rather
      than always being assigned Z, otherwise we will cause an error if more than
      one volume needs to be moved.
    - The parameters should be rewritten to use parameter sets to make it more legible,
      with a named parameter for CurrentLetter.
      
#>
param([Switch]$Import)

function Change-DriveLetter(){
    param(
        $volumeLabel = "VM",
        $TargetLetter = "D:",
        [Switch]$ByDriveLetter
    )

    if ($TargetLetter -notmatch ":$") { $TargetLetter += ":" }

    if ($ByDriveLetter) {
        if ($volumeLabel -notmatch ":$") { $volumeLabel += ":" }
        $vmsVolume = Get-WMIObject Win32_Volume -Filter "DriveLetter='$volumeLabel'"
    } else {
        $vmsVolume = Get-WMIObject Win32_Volume -Filter "Label='$volumeLabel'"
    }


    function Switch-Driveletter() {
        param(
            [parameter(mandatory=$true, position=1)][System.Management.ManagementObject] $Volume,
            [parameter(Mandatory=$true, position=2)][String] $DriveLetter
        )

        $Volume.DriveLetter = $DriveLetter
        $Volume.Put()
    }

    if ($vmsVolume.DriveLetter -eq $TargetLetter) {
        Write-Host "The '$volumeLabel' drive is mounted with the right driveletter ($($vmsVolume.DriveLetter))!" -ForegroundColor Green
    } else {
        Write-host "The '$volumeLabel' drive is mounted with the wrong driveletter ($($vmsVolume.DriveLetter))!" -ForegroundColor Red

        try {
            $offendingVolume = Get-WmiObject Win32_volume -Filter "DriveLetter='$TargetLetter'" -ErrorAction Stop
        } catch {
            write-host "Couldn't retrieve the volume with driveletter '$TargetLetter': " -ForegroundColor Cyan -NoNewline
            write-host $_
        }

        if (!$offendingVolume) {
            write-host "There's currently no drive @ '$TargetLetter'!" -ForegroundColor green
        } else {
            write-host "There's a drive @ '$TargetLetter'..." -ForegroundColor Red -NoNewline
            write-host "Moving the drive to 'Z:'... "
            try {
                Switch-Driveletter $offendingVolume "Z:"
                write-host "Done!" -ForegroundColor Green
            } catch {
                write-host "An exception occurred while trying to move the drive @ '$TargetLetter' to 'Z:'!" -ForegroundColor Red
                write-host $_
            }
        }

        try {
            write-host "Switching the driveletter of '$volumeLabel' to '$TargetLetter'... " -ForegroundColor Cyan -NoNewline
            Switch-Driveletter $vmsVolume $TargetLetter
            write-host "Done!" -ForegroundColor Green
        } catch {
            write-host "An exception occurred!" -ForegroundColor Red
            write-host $_
        }
    }
}

if (!$Import) { Change-VolumeDriveLetter }