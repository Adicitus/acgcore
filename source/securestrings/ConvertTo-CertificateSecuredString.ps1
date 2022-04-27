
<#
.SYNOPSIS
Transforms a SecureString to a certificate-secured string.

.PARAMETER SecureString
The SecureString to convert.

.PARAMETER Certificate
A X509 certificate object that should be used to encrypt the string.

.PARAMETER Thumbprint
The thumbprint of a certificate to use when encrypting the string.

The Cmdlet will look in the entire store for a certificate with the given thumbprint.

If more than 1 certificate is found with the thumbprint, the Cmdlet will verify that they
are in fact duplicate copies of the same certificate by check that they have the same Issuer
and Serial Number.

If more than 1 certificate are found to have the same thumbprint this Cmdlet will throw
an exception.

WARNING: You will need to use the private key associated with the certificate to
decrypt the string. This Cmdlet does not check if the private key is available.

.PARAMETER CertificateFilePath
Path to an existing file containing a DER-encoded certificate to use when encoding the string. 
#>
function ConvertTo-CertificateSecuredString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
        [securestring]$SecureString,
        [parameter(Mandatory=$true, Position=2, ParameterSetName="Certificate")]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [parameter(Mandatory=$true, Position=2, ParameterSetName="Thumbprint")]
        [string]$Thumbprint,
        [Parameter(Mandatory=$true, ParameterSetName="CertificateFilePath")]
        [string]$CertificateFilePath
    )

    $pubKey = switch ($PSCmdlet.ParameterSetName) {

        Certificate {
            $Certificate.publicKey.Key
        }

        Thumbprint {
            # Retrieve the certificate:
            $cert = $null
            try {
                $cert = Get-ChildItem -Path 'Cert:\' -Recurse -ErrorAction Stop | Where-Object Thumbprint -eq $Thumbprint
            } catch {
                $msg = "Unexpected error while looking up the certificate ('{0}')." -f $Thumbprint
                $ex = New-Object $msg $_
                throw $ex
            }

            # Verify that we found a certificate:
            if ($null -eq $cert) {
                $msg = "Failed to find the certificate ('{0}')." -f $Thumbprint
                throw $msg
            }

            # Verify that we retrieved only a single certificate:
            if ($cert -is [array]) {
                # More than 1 certificate found.
                # This should not pretty much never happen, unless the store contains duplicates of the same certificate.
                # Verify that they are the same certificate:
                $cert = $cert | Sort-Object { "Cert={1}, {0}" -f $_.Issuer, $_.SerialNumber } -Unique
                if ($cert -is [array]) {
                    $msg = "More than 1 certificate found for the thumbprint ('{0}')." -f $Thumbprint
                    throw $msg
                }
            }

            $cert.PublicKey.Key
        }

        CertificateFilePath {
            Try {
                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $CertificateFilePath -ErrorAction Stop
            } catch {
                $msg = "Failed to load the specified certificate file ('{0}')." -f $CertificateFilePath
                $ex = New-Object System.Exception $msg $_.Exception
                throw $ex
            }

            $cert.PublicKey.Key
        }
    }

    # Unlock the securestring and turn it into a byte array:
    $plain = Unlock-SecureString -SecString $SecureString
    $plainBytes = [System.Text.Encoding]::Default.GetBytes($plain)
    Remove-Variable 'plain'
    # Use the public key to encrypt the byte array:
    $encBytes = $pubKey.encrypt($plainBytes, [System.Security.Cryptography.RSAEncryptionPadding]::Pkcs1)
    Remove-Variable 'plainBytes'
    # Convert the encrypted byte array to Bas64 string:
    $encString = [convert]::ToBase64String($encBytes)

    return $encString
}