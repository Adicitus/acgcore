function Reset-Module {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    if ($module = Get-Module $Name) {
        Remove-Module $module -Force
    }

    Import-Module $Name
}