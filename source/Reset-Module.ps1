function Reset-Module {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ArgumentCompleter({
            Get-Module | Foreach-Object Name
        })]
        [string]$Name
    )

    if ($module = Get-Module $Name) {
        Remove-Module $module -Force
    }

    Import-Module $Name -Global
}