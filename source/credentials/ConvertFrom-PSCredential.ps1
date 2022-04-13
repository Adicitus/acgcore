
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
    [CmdletBinding(DefaultParameterSetName="dpapi")]
    param(
        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true, HelpMessage="Credential to convert.")]
        [PSCredential] $Credential,
        [Parameter(Mandatory=$true, ParameterSetName='dpapi.key', HelpMessage='Signals that the credential should be protected using a DPAPI key.')]
        [switch] $UseKey,
        [Parameter(Mandatory=$false, ParameterSetName='dpapi.key', HelpMessage='A base64 encoded key to use when encrypting the credentials. If this parameter is not specified when the $UseKey switch is set, a random 256 bit key will be generated.')]
        [string] $Key,
        [Parameter(Mandatory=$true, ParameterSetName='plain', HelpMessage='Disable encryption, causing the plain text be base64 encoded.')]
        [switch] $NoEncryption,
        [Parameter(Mandatory=$true, ParameterSetName='plain', HelpMessage='Are you completely sure you do not want to use encryption?.')]
        [switch] $ThisIsNotProductionCode,
        [Parameter(Mandatory=$true, ParameterSetName='plain', HelpMessage="Ok, you're the boss.")]
        [switch] $IKnowWhatIAmDoing
    )
    
    # Scriptblock to convert string to Base64 string.
    $convertToBase64 = {
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

        plain {
            $header.m = 'plain'
            $encPassword = & $convertToBase64 (Unlock-SecureString $secPassword)
        }
    }

    $headerString = $header | ConvertTo-Json -Compress

    $credStr = @(
        & $convertToBase64 $headerString
        & $convertToBase64 $username
        $encPassword
    ) -join ":"

    if ($result.Count -eq 0) {
        $result = $credStr
    } else {
        $result.CredentialString = $credStr
    }

    return $result
}