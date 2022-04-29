<#
.DESCRIPTION
Converts the provided string to a Base64-encoded string.
#>
function ConvertTo-Base64String {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=1, HelpMessage="String to convert to Base64.")]
        [ValidateNotNull()]
        [string[]]$String,
        [Parameter(Mandatory=$false, Position=2, HelpMessage="The encoding of the string to convert.")]
        [System.Text.Encoding]$InputEncoding = [System.Text.Encoding]::Default

    )

    process {
        foreach ($s in $String) {
            if ($String -eq '') {
                ''
            } else {
                $bytes = $InputEncoding.GetBytes($String)
                [convert]::ToBase64String($bytes)
            }
        }
    }
}