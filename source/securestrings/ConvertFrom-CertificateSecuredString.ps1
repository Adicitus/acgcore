<#
.SYNOPSIS
Decryps a certificate-secured string and turns it into a SecureString.

.PARAMETER CertificateSecuredString
Certificate-secured string to convert into a SecureString.

.PARAMETER Certificate
Certificate with an associated private key should be used to decrypt the secured string.

.PARAMETER Thumbprint
Thumbprint of the certificate that should be used to decrypt the secured string.

#>
function ConvertFrom-CertificateSecuredString {
    param(
        [parameter(Mandatory=$true, ValueFromPipeline=$true, HelpMessage="Base64-encoded certificate-encrypted string to decrypt.")]
        [ValidatePattern('[a-z0-9+\/=]+')]
        [string]$CertificateSecuredString,
        [parameter(Mandatory=$true, ParameterSetName="Certificate")]
        [System.Security.Cryptography.X509Certificates.X509Certificate]$Certificate,
        [parameter(Mandatory=$true, ParameterSetName="Thumbprint")]
        [string]$Thumbprint
    )

    $privateKey = $null

    switch ($PSCmdlet.ParameterSetName) {

        Certificate {
            # Verify that the certificate has a private key:
            if (-not $Certificate.HasPrivateKey) {
                $msg = "Unable to decrypt string. No private key available for the certificate used to encrypt the credential (thumbprint '{0}')." -f $Thumbprint
                throw $msg
            }

            # Check if the private key is included in the certificate object:
            if ($null -ne $Certificate.privateKey) {
                $privateKey = $Certificate.privateKey.Key
                break
            }

            # Check if we can find the associated private key:
            try {
                $privateKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Certificate)
            } catch {
                $msg = "Failed to find a private key for the provided certificate: SN={0},{1} (Thumbprint: '{0}')" -f $Certificate.SerialNumber, $Certificate.Issuer, $Certificate.Thumbprint
                $ex = New-Object $msg $_.Exception
                throw $ex
            }
        }

        Thumbprint {
            # Retrieve the certificate:
            $cert = $null
            try {
                $cert = Get-ChildItem -Path 'Cert:\' -Recurse -ErrorAction Stop | Where-Object Thumbprint -eq $Thumbprint
            } catch {
                $msg = "Unexpected error while looking up the certificate (thumbprint '{0}')." -f $Thumbprint
                $ex = New-Object $msg $_
                throw $ex
            }

            # Verify that we found a certificate:
            if ($null -eq $cert) {
                $msg = "Failed to find the certificate (thumbprint '{0}')." -f $Thumbprint
                throw $msg
            }

            # Verify that we retrieved only a single certificate:
            if ($cert -is [array]) {
                # Eliminate any certificat that does not have an associated private key:
                $cert = $cert | Where-Object HasPrivateKey

                # Verify that we still have at least 1:
                if ($null -eq $cert) {
                    $msg = "No certificate with associated private key available for the thumbprint ('{0}')" -f $Thumbprint
                    throw $msg
                }

                # More than 1 certificate found.
                # This should not pretty much never happen, unless the store contains duplicates of the same certificate.
                # Verify that they are the same certificate:
                $cert = $cert | Sort-Object { "Cert={1}, {0}" -f $_.Issuer, $_.SerialNumber } -Unique
                if ($cert -is [array]) {
                    $msg = "More than 1 certificate found for the thumbprint ('{0}')." -f $Thumbprint
                    throw $msg
                }
            }

            # Verify that the certificate has an associated private key:
            if (-not $cert.HasPrivateKey) {
                $msg = "Unable to decrypt string. No private key available for the certificate used to encrypt the credential (thumbprint '{0}')." -f $Thumbprint
                throw $msg
            }

            $privateKey = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
        }

        default {
            $msg = "Unknown ParameterSet ('{0}'). This shouldn't happen, but indicates that someone has pushed buggy/incomplete code." -f $PSCmdlet.ParameterSetName
            throw $msg
        }
    }

    if ($null -eq $privateKey) {
        $msg = "Failed to retrieve the private key for the specified certificate (thumbprint '{0}')." -f $Thumbprint
        throw $msg
    }

    $encBytes   = [convert]::FromBase64String($CertificateSecuredString)
    $plainBytes      = $privateKey.Decrypt($encBytes, [System.Security.Cryptography.RSAEncryptionPadding]::Pkcs1)
    $plainString     = [System.Text.Encoding]::Default.GetString($plainBytes)
    Remove-Variable 'plainBytes'
    $secString  = ConvertTo-SecureString -String $plainString -AsPlainText -Force
    Remove-Variable 'plainString'

    return $secString
}