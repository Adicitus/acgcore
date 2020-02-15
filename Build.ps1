

# Build manifest
$manifestArgs = @{}
$buildArgs = @{}

Get-ChildItem "$PSScriptRoot\build.settings" -File | ForEach-Object {
    $name = $_.Name.split(".")[0]
    $buildArgs.$name = & $_.FullName
}

Get-ChildItem "$PSScriptRoot\build.settings\manifest" -File | ForEach-Object {
    $name = $_.Name.split(".")[0]
    $manifestArgs.$name = & $_.FullName
}

$moduleName = $buildArgs.modulename

$outDir = "$PSScriptRoot\out\$moduleName"
$assetsOutDir = "$outDir\.assets"
$srcDir = "$PSScriptRoot\source"

$moduleFile     = "{0}\{1}.psm1" -f $outDir, $moduleName
$manifestFile   = "{0}\{1}.psd1" -f $outDir, $moduleName

if (Test-Path $outDir) {
    Remove-Item $outDir -Force -Recurse
}

$null = New-Item $outDir -ItemType Directory

# Build Script module
Get-ChildItem $srcDir -Directory | ForEach-Object {
    $item = $_
    $subName = $_.Name
    
    "# {0}.{1}" -f $moduleName, $subName >> $moduleFile

    if ($assetsDir = Get-ChildItem $item.FullName -Filter ".assets" -Directory) {
        if ( !(Test-Path $assetsOutDir) ) {
            mkdir $assetsOutDir
        }

        $assetsDir | Get-ChildItem | ForEach-Object {
            Copy-Item $_.FullName -Destination "$assetsOutDir\" -Recurse 
        }
    }

    Get-ChildItem $item.FullName -Filter *.ps1 | ForEach-Object {
        Get-Content $_.FullName >> $moduleFile
    }
}

New-ModuleManifest -Path $manifestFile @manifestArgs

$manifest = Get-Content $manifestFile

# Trim the manifest
Remove-Item $manifestFile

$manifest | Where-Object {
    $_ -notmatch "^\s*$"
} | Where-Object {
    $_ -notmatch "^\s*\#"
} | ForEach-Object {
    $_ -replace "\#.*$", "" >> $manifestFile
}