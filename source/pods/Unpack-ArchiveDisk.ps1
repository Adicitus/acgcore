# Unpacks a MOCSetup-style Archive disk (Cluster Pod).
# 
# !NOTE! This function requires the Hyper-V VHD cmdlts to function.
# It used rely on the DiskImage cmdlts, but since I have had access
# control issues when treating the VHDs as DiskImages.
function Unpack-ArchiveDisk {
    
    param([parameter(ValueFromPipeline=$true)][System.IO.FileInfo]$File)

    shoutOut "Unpacking '$($File.FullName)'..." Cyan
    Mount-VHD $file.fullname
    $vhd = Get-VHD $File.FullName
    $disk = $vhd | Get-Disk
	$partitions = $disk | Get-Partition
    
    $partitions | % {
        shoutOut "looking at partition #$($_.PartitionNumber)... " Cyan
        $sfxPath = $_ | Get-Volume | Find-VolumePath
        if (!$sfxPath) {
            shoutOut "No Mount Point found for this partition, skipping!"
            return
        }

        if (!($sfxPath = $sfxPath | ? { Test-Path $_ } | Select -First 1)) {
            shoutOut "For some reason the assigned access paths have become invalid, generate a new one..." -MsgType Warning
            $tmpDir = "C:\temp\{0:x}" -f [datetime]::Now.Ticks
            mkdir $tmpDir | Out-Null
            $_ | Add-PartitionAccessPath -AccessPath $tmpDir
            $sfxPath = $tmpDir
            shoutOut "Added '$tmpDir'!" -MsgType Success
        }
    
        $ini = @{}
        $iniFile = "{0}\archive.ini" -f $sfxPath
    
        if (Test-Path $iniFile -PathType Leaf) {
            "Found archive.ini ('{0}')." -f $iniFile | shoutOut
            $ini = Parse-ConfigFile $iniFile
        }
    
        $commonArgs = @{}
        
        if (($c = $ini."Unpack-ArchiveDisk") -and ($d = $c.Destination)) {
            $commonArgs.Destination = $d
            "Unpacking all archives to '{0}'." -f $commonArgs.Destination | shoutOut
        }
    
        $archiveFiles = Get-Childitem -Path $sfxPath -File
    
        foreach ($file in $archiveFiles) {
            if (($file.name -match "part(?<number>[0-9]+)\.[a-z0-9]+$") -and ($Matches.number -notmatch "^0*1$")) {
                continue
            }
        
            switch -Regex ($file.Name) {
                "\.(rar|exe)$" {
                    "Unpacking '{0}' as RAR file..." -f $file.FullName | shoutOut
                    $args = $commonArgs.clone()
                    $args.File = $file
                    Unpack-RARFile @args
                }
                
                "\.zip$" {
                    "Unpacking '{0}' as ZIP file..." -f $file.FullName | shoutOut
                    $args = $commonArgs.clone()
                    $args.File = $file
                    Unpack-ZipFile @args
                }
                
                default {
                    "Unable to identify type of archive: '{0}'" -f $file.FullName | shoutOut -MsgType Warning
                }
            }
        }
        
        if ($tmpDir) {
            shoutOut "Cleaning up temporary access path..." -NoNewline
            $_ | Remove-PartitionAccessPath -AccessPath $tmpDir
            Remove-Item $tmpDir -Recurse -Force
            shoutOut "Done!" -MsgType Success
        }
    }
	$vhd | Dismount-VHD
}