. "$PSScriptRoot\ShoutOut.ps1"
. "$PSScriptRoot\Run-Operation.ps1"
. "$PSScriptRoot\Find-VolumePath.ps1"
. "$PSScriptRoot\Unpack-RARFile.ps1"


# Unpacks a MOCSetup-style Archive disk (Cluster Pod).
function Unpack-ArchiveDisk {
    
    param([parameter(ValueFromPipeline=$true)][System.IO.FileInfo]$File)

    shoutOut "Unpacking '$($File.FullName)'..." Cyan
    Mount-DiskImage -ImagePath $file.fullname
    $vhd = Get-DiskImage -ImagePath $File.FullName
	$partitions = Get-Partition -DiskNumber $vhd.Number
    
    $partitions | % {
        shoutOut "looking at partition #$($_.PartitionNumber)... " Cyan
        $sfxPath = $_ | Get-Volume | Find-VolumePath
        if (!$sfxPath) {
            shoutOut "No Mount Point found for this partition, skipping!"
            return
        }

        if (!($sfxPath = $sfxPath | ? { Test-Path $_ } | Select -First 1)) {
            Write-Host "For some reason the assigned access paths have become invalid, generate a new one..." -ForegroundColor Yellow
            $tmpDir = "C:\temp\{0:x}" -f [datetime]::Now.Ticks
            mkdir $tmpDir | Out-Null
            $_ | Add-PartitionAccessPath -AccessPath $tmpDir
            $sfxPath = $tmpDir
            Write-Host "Added '$tmpDir'!" -ForegroundColor Green
        }
    
	    $SfxFiles = Get-ChildItem -Path $SfxPath -Filter *.exe
    
	    foreach ($sfx in $SfxFiles)
	    {
            Unpack-RARFile $sfx
	    }
        
        if ($tmpDir) {
            Write-Host "Cleaning up temporary access path..." -ForegroundColor Cyan -NoNewline
            $_ | Remove-PartitionAccessPath -AccessPath $tmpDir
            Remove-Item $tmpDir -Recurse -Force
            Write-Host "Done!" -ForegroundColor Green
        }
    }
	$vhd | Dismount-DiskImage
}