. "$PSScriptRoot\Find-VolumePath.ps1"

function Create-HiveVHD {
    param(
        $PackageName,
        $Label=$PackageName,
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
        Path="$DestinationDir$PackageName.hive.vhdx"
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

    $volume = $partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel $Label -Force
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
    
    $path = Find-VolumePath $volume
    
    Write-Host "Adding hive.ini... " -NoNewline
    $hiveConfig = New-Item "${path}hive.ini" -ItemType File
    $path = $hiveConfig.FullName
    $acl = Get-Acl $path
    $ar = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "Allow")
    $acl.SetAccessRule($ar)
    Set-Acl $path $acl
    Write-Host "Done!" -ForegroundColor Green
    Write-Host "Hiding hive.ini..." -NoNewline
    $hiveConfig | Set-ItemProperty -Name Attributes -Value ([System.IO.FileAttributes]::Hidden)
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