. "$PSScriptRoot\ShoutOut.ps1"
. "$PSScriptRoot\Run-Operation.ps1"
. "$PSScriptRoot\Unpack-RARFile.ps1"


# Unpacks a MOCSetup-style Archive disk (Cluster Pod).
function Unpack-ArchiveDisk($File){
    
    shoutOut "Unpacking '$($File.FullName)'..." Cyan
    Mount-DiskImage -ImagePath $file.fullname
    $vhd = Get-DiskImage -ImagePath $File.FullName
	$partitions = Get-Partition -DiskNumber $vhd.Number
    
    $partitions | % {
        shoutOut "looking at partition #$($_.PartitionNumber)... " Cyan
        if ($_.DriveLetter -notmatch "^[A-Z]$") {
            shoutOut "No drive letter associated with the partition, skipping!"
            return
        }

	    $SfxPath = "$($_.driveletter):\"
    
	    $SfxFiles = Get-ChildItem -Path $SfxPath -Filter *.exe
    
	    foreach ($sfx in $SfxFiles)
	    {
            Unpack-RARFile $sfx
	    }
    }
	$vhd | Dismount-DiskImage
}