#ConvertFrom-UnicodeEscapedString.ps1

function ConvertFrom-UnicodeEscapedString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$InString
    )

    return [System.Text.RegularExpressions.Regex]::Unescape($InString)
}