<#
.DESCRIPTION
Converts the provided Base64 encoded string to a regular string.
#>
function ConvertFrom-Base64String {
    [CmdletBinding(DefaultParameterSetName="Encoding")]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=1, HelpMessage="Base64-encoded string to convert.")]
        [ValidatePattern('^([a-z0-9+\/]+={0,2})?$')]
        [ValidateScript({
            if ($_.Length % 4 -ne 0) {
                $msg = "Invalid string length. Base64-encoded strings should have a length evently divisible by 4, found {0} ('{1}')" -f $_.Length, $_
                throw $msg
            }
            return $true
        })]
        [string]$Base64String,
        [Parameter(Mandatory=$false, Position=2, HelpMessage="Encoding to convert the string into.")]
        [System.Text.Encoding]$OutputEncoding = [System.Text.Encoding]::default,
        [Parameter(Mandatory=$true, ParameterSetName="Raw", HelpMessage="Disable output encoding, returns a byte array.")]
        [switch]$NoEncoding
    )

    process {
        foreach($s in $Base64String) {
            if ($s.Length % 4 -ne 0) {
                Throw
            }

            $bytes = [convert]::FromBase64String($Base64String)

            if ($PSCmdlet.ParameterSetName -eq "Raw") {
                $bytes
            } else {
                $OutputEncoding.GetString($bytes)
            }
        }
    }
}