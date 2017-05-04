# CreateShortcut.ps1

function Create-Shortcut(){
    param(
        [parameter(Mandatory=$true, position=1)][String]$ShortcutPath,
        [parameter(Mandatory=$true, position=2)][String]$TargetPath,
        [parameter(Mandatory=$false, position=3)][String]$Arguments,
        [parameter(Mandatory=$false, position=4)][String]$IconLocation
    )

    if ($ShortcutPath -match '^(?<directory>([A-Z]:|\.)[\\/]([^\\/]+[\\/])*)(?<filename>.*\.lnk)$'){
        $shortcutDir  = $Matches.directory
        $shortcutFile = $Matches.filename
    } else {
        shoutOut "Invalid path: " Red -NoNewline
		shoutOut "$shortcutPath"
        return $false
    }

    $WSShell = New-Object -ComObject WScript.shell
    $shortcut = $WSShell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    if ($Arguments) { $shortcut.Arguments = $Arguments }
    if ($IconLocation) { $shortcut.IconLocation = $IconLocation }
    $shortcut.Save()
    return $true

}