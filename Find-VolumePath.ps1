# Retrieves any paths that lead to the given MSFT_Volume
function Find-VolumePath {
    param(
        [parameter(Position=1, ValueFromPipeline=$true)]$Volume,
        [parameter()][Switch]$FirstOnly
    )
    $paths = @()

    $Volume | % {
        if ($_.UniqueID) {
            $id = $_.UniqueID # WS2016+
        } else {
            $id = $_.ObjectID # WS2012R2
        }
    
        $id = $id -replace "\\","\\"
    
        $mountPoints = gwmi Win32_MountPoint | ?{ $_.Volume -eq "Win32_Volume.DeviceID=`"$($id)`"" }
        if (!$mountPoints) { return $null }

        $mountPoints | % {
            if ($_.Directory -match "^Win32_Directory.Name=`"(?<dir>.*)`"") {
                $dir = $Matches.Dir -replace "\\\\","\"
                if ($dir -notmatch "\\$") { $dir = "$dir\" }
                $paths += $dir
            } else {
                shoutOut "Unexpected volume mountpoint format: $($_.Directory)" Red
            }
        }
    }

    if ($FirstOnly) { return $paths | Select -First 1 }
    return $paths
}
