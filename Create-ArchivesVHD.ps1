. "$PSScriptRoot\Create-PodVHD.ps1"

function Create-ArchivesVHD {
    param(
        $PackageName,
        $Label=$PackageName,
        $DestinationDir="C:\",
        $MaxSize=128GB,
        [Switch]$Deduplicated,
        [Switch]$Fixed
    )

    $params = @{
        PodPath="$DestinationDir$PackageName.archives.vhdx"
        Label=$Label
        DestinationDir=$DestinationDir
        MAxSize=$MaxSize
    }

    if ( !($PSBoundParameters.ContainsKey("Deduplicated")) ) {
        $params.NonDeduplicated = $true
    }
    if ($PSBoundParameters.ContainsKey("Fixed")) {
        $params.Fixed = $true
    }

    $vhd = Create-PodVHD @params
    
    $path = $vhd | Get-Disk | Get-Partition | Get-Volume | Find-VolumePath
    
    return $vhd
}