. "$PSScriptRoot\Find-VolumePath.ps1"

<#

.SYNOPSIS
Creates a VHD used as a pod for the Caffeine delivery system.

.DESCRIPTION
This is a basic function used by the Create-HiveVHD and Create-ArchivesVHD functions.

#>
function Create-PodVHD {
    param(
        $FileName,
        $Label,
        $DestinationDir="C:\",
        $MaxSize=128GB,
        [Switch]$NonDeduplicated,
        [Switch]$Fixed
    )

    if ($DestinationDir -notmatch "[\\/]$") {
        $DestinationDir += "\"
    }

    if ( !(Test-Path $DestinationDir) ) {
        mkdir $DestinationDir | Out-Null
    }

    $params = @{
        Path="$DestinationDir$FileName"
        SizeBytes=$MaxSize
    }

    if ($Fixed) {
        $params.Fixed = $true
    } else {
        $params.Dynamic = $true
    }

    Write-Host "Creating VHD... " -NoNewline
    $vhd = New-VHD @params
    Write-Host "Done!" -ForegroundColor Green

    Write-Host "Formatting VHD... " -NoNewline
    $vhd = $vhd | Mount-VHD -Passthru

    $disk = $vhd | Get-Disk

    $disk | Initialize-Disk -PartitionStyle MBR

    $partition = $disk | New-Partition -UseMaximumSize -MbrType IFS

    $volume = $partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel $Label -Force -Confirm:$false
    Write-Host "Done!" -ForegroundColor Green

    Write-Host "Assigning driveletter... " -NoNewline
    $dlcs = "DEFGHIJKLMNOPQRSTUVWXYZ"
    Get-Volume | ? { $_.DriveLetter } | % {
        $dlcs = $dlcs -replace $_.DriveLetter,""
    }
    $driveLetter = $dlcs[0]

    $id =   if ($volume.UniqueID) {
                $volume.UniqueID # >= Win10/WS2016
            } else {
                $volume.ObjectID # <= Win8.1/WS2012R2
            }

    $idRegex = $id -replace "\\","\\"
    $w32_volume = gwmi "Win32_Volume where DeviceID='$idRegex'"
    
    Write-Host "($driveLetter)" -NoNewline

    $w32_volume.DriveLetter = "$driveLetter`:"
    $w32_volume.Put() | Out-Null
    Write-Host "Done! ($driveLetter)" -ForegroundColor Green

    if (!$NonDeduplicated) {
        Write-Host "Setting deduplication on the VHD volume... " -NoNewline
        if ( (Get-Module -Name Deduplication -ea SilentlyContinue -ListAvailable) ) {
            Import-Module Deduplication
            $volume | Enable-DedupVolume -UsageType HyperV | Out-Null
            Write-Host "Done!" -ForegroundColor Green
        } else {
            Write-Host "Deduplication feature not installed!" -ForegroundColor Red
        }
    }
    
    Write-host "Adding source system information (source.info)... " -NoNewline
    $path = Find-VolumePath $volume
    $sysinfopath = "$path\source.info"

    "Source system:" >> $sysinfopath
    systeminfo | % { " $_" } >> $sysinfopath
    Write-Host "Done!" -ForegroundColor Green

    Write-host "Hiding source.info... "-NoNewline
    Get-Item $sysinfopath | Set-ItemProperty -Name Attributes -Value ([System.IO.FileAttributes]::Hidden)
    Write-Host "Done!" -ForegroundColor Green

    try {
        Write-Host "Setting access rights for the volume... " -NoNewline
        $acl = Get-Acl $Path
        $ar = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "Allow")
        $acl.SetAccessRule($ar)
        Set-Acl $path $acl
        Write-Host "Done!" -ForegroundColor Green
    } catch {
        Write-Host "Failed!" -ForegroundColor Red
        Write-Host $_
    }



    return $vhd
}