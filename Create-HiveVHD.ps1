. "$PSScriptRoot\Find-VolumePath.ps1"
. "$PSScriptRoot\Create-PodVHD.ps1"

function Create-HiveVHD {
    param(
        $PackageName,
        $Label=$PackageName,
        $DestinationDir="C:\",
        $MaxSize=128GB,
        [Switch]$NonDeduplicated,
        [Switch]$Fixed
    )

    $params = @{
        PodPath="$DestinationDir$PackageName.hive.vhdx"
        Label=$Label
        DestinationDir=$DestinationDir
        MAxSize=$MaxSize
    }

    if ($PSBoundParameters.ContainsKey("NonDeduplicated")) {
        $params.NonDeduplicated = $true
    }
    if ($PSBoundParameters.ContainsKey("Fixed")) {
        $params.Fixed = $true
    }

    $vhd = Create-PodVHD @params
    
    $path = $vhd | Get-Disk | Get-Partition | Get-Volume | Find-VolumePath

    
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


    return $vhd
}