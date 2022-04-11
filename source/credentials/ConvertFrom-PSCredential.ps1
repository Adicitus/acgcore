
<#
.SYNOPSIS
Converts a PSCredential object into a DPAPI-protected string representation.

.DESCRIPTION
Converts a PSCredential object into a DPAPI-protected string represenation.

If the $UseKey switch is specified, the function returns a hashtable with the
following keys:
    - Key: The key used to encrypt the credential.
    - Credential: The encrypted string representation of the credential.

Otherwise the encrypted string representation is returned.

.PARAMETER Credential
PSCredential Object to convert.

.PARAMETER UseKey
Switch to indicate that the credential is to be encrypted using a key.

.PARAMETER Key
A base64-encoded key of 256 bits that should be used when encrypting the credential (DPAPI).

#>
function ConvertFrom-PSCredential {
    param(
        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true, HelpMessage="Credential to convert.")]
        [PSCredential] $Credential,
        [Parameter(Mandatory=$false, HelpMessage='Signals that the credential should be protected using a DPAPI key.')]
        [switch] $UseKey,
        [Parameter(Mandatory=$false, HelpMessage='A base64 encoded key to use when encrypting the credentials. If this parameter is not specified when the $UseKey switch is set, a random 256 bit key will be generated.')]
        [string] $Key
    )

    $convertArgs = @{
        SecureString = $Credential.Password
    }

    if ($UseKey) {
        if ($Key) {
            $bytes = [System.Convert]::FromBase64String($Key)
            if ($bytes.count -ne 32) {
                throw "Invalid key provided for Save-Credential (expected a Base64 string convertable to a 32 byte array)."
            }
        } else {
            $r = [System.Random]::new()
            $bytes = for($i = 0; $i -lt 32; $i++) { $r.next(0, 256) }
        }
        $convertArgs.Key = $bytes
    }

    $credStr = "{0}:{1}" -f $Credential.Username, (ConvertFrom-SecureString @convertArgs)

    $r = if ($UseKey) {
        @{ 
            Key = [System.Convert]::ToBase64String($convertArgs.Key)
            CredentialString = $credStr
        }
    } else {
        $credStr
    }

    return $r
}