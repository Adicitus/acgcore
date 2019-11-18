function Load-Credential($path) {
    $credStr = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $u, $p = $credStr.split(":")
    New-Object PScredential $u, ($p | ConvertTo-SecureString)
}