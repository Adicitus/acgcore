
<#
.SYNOPSIS
Converts a PSCredential object into a portable string representation.

.DESCRIPTION
Converts a PSCredential object into a portable string represenation.

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

.PARAMETER Thumbprint
Thumbprint of a certificate in the certificate store of the local machine.

This will cause the the password to be encrypted using the certificates public key.

WARNING: You will need to use the private key associated with the certificate to
decrypt the credential. This Cmdlet does not check if the private key is available.

#>
function ConvertFrom-PSCredential {
    [CmdletBinding(DefaultParameterSetName="dpapi")]
    param(
        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true, HelpMessage="Credential to convert.")]
        [PSCredential] $Credential,
        [Parameter(Mandatory=$true, ParameterSetName='dpapi.key', HelpMessage='Signals that the credential should be protected using a DPAPI key.')]
        [switch] $UseKey,
        [Parameter(Mandatory=$false, ParameterSetName='dpapi.key', HelpMessage='A base64 encoded key to use when encrypting the credentials. If this parameter is not specified when the $UseKey switch is set, a random 256 bit key will be generated.')]
        [string] $Key,
        [Parameter(Mandatory=$true, ParameterSetName='x509.managed', HelpMessage='Thumbprint of the certificate that should be used to encrypt the credential. Warning: you will need the corresponding private key to decrypt the credential.')]
        [string] $Thumbprint,
        [Parameter(Mandatory=$true, ParameterSetName='plain', HelpMessage='Disable encryption, causing the plain text be base64 encoded.')]
        [switch] $NoEncryption,
        [Parameter(Mandatory=$true, ParameterSetName='plain', HelpMessage='Are you completely sure you do not want to use encryption?.')]
        [switch] $ThisIsNotProductionCode,
        [Parameter(Mandatory=$true, ParameterSetName='plain', HelpMessage="Ok, you're the boss.")]
        [switch] $IKnowWhatIAmDoing
    )
    
    # Scriptblock to convert string to Base64 string.
    $convertStringToBase64 = {
        param($s)

        $b      = [System.Text.Encoding]::Default.GetBytes($s)
        $utf8b  = [System.Text.Encoding]::Convert([System.Text.Encoding]::Default, [System.Text.Encoding]::UTF8, $b)
        $b64s   = [convert]::ToBase64String($utf8b)

        return $b64s
    }

    $result = @{}
    $header = @{}
    $username = $Credential.UserName
    $secPassword = $Credential.Password
    $encPassword = $null

    switch ($PSCmdlet.ParameterSetName) {
        dpapi       {
            $header.m = 'dpapi'

            $encPassword = ConvertFrom-SecureString -SecureString $secPassword
        }

        dpapi.key   {
            $header.m = 'dpapi.key'
            
            $convertArgs = @{
                SecureString = $secPassword
            }

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

            $encPassword = ConvertFrom-SecureString @ConvertArgs

            $result.Key = [System.Convert]::ToBase64String($convertArgs.Key)
        }

        x509.managed {
            <#
                Encrypt the credential using public key encryption via a X509 certificate found in Windows Certificate Store.

                Headers:
                    - m: Method ('x509.managed')
                    - t: Thumbprint of the certificate used.
            #>
            $header.m = 'x509.managed'
            $header.t = $Thumbprint

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
                $msg = "Failed to find the certificate ('{0}')." -f $versionString.t
                throw $msg
            }

            # Verify that we retrieved only a single certificate:
            if ($cert -is [array]) {
                # More than 1 certificate found.
                # This should not pretty much never happen, unless the store contains duplicates of the same certificate.
                # Verify that they are the same certificate:
                $cert = $cert | Sort-Object { "Cert={1}, {0}" -f $_.Issuer, $_.SerialNumber } -Unique
                if ($cert -is [array]) {
                    $msg = "More than 1 certificate found for the thumbprint ('{0}')." -f $versionString.t
                    throw $msg
                }
            }
            
            # Retrieve the public key:
            $k = $cert.publicKey.Key
            # Unlock the password securestring and turn the password into a byte array:
            $pass = Unlock-SecureString -SecString $Credential.Password
            $passBytes = [System.Text.Encoding]::Default.GetBytes($pass)
            Remove-Variable 'pass'
            # Use the public key to encrypt the password byte array:
            $encBytes = $k.encrypt($passBytes, [System.Security.Cryptography.RSAEncryptionPadding]::Pkcs1)
            Remove-Variable 'passBytes'
            # Convert the encrypted byte array to Bas64 string and assign it to $encPassword:
            $encPassword = [convert]::ToBase64String($encBytes)
            
        }

        plain {
            $header.m = 'plain'
            $encPassword = & $convertStringToBase64 (Unlock-SecureString $secPassword)
        }
    }

    $headerString = $header | ConvertTo-Json -Compress

    $credStr = @(
        & $convertStringToBase64 $headerString
        & $convertStringToBase64 $username
        $encPassword
    ) -join ":"

    if ($result.Count -eq 0) {
        $result = $credStr
    } else {
        $result.CredentialString = $credStr
    }

    return $result
}