# ExecuteFile.ps1

function Execute-File() {
    param(
        [parameter(Mandatory=$true, Position=1)] [String]$File,
        [parameter(Mandatory=$false, Position=2)] [String]$Args,
        [parameter(Mandatory=$false, Position=3)][Boolean]$UseShell = $false,
        [parameter(Mandatory=$false)] [Switch] $GetExitCode
    )

    $ps = New-Object System.Diagnostics.Process
    $ps.StartInfo.Filename  = $File
    $ps.StartInfo.Arguments = $Args
    $ps.StartInfo.UseShellExecute = $UseShell
    $_ = $ps.start()
    $ps.WaitForExit()
    
    if ($GetExitCode) {
        return $ps.ExitCode
    }

    if ($ps.ExitCode -eq 0) {
        return $true
    } else {
        return $false
    }
}