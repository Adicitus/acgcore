. "$PSScriptRoot\ShoutOut.ps1"
. "$PSScriptRoot\Run-Operation.ps1"
. "$PSScriptRoot\Unpack-RARFile.ps1"


# Unpacks a MOCSetup-style Archive disk (Cluster Pod).
function Unpack-ArchiveDisk($File){
    
    if ( !(Get-Module Hyper-V -ListAvailable )) {
        ShoutOut "Unable to unpack, no 'Hyper-V' module available (unpacking relies on VHD cmdlets)!" Yellow
        return
    } 

    shoutOut "Unpacking '$($File.FullName)'..." Cyan
    $vhd = Mount-DiskImage -ImagePath $file.fullname -PassThru | Get-DiskImage
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