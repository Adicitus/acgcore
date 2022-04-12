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

    $base64StrRegex = '[A-Za-z-0-9+\/]+=*'
    $credStringRegex = '^(?<v>{0}):(?<u>{0}):(?<p>{0})$' -f $base64StrRegex
    $legacyCredStringRegex = '^(?<u>[^:]+):(?<p>{0})$' -f $base64StrRegex

    switch -Regex ($CredentialString) {
        $credStringRegex {
            # TODO: Handle newer credential version formats.

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
                dpapi.Key {
                    # Explicit encryption using DPAPI with a key (128, 192 or 256 bits). This only works on Windows.
                    # Assumption: The string was produced using ConvertFrom-SecureString Cmdlet with the 'Key' parameter.

                    if (-not $PSBoundParameters.ContainsKey('Key')) {
                        throw "Credential is DPAPI key-encrypted, but no value provided for 'Key' parameter."
                    }

                    $keyBytes = [System.Convert]::FromBase64String($key)

                    ConvertTo-SecureString -String $Matches.p -Key $KeyBytes
                }

                dpapi {
                    # Implicit encryption using user credentials. This only works on Windows.
                    # Assumption: The string was produced using ConvertFrom-SecureString Cmdlet.

                    ConvertTo-SecureString -String $Matches.p
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

            # TODO: Create and return a PSCredential object.
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