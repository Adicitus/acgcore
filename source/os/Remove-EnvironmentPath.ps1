function Remove-EnvironmentPath {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, Position=1, HelpMessage="The path to remove from the Path environmental variable.")]
        [string]$Path,
        [parameter(Mandatory=$false, Position=2, HelpMessage="The type of environment variable to target.")]
        [System.EnvironmentVariableTarget]$Target = [System.EnvironmentVariableTarget]::Process
    )

    $oldPath = [System.Environment]::GetEnvironmentVariable('Path', $Target)
    if ($null -eq $oldPath) { return }
    $paths = [string[]]$oldPath.split(';')
    if ($paths -contains $Path) {
        $newPaths = $paths | Where-Object  { $_ -ne $Path }
        $newPath = $newPaths -join ';'
        [System.Environment]::SetEnvironmentVariable('Path', $newPath, $Target)
    }
}