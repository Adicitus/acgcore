#ConvertTo-UnicodeEscapedString.ps1

function ConvertTo-UnicodeEscapedString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [String]$inString
    )

    $sb = New-Object System.Text.StringBuilder

    $inChars = [char[]]$inString

    foreach ($c in $inChars) {
        $encV = if ($c -gt 127) {
            "\u"+([int]$c).ToString("X4")
        } else {
            $c
        }
        $sb.Append($encV) | Out-Null
    }

    return $sb.ToString()
}