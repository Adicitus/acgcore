<#
.SYNOPSIS
Restores a PSCredential saved to disk using the Save-PSCredential Cmdlet.

.PARAMETER Path
Path to the file containing the credential.

.PARAMETER Key
DPAPI key to use when decrypting the credential (256 bits, base64 encoded).
#>
function Restore-PSCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, HelpMessage="Path to the file from which the credential should be loaded.")]
        [String]$Path,
        [Parameter(Mandatory=$false, HelpMessage="DPAPI key to use when decrypting the credential (256 bits, base64 encoded).")]
        [string]$Key
    )

    $Path = Resolve-Path $path

    $credStr = Get-Content -Path $path -Encoding UTF8

    $convertArgs = @{
        CredentialString = $credStr
    }

    if ($Key) {
        $convertArgs.Key = $Key
    }

    return ConvertTo-PSCredential @convertArgs
}