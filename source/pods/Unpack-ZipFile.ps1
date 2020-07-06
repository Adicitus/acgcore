function Unpack-ZipFile{
    [CmdletBinding()]
    param(
		[parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="FileInfo", position=1)][System.IO.FileInfo]$File,
		[parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="String", position=1)][String]$Path,
		[parameter(Mandatory=$false, position=2)] $Destination=$null
    )

    $Path = switch ($PSCmdlet.ParameterSetName) {
        	"FileInfo" {
                $File.FullName
            }

            "String" {
                Resolve-Path $Path
            }
    }
    
    $ini = @{}
    $iniPath = "{0}.ini" -f $Path

    if (Test-Path $iniPath -PathType Leaf) {
        $ini = Parse-ConfigFile $iniPath
    }

    if (!$PSBoundParameters.ContainsKey("Destination")) {
        $Destination = if (($c = $ini."Unpack-ZipFile") -and ($d = $c.Destination)) {
            $d
        } else {
            "C:\"
        }
    }
    
    if (!(Test-Path $Destination)) {
        mkdir $Destination
    }
    
    $Destination = Resolve-Path $Destination

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $Destination)

}