#ConvertFrom-UnicodeEscapedString.ps1

function ConvertFrom-UnicodeEscapedString {
    param(
        [string]$InString
    )

    return [System.Text.RegularExpressions.Regex]::Unescape($InString)
}