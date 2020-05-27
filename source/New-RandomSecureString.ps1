# Generate new random SecureString to use as a password.
function New-RandomSecureString() {
    [CmdletBinding()]
    param(
        [int]$Length=8,
        [string]$Characters="abcdefghijklmnopqrstuvwxyz0123456789-_"
    )

    $rng = $script:__RNG

    $password = New-Object securestring

    for ($i = 0; $i -lt $Length; $i++) {
        $c = $Characters[$rng.Next($Characters.Length)]
        if ($rng.Next(10) -gt 4) {
            $c = "$c".ToUpper()
        }

        $password.AppendChar($c)
    }

    return $password
}