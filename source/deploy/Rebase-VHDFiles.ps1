
function Rebase-VHDFiles() {
    
    param(
        [parameter(Mandatory=$false, Position=1)] [string[]] $VHDFolder = 'C:\Program Files\Microsoft Learning',
        [parameter(Mandatory=$false, Position=2)] [string[]] $ExcludePaths = @()
    )

    $vhdFiles = $VHDFolder | ls -Recurse | ? { $_ -match '.*\.(a)?vhd(x)?' }
    $vhdFiles = $vhdFiles | ? { $p = $_.FullName; -not ($ExcludePaths | ? { $p -like $_ }) }
    shoutOut "Found the following VHDs:"
    $vhdFiles | % FullName | % { shoutOut " | $_" }
    $vhds = $vhdFiles | % { Get-VHD -Path $_.FullName }

    $vhdMap = @{ }

    foreach($vhd in $vhds) {
        if ($vhd.Path -match $Script:RegexPatterns.File) {
            $vhdMap[$matches.filename] = $vhd
        } else {
            shoutOut "Couldn't interpret a VHD path: " Red -NoNewline
            shoutOut "'$($vhd.Path)'" 
        }
    }
 

    foreach ($vhd in $vhds) {
        shoutOut "$($vhd.Path): " -NoNewline
        if (!$vhd.ParentPath) {
            shoutOut "is a base disk!" green
            continue
        }
        if (Test-Path $vhd.ParentPath) {
            shoutOut "Has it's parent disk!" Green
            continue
        }

        if (!($vhd.ParentPath -match $Script:RegexPatterns.File)) {
            shoutOut "Could not interpret ParentPath: " Red -NoNewline
            shoutOut "'$($vhd.ParentPath)'"
            continue
        }
        if ($vhdMap.ContainsKey($Matches.filename)) {
            $parent = $vhdMap[$Matches.filename]
            shoutOut "Found missing parent disk (probably): " Green
            shoutOut "'$($parent.Path)'" Green
            shoutOut "Rebasing the disk... " -NoNewline
            try {
                $vhd | Set-VHD -ParentPath $parent.Path
                shoutOut "Success!" Green
            } catch {
                shoutOut "Failed!" Red
                shoutOut $_
            }
        } else {
            shoutOut "Is missing it's parent disk!" Red
            shoutOut "Missing disk: " Red -NoNewline
            shoutOut "'$($vhd.ParentPath)'" Red
        }

    }
}