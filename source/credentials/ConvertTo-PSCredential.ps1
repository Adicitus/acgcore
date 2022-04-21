<#
.SYNOPSIS
Converts a portable string representation of a PSCredential object back into a PSCredential Object.

.DESCRIPTION
Converts a portable string reprentation of a PSCredential object back into a PSCredential Object.

Most strings contain all the information required for decryption, so this Cmdlet does not expose many parameters.

.PARAMETER CredentialString
The string representation of the PSCredential object to restore.

.PARAMETER Key
A base64 key (256 bits) that should be used to decrypt the stored credential.
#>
function ConvertTo-PSCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="String representation of the credential to restore.")]
        [ValidatePattern('[a-z0-9+/]+={0,2}:[a-z0-9+/]+={0,2}:[a-z0-9+/]+={0,2}')]
        [string]$CredentialString,
        [Parameter(Mandatory=$false, HelpMessage="DPAPI key to use when decrypting the credential (256 bits, base64 encoded).")]
        [string]$Key
    )

    $base64StrRegex = '[A-Za-z-0-9+\/]+=*'
    $credStringRegex = '^(?<h>{0}):(?<u>{0}):(?<p>{0})$' -f $base64StrRegex
    $legacyCredStringRegex = '^(?<u>[^:]+):(?<p>{0})$' -f $base64StrRegex

    switch -Regex ($CredentialString) {
        $credStringRegex {

            $fields = @{
                header = $Matches.h
                username = $Matches.u
                password = $Matches.p
            }

            $headerBytes   = [Convert]::FromBase64String($fields.header)
            $headerString  = [System.Text.Encoding]::UTF8.GetString($headerBytes)

            try {
                $header = ConvertFrom-Json $headerString -ErrorAction Stop
            } catch {
                $msg = "Failed to convert verion field: '{0}'" -f $headerString
                $ex = New-Object System.Exception $msg $_.Exception
                throw $ex
            }

            if ($header -isnot [PSCustomObject]) {
                throw "Invalid header field format: $headerString"
            }

            if ($null -eq $header.m) {
                throw "Missing method ('m') field in header field: $headerString"
            }

            $secPassword = switch ($header.m) {
                dpapi {
                    # Implicit encryption using user credentials. This only works on Windows.
                    # Assumption: The string was produced using ConvertFrom-SecureString Cmdlet.

                    Import-SecureString -String $fields.password
                }

                dpapi.Key {
                    # Explicit encryption using DPAPI with a key (128, 192 or 256 bits). This only works on Windows.
                    # Assumption: The string was produced using ConvertFrom-PSCredential Cmdlet with the 'Key' parameter.

                    if (-not $PSBoundParameters.ContainsKey('Key')) {
                        throw "Credential is DPAPI key-encrypted, but no value provided for 'Key' parameter."
                    }

                    Import-SecureString -String $fields.password -DPAPIKey $Key
                }

                x509.managed {
                    # Explicit encryption using a X509 certificate found in the certificate store on this computer.
                    # NOTE: The private key associated with the certificate must be available, otherwise the decryption will fail.

                    if ($null -eq $header.t) {
                        $msg = "Unable to decrypt credential: Invalid credential string header. Method '{0}' specified but thumbprint is missing (no 't' field)" -f $_
                        throw $msg
                    }

                    try {
                        Import-SecureString -String $fields.password -Thumbprint $header.t -ErrorAction Stop
                    } catch {
                        $msg = "Failed to decrypt the credential using certificat (Thumbprint: {0}). See inner exception for details." -f $header.t
                        $ex = New-Object System.Exception $msg, $_.Exception
                        throw $ex
                    }
                }
                
                plain {
                    # Plain Text encyption, this is only available for debug/testing/demo purposes.
                    $passBytes  = [Convert]::FromBase64String($fields.password)
                    $passString = [System.Text.Encoding]::UTF8.GetString($passBytes)
                    Import-SecureString -String $passString -NoEncryption
                }

                default {
                    $msg = "Unrecognized encryption method in credential header ('{0}'). This may indicate that you are using an out-dated version of the Cmdlet." -f $header.m
                    throw $msg
                }
            }

            $userBytes  = [Convert]::FromBase64String($fields.username)
            $userString = [System.Text.Encoding]::UTF8.GetString($userBytes)

            return New-PSCredential -Username $userString -SecurePassword $secPassword
        }

        $legacyCredStringRegex {
            "Credential is serialized using legacy format. To avoid future complications, please reserialize the credential before storing it." | Write-Warning

            $u = $Matches.u
            $p = $Matches.p

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

        default {
            throw "Unrecognized credential string provided to ConvertTo-PSCredential: $CredentialString"
        }
    }
}