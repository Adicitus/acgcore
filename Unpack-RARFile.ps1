. "$PSScriptRoot\Run-Operation.ps1"

function Unpack-RARFile{
    param(
		[parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="FileInfo", position=1)][System.IO.FileInfo]$File,
		[parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="String", position=1)][String]$Path,
		[parameter(Mandatory=$false, position=2)] $Destination=$null,
		[parameter(Mandatory=$false, position=3)] $UnrarPath="$PSScriptRoot\bin\RAR\UnRAR.exe"
	)
	
	if ($Path) {
        $File = Get-Item $Path
    }
    
    shoutOut "Looking to unpack '$($File.FullName)'..." Cyan
    
    shoutOut "Checking for an archive comment..." Cyan -NoNewline
    $comment = & $UnRARPath v "$($File.FullName)"
    
    if (!$Destination) {
        $path = $comment -match '^\s*Path\s*=' -replace '^\s*Path\s*=\s*|\\$',''
        $path = $path  -replace '^[a-z]:','C:' # MOCSetup compatibility, should probably be a setting.

        if  (!$path){
            shoutOut "Didn't find a 'Path' directive in the comment, falling back on 'C:\'" Yellow
            $path = "C:"
        } else {
            shoutOut "Found a 'Path' directive, using '$Path'" Green
        }
        $Destination = $path -replace "[\\/]$",""
    } else {
        $Destination = $Destination -replace "[\\/]$",""
    }

    shoutOut "Extracting '$($File.FullName)' --> '$Destination\'"
    { & $UnRARPath x -c- -y -o+  "$($File.FullName)" "$Destination\"  } | Run-Operation | Out-Null
    shoutOut "Done!"
}