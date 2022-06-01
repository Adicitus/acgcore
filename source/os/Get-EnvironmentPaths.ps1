function Get-EnvironmentPaths() {
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$false, Position=1, HelpMessage="The type of environment variable to retrieve.")]
        [System.EnvironmentVariableTarget]$Target = [System.EnvironmentVariableTarget]::Process
    )

    $v = [System.Environment]::GetEnvironmentVariable('Path', $Target)
    if ($null -ne $v) {
        return $v.split(';')
    } else {
        return $null
    }
}