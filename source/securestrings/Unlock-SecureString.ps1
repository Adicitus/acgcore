<#
.SYNOPSIS
Transforms a SecureString back into a plain string. Must the run by the same user, on the same computer where it was produced.

.DESCRIPTION
Transforms a SecureString back into a plain string. Must the run by the same user, on the same computer where it was produced.

This is a wrapper for Export-SecureString, and is equivalent to:
    Export-SecureString -SecureString $SecureString -NoEncryption

.PARAMETER SecureString
SecureString to unlock.
#>
function Unlock-SecureString {
    param(
        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [Alias('SecString')] # Backwards compatibility for pre version 0.10.0.
        [SecureString]$SecureString
    )
    
    return Export-SecureString -SecureString $SecureString -NoEncryption
}