
<#
.SYNOPSIS
Saves a PSCredential to disk as a DPAPI protected string.

.PARAMETER Path
Path to the file containing the credential.

.PARAMETER UseKey
Switch to signal that the Cmdlet should use a key when encypting the credentials.

.PARAMETER Key
A DPAPI key to use when encrypting the credential (256 bits, base64 encoded).

If this is not specified, a random 256 bit key will be generated.
#>
function Save-PSCredential{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=1, HelpMessage="Path to the file where the credential should be stored.")]
        [string] $Path,
        [Parameter(Mandatory=$true, Position=2, ValueFromPipeline=$true, HelpMessage="Credential to store.")]
        [PSCredential] $Credential,
        [Parameter(Mandatory=$false, HelpMessage='Signals that the credential should be protected using a DPAPI key.')]
        [switch] $UseKey,
        [Parameter(Mandatory=$false, HelpMessage='A base64 encoded key (256 bits) to use when encrypting the credentials. If this parameter is not specified when the $UseKey switch is set, a random key will be generated.')]
        [string] $Key
    ) 

    $convertArgs = @{
        Credential = $Credential
    }

    if ($UseKey) {
        $convertArgs.UseKey = $true
        if ($PSBoundParameters.ContainsKey('Key')) {
            $convertArgs.Key = $Key
        }
    }

    $secCred = ConvertFrom-PSCredential @convertArgs

    if ($UseKey) {
        $secCred.CredentialString | Set-Content -Path $Path -Encoding UTF8
        return $secCred.Key
    } else {
        $secCred | Set-Content -Path $Path -Encoding UTF8
    }

}