<#
.SYNOPSIS
Converts a portable string representation of a PSCredential object back into a PSCredential Object.

.PARAMETER CredentialString
The string representation of the PSCredential object to restore.

.PARAMETER Key
A base64 key (256 bits) that should be used to decrypt the stored credential.
#>
function ConvertTo-PSCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="String representation of the credential to restore.")]
        [string]$CredentialString,
        [Parameter(Mandatory=$false, HelpMessage="DPAPI key to use when decrypting the credential (256 bits, base64 encoded).")]
        [string]$Key
    )

    $base64StrRegex = '[A-Za-z-0-9+\/]+=*'
    $credStringRegex = '^(?<v>{0}):(?<u>{0}):(?<p>{0})$' -f $base64StrRegex
    $legacyCredStringRegex = '^(?<u>[^:]+):(?<p>{0})$' -f $base64StrRegex

    switch -Regex ($CredentialString) {
        $credStringRegex {

            $versionBytes   = [Convert]::FromBase64String($Matches.v)
            $versionString  = [System.Text.Encoding]::UTF8.GetString($versionBytes)

            try {
                $versionInfo    = ConvertFrom-Json $versionString -ErrorAction Stop
            } catch {
                $msg = "Failed to convert verion field: '{0}'" -f $versionString
                $ex = New-Object System.Exception $msg $_.Exception
                throw $ex
            }

            if ($versionInfo -isnot [PSCustomObject]) {
                throw "Invalid version field format: $versionString"
            }

            if ($null -eq $versionInfo.m) {
                throw "Missing method ('m') field in version field: $versionString"
            }

            $secPassword = switch ($versionInfo.m) {
                dpapi {
                    # Implicit encryption using user credentials. This only works on Windows.
                    # Assumption: The string was produced using ConvertFrom-SecureString Cmdlet.

                    ConvertTo-SecureString -String $Matches.p
                }

                dpapi.Key {
                    # Explicit encryption using DPAPI with a key (128, 192 or 256 bits). This only works on Windows.
                    # Assumption: The string was produced using ConvertFrom-SecureString Cmdlet with the 'Key' parameter.

                    if (-not $PSBoundParameters.ContainsKey('Key')) {
                        throw "Credential is DPAPI key-encrypted, but no value provided for 'Key' parameter."
                    }

                    $keyBytes = [System.Convert]::FromBase64String($key)

                    ConvertTo-SecureString -String $Matches.p -Key $KeyBytes
                }

                x509.managed {

                    if ($null -eq $versionInfo.t) {
                        $msg = "Unable to decrypt credential: Invalid credential string header. Method '{0}' specified but thumbprint is missing (no 't' field)" -f $_
                        throw $msg
                    }

                    $cert = $null

                    try {
                        $cert = Get-ChildItem -Path Cert:\ -Recurse | Where-Object Thumbprint -eq $versionInfo.t
                    } catch {
                        $msg = "Unable to decrypt credential: An unexpecetd error occured when looking for thumbprint '{0}' in the certificate store." -f $versionInfo.t
                        $ex  = New-Object System.Exception $msg $_.Exception
                        throw $ex
                    }

                    # Verify that we found a certificate:
                    if ($null -eq $cert) {
                        $msg = "Unable to decrypt credential: Failed to find the certificate used to encrypt the credential string ('{0}')." -f $versionInfo.t
                        throw $msg
                    }

                    # Verify that we retrieved only a single certificate:
                    if ($cert -is [array]) {
                        # More than 1 certificate found.
                        # This should not pretty much never happen, unless the store contains duplicates of the same certificate.
                        # Verify that they are the same certificate:
                        $cert = $cert | Sort-Object { "Cert={1}, {0}" -f $_.Issuer, $_.SerialNumber } -Unique
                        if ($cert -is [array]) {
                            $msg = "Unable to decrypt credential. More than 1 certificate found for the thumbprint ('{0}')." -f $versionInfo.t
                            throw $msg
                        }
                    }

                    # Verify that we have the private key for certificate
                    if (!$cert.HasPrivateKey) {
                        $msg = "Unable to decrypt credential. No private key available for the certificate used to encrypt the credential (thumbprint '{0}')." -f $versionInfo.t
                        throw $msg
                    }

                    $k = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)

                    $passBytesEnc   = [convert]::FromBase64String($Matches.p)
                    $passBytes      = $k.Decrypt($passBytesEnc, [System.Security.Cryptography.RSAEncryptionPadding]::Pkcs1)
                    $passStr        = [System.Text.Encoding]::Default.GetString($passBytes)
                    Remove-Variable 'passBytes'
                    $passSecStr     = ConvertTo-SecureString -String $passStr -AsPlainText -Force
                    Remove-Variable 'passStr'

                    $passSecStr
                }
                
                plain {
                    # Plain Text encyption, this is only available for debug/testing/demo purposes.
                    $passBytes  = [Convert]::FromBase64String($Matches.p)
                    $passString = [System.Text.Encoding]::UTF8.GetString($passBytes)
                    ConvertTo-SecureString -String $passString -AsPlainText -Force
                }

                default {
                    $msg = "Unrecognized encryption method: {0}" -f $versionInfo.m 
                }
            }

            $userBytes  = [Convert]::FromBase64String($Matches.u)
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