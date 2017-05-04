# BuildSetupInventory.ps1

# Inventory the deployment files and verify that they exist.
function Build-JobInventory(){
	param(
		[parameter(Mandatory=$true)]  [hashtable] $Config,
		[parameter(Mandatory=$false)] [Switch] $Silent,
        [parameter(Mandatory=$false)] [String] $DestinationDir
	)
	
	$defaultTargetDir = $DestinationDir
	if ($config.Deploy.Destination) {
		$defaultTargetDir = $config.Deploy.Destination
	}

	ShoutOut "Time to inventory the files..."
	$inventory = @{}
	$fileRegex = "^\s*(?<SourcePath>(((?<driveLetter>[A-Z]):|\.)[\\/])?([^\\/]+[\\/])*(?<filename>[^\\/.]+\.(?<extension>[a-z0-9.]+)))(;(?<TargetPath>.*))?\s*$" # Verify this
    $folderRegex = "^\s*(?<SourcePath>.+\\(?<filename>[^.]+\.(?<extension>[a-z0-9.]+)))(;(?<TargetPath>.*))?\s*$"
	foreach($file in ($config.Deploy.file + $config.Deploy.unicast | ? { $_ -ne $null })) {
		AddTo-JobInventory $inventory $file $defaultTargetDir
<#
        ShoutOut "Checking '$file'..." -Quiet:$Silent
		if ($file -match $fileRegex) {
			shoutOut "The filename matches the expected format for a file!" green -Quiet:$Silent
			$filename = $matches.filename
			$inventory[$filename] = @{  }
			$targetDir = $defaultTargetDir
			if ($matches.TargetPath){
				$targetDir = $Matches.TargetPath
			}
			$inventory[$filename].filename = $filename
			$inventory[$filename].extension = $matches.extension
			$inventory[$filename].TargetPath = $targetDir.trimEnd('\/')
			$inventory[$filename].FullPath = "$($inventory[$filename].TargetPath)\$filename"
			$inventory[$filename].Exists = Test-Path $inventory[$filename].FullPath

			if ($inventory[$filename].Exists) {
				shoutOut "'$filename' is where we expected it to be!" Green -Quiet:$Silent
			} else {
				ShoutOut "A file is missing: '$filename' (Should be located at '$($inventory[$filename].FullPath)')" Red -Quiet:$Silent
			}

		}
#>
	}
	
	return $inventory
}

function AddTo-JobInventory() {
    param(
        [parameter(Mandatory=$true, position=1)] [Hashtable] $Inventory,
        [parameter(Mandatory=$true, position=2)] [string]    $Path,
        [parameter(Mandatory=$true, position=3)] [String]    $DefaultTargetDir
    )

    $fileRegex = "^\s*(?<SourcePath>(((?<driveLetter>[A-Z]):|\.)[\\/])?([^\\/]+[\\/])*(?<filename>[^\\/.]+\.(?<extension>[a-z0-9.]+)))(;(?<TargetPath>.*))?\s*$" # Verify this
    $folderRegex = "^\s*(?<SourcePath>.+\\(?<filename>[^.]+\.(?<extension>[a-z0-9.]+)))(;(?<TargetPath>.*))?\s*$"

    ShoutOut "Checking '$Path'..." -Quiet:$Silent
	if ($Path -match $fileRegex) {
		shoutOut "The filename matches the expected format for a file!" green -Quiet:$Silent
		$filename = $matches.filename
		$Inventory[$filename] = @{  }
		$targetDir = $defaultTargetDir
		if ($matches.TargetPath){
			$targetDir = $Matches.TargetPath
		}
		$Inventory[$filename].filename = $filename
		$Inventory[$filename].extension = $matches.extension
		$Inventory[$filename].TargetPath = $targetDir.trimEnd('\/')
		$Inventory[$filename].FullPath = "$($Inventory[$filename].TargetPath)\$filename"
		$Inventory[$filename].Exists = Test-Path $Inventory[$filename].FullPath

		if ($Inventory[$filename].Exists) {
			shoutOut "'$filename' is where we expected it to be!" Green -Quiet:$Silent
		} else {
			ShoutOut "A file is missing: '$filename' (Should be located at '$($Inventory[$filename].FullPath)')" Red -Quiet:$Silent
		}

	}

}