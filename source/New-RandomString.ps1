<#
.SYNOPSIS
Generates a new random string of a given length using the given pool of candidate characters.

.PARAMETER Length
Number of characters in the string.

Minimum length is 1. Default is 8.

.PARAMETER Characters
String of candidate characters that will be used in the generated string.

If a character appears more than once, it will be most likely to appear in the
generated string.

Minimum length is 1.

This defaults to "abcdefghijklmnopqrstuvwxyz0123456789-_".

.PARAMETER ReturnType
The type of object to return:
    - String: Just return the plain string ([string]).
    - Bytes: Converts the string into an array of bytes ([byte[]]) before returning it.
    - Base64: Converts the string into a bas64 representation before returning it.
    - SecureString: Return the string as a SeureString object ([SecureString]).

.PARAMETER AsSecureString
Return the generated string as a SecureString instead of a plain String.

#>
function New-RandomString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, HelpMessage="Length of the string to generate.")]
        [ValidateScript({if ($_ -ge 0) { return $true }; throw "Invalid Length requested ($_), cannot generate a string of negative length." })]
        [int]$Length=8,
        [Parameter(Mandatory=$false, HelpMessage="String of candidate characters.")]
        [ValidateNotNullOrEmpty()]
        [string]$Characters="abcdefghijklmnopqrstuvwxyz0123456789-_",
        [Parameter(Mandatory=$false, HelpMessage="Format to return the string in (default 'String').")]
        [ValidateSet("String", "Base64", "Bytes", "SecureString")]
        [string]$ReturnFormat="String",
        [Parameter(Mandatory=$false, HelpMessage="Determines if selected characters will retain their original case.")]
        [bool]$RandomCase=$true,
        [Parameter(Mandatory=$false, HelpMessage="Causes the string to be returned as a SecureString. For legacy reasons, this overrides `$ReturnFormat.")]
        [switch]$AsSecureString
    )

    if ($Length -eq 0) {
        # Zero length string requested, return empty string. 
        return ""
    }

    $rng = $script:__RNG

    if ($AsSecureString -or ($ReturnFormat -eq "SecureString")) {
        $password = New-Object securestring
        for ($i = 0; $i -lt $Length; $i++) {
            $c = $Characters[$rng.Next($Characters.Length)]
            if ($RandomCase) {
                $c = if ($rng.Next(10) -gt 4) {
                    [char]::ToUpper($c)
                } else {
                    [char]::ToLower($c)
                }
            }

            $password.AppendChar($c)
        }
        return $password
    }

    $password = ""
    for ($i = 0; $i -lt $Length; $i++) {
        $c = $Characters[$rng.Next($Characters.Length)]
        if ($RandomCase) {
            $c = if ($rng.Next(10) -gt 4) {
                [char]::ToUpper($c)
            } else {
                [char]::ToLower($c)
            }
        }

        $password += $c
    }

    switch($ReturnFormat) {
        String {
            return $password
        }

        Bytes {
            return [System.Text.Encoding]::Default.GetBytes($password)
        }

        Base64 {
            $bytes = [System.Text.Encoding]::Default.GetBytes($password)
            return [System.Convert]::ToBase64String($bytes)
        }
    }
}
