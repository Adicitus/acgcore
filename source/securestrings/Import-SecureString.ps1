<#
.SYNOPSIS
Imports a provided string into the current context as a SecureString.

.PARAMETER DPAPIKey
A Base64-encoded string corresponding to a 128, 192 or 256 bit key that should be used to decrypt the string.

.PARAMETER Thumbprint
Thumbprint of a certificate to use when decrypting the string.

The cmdlet llooks in the entire certificate store.

If no certificate matching the thumbprint can be found, or if none of the found certificates have an
associated private key, the Cmdlet will throw an exception.

.PARAMETER NoEncryption
Indicates that the string is not encrypted an should be imported as-is.
#>
Function Import-SecureString {
    [CmdletBinding(DefaultParameterSetName='dpapi')]
    param(
        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true, HelpMessage="The exported SecureString to import")]
        [string]$String,
        [Parameter(Mandatory=$false, ParameterSetName='dpapi.key', HelpMessage='A base64 encoded key (128, 192 or 256 bits) to use when encrypting the string. If this parameter is not specified when the $UseKey switch is set, a random 256 bit key will be generated.')]
        [ValidateScript({
            # Verify that this is a valid Base64 string:
            $base64Pattern = "^[a-z0-9+\/\r\n]+={0,2}$"
            if ($_.Length % 4 -ne 0) {
                $msg = "Invalid base64 string provided as Key: string length should be evenly divisble by 4, current string length mod 4 is {0} ('{1}')" -f ($_.Length % 4), $_
                throw $msg
            }
            if ($_ -notmatch $base64Pattern) {
                $msg = "Invalid base64 string provided as Key: '{0}' contains invalid charactes." -f $_
                throw $msg
            }
            return $true
        })]
        [Alias('Key')]
        [string] $DPAPIKey,
        [Parameter(Mandatory=$true, ParameterSetName='x509.managed', HelpMessage='Thumbprint of the certificate that should be used to encrypt the resulting string. Warning: you will need the corresponding private key to decrypt the string.')]
        [string] $Thumbprint,
        [Parameter(Mandatory=$true, ParameterSetName='plain', HelpMessage='Disable encryption, causing the plain text be base64 encoded.')]
        [switch] $NoEncryption
    )

    switch ($PSCmdlet.ParameterSetName) {
        dpapi {
            return ConvertTo-SecureString -String $String
        }

        dpapi.key {
            $keyBytes = [convert]::FromBase64String($DPAPIKey)
            return ConvertTo-SecureString -String $string -Key $keyBytes
        }

        x509.managed {
            try {
                return ConvertFrom-CertificateSecuredString -CertificateSecuredString $String -Thumbprint $Thumbprint
            } catch {
                $msg = "Failed to decrypt the string using certificat (Thumbprint: {0}). See inner exception for details." -f $header.t
                $ex = New-Object System.Exception $msg, $_.Exception
                throw $ex
            }
        }

        plain {
            return ConvertTo-SecureString -String $String -AsPlainText -Force
        }
    }
}