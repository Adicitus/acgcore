<#
.SYNOPSIS
Transforms a SecureString back into a plain string. Must the run by the same user, on the same computer where it was produced.
#>
function Unlock-SecureString {
    param(
        [SecureString]$SecString
    )
    $Marshal = [Runtime.InteropServices.Marshal]
    $bstr = $Marshal::SecureStringToBSTR($SecString)
    $r = $Marshal::ptrToStringAuto($bstr)
    $Marshal::ZeroFreeBSTR($bstr)
    return $r
}