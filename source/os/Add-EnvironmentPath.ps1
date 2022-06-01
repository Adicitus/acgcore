function Add-EnvironmentPath {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position=1, HelpMessage="The path to add to the Path environmental variable.")]
        [string]$Path,
        [parameter(Mandatory=$false, Position=2, HelpMessage="The type of environment variable to target.")]
        [System.EnvironmentVariableTarget]$Target = [System.EnvironmentVariableTarget]::Process
    )

    $oldPath = [System.Environment]::GetEnvironmentVariable('Path', $Target)
    $paths = if ($null -eq $oldPath) {
        [string[]]@()
    } else {
        [string[]]$oldPath.split(';')
    }

    if ($paths -contains $Path) {
        return
    }
    $newPath = ($paths + $Path) -join ";"
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, $Target)
}