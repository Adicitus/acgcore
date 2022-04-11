<#
.SYNOPSIS
Converts a DPAPI-protected string representation of a PSCredential object back into a PSCredential Object.

.PARAMETER CredentialString
The string representation of the PSCredential object to restore.

.PARAMETER Key
A base64 key (256 bits) that should be used to decrypt the stored credential.
#>
function ConvertTo-PSCredential {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="String representation of the credential to restore.")]
        [string]$CredentialString,
        [Parameter(Mandatory=$false, HelpMessage="DPAPI key to use when decrypting the credential (256 bits, base64 encoded).")]
        [string]$Key
    )

    $credStr = $CredentialString
    $u, $p = $credStr.split(":")
    
    $ConvertArgs = @{
        String=$p
    }

    if ($key) {
        $keyBytes = [System.Convert]::FromBase64String($key)
        $ConvertArgs.Key = $keyBytes
    }

    $secPass = ConvertTo-SecureString @ConvertArgs

    return New-PSCredential -Username $u -SecurePassword $secPass
}