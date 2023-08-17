<#
.SYNOPSIS
Takes a protected SecureString and exports it to a portable format as an encrypted string (can also exort as a plaintext string).

#>
function Export-SecureString {
    [CmdletBinding(DefaultParameterSetName="dpapi")]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=1)]
        [Alias('SecString')]
        [ValidateNotNull()]
        [securestring]$SecureString,
        [Parameter(Mandatory=$true, ParameterSetName='dpapi.key', HelpMessage='Signals that the credential should be protected using a DPAPI key.')]
        [Alias('UseKey')]
        [switch] $UseDPAPIKey,
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
        [Parameter(Mandatory=$true, ParameterSetName='x509.unmanaged', HelpMessage='Certificate that should be used to encrypt the resulting string.')]
        [System.Security.Cryptography.X509Certificates.X509Certificate] $Certificate,
        [Parameter(Mandatory=$true, ParameterSetName='x509.managed', HelpMessage='Thumbprint of the certificate that should be used to encrypt the resulting string. Warning: you will need the corresponding private key to decrypt the string.')]
        [string] $Thumbprint,
        [Parameter(Mandatory=$true, ParameterSetName='plain', HelpMessage='Disable encryption, causing the plain text be base64 encoded.')]
        [switch] $NoEncryption
    )

    switch ($PSCmdlet.ParameterSetName) {
        dpapi {
            return ConvertFrom-SecureString -SecureString $SecureString
        }

        dpapi.key {

            $convertArgs = @{
                SecureString = $SecureString
            }

            if ($PSBoundParameters.ContainsKey('Key')) {
                $bytes = [System.Convert]::FromBase64String($Key)
                if ($bytes.count -notin 16, 24, 32) {
                    $msg = "Invalid key provided for SecureString export: expected a Base64 string convertable to a 16, 24 or 32 byte array (found a string convertible to {0} bytes)." -f $bytes.Count
                    throw $msg
                }
            } else {
                $r = $script:__RNG
                $bytes = for($i = 0; $i -lt 32; $i++) { $r.next(0, 256) }
            }
            $convertArgs.Key = $bytes

            return @{
                String = ConvertFrom-SecureString @ConvertArgs
                Key    = [System.Convert]::ToBase64String($convertArgs.Key)
            }

        }

        x509.unmanaged {
            return convertTo-CertificateSecuredString -SecureString $SecureString -Certificate $Certificate
        }

        x509.managed {
            return convertTo-CertificateSecuredString -SecureString $SecureString -Thumbprint $Thumbprint
        }

        plain {
            $Marshal = [Runtime.InteropServices.Marshal]
            $bstr = $Marshal::SecureStringToBSTR($SecureString)
            $r = $Marshal::ptrToStringAuto($bstr)
            $Marshal::ZeroFreeBSTR($bstr)
            return $r
        }
    }
}