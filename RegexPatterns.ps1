$Script:RegexPatterns = @{ }

$Script:RegexPatterns.IPv4AddressByte = "(25[0-4]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])" # A byte in an IPv4 Address
$IPv4AB = $Script:RegexPatterns.IPv4AddressByte
$Script:RegexPatterns.IPv4NetMaskByte = "(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[1-9])" # A non-full byte in a IPv4 Netmask
$IPv4NMB = $Script:RegexPatterns.IPv4NetMaskByte

$ItemChars = "[^\\/:*`"|<>]"
$Script:RegexPatterns.Directory = '(?<directory>(?<root>[A-Z]+:|\.|\\.*)[\\/]({0}+[\\/]?)*)' -f $ItemChars
$Script:RegexPatterns.File = ( '(?<file>(?<directory>((?<root>[A-Z]+:|\.|\\.*)[\\/])?({0}+[\\/])*)(?<filename>([^\\/.]+)+(\.(?<extension>[^\\/.]+)?))' + ")" ) -f $ItemChars
$Script:RegexPatterns.IPv4Address = "($IPv4AB\.){3}$($IPv4AB)"
$Script:RegexPatterns.IPv4Netmask = "((255\.){3}$IPv4NMB)|((255\.){2}($IPv4NMB\.)0)|((255\.){1}($IPv4NMB\.)0\.0)|(($IPv4NMB\.)0\.0\.0)|0\.0\.0\.0"
$Script:RegexPatterns.GUID = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{10}"


<#
.SYNOPSIS
Returns the ACGCore regular expression with the given name.
#>
function Get-ACGCoreRegexPattern {
    param([string]$PatternName)

    if ($Script:RegexPatterns.ContainsKey($PatternName)) {
        return $Script:RegexPatterns[$PatternName]
    } else {
        throw "Invalid pattern name provided"
    }
}

<#
.SYNOPSIS
Rreturns the name of all standard regular expressions used in ACGCore.
#>
function Get-ACGCoreRegexPatternNames {

    return $Script:RegexPatterns.Keys
}


<#
.SYNOPSIS
Matches ACGCore regular expressions against a string.
.DESCRIPTION
Tries to match the given string $value against the pattern named $PatternName.

Returns a record of the match if the regex matches the given value (equivalent
to $matches), otherwise returns $false.

By default the this function assumes that the entire string should match the
given pattern. This behavior can be overriden by using the AllowPartialMatches
switch, in which case the function will attempt to match any part of the given
string.
#>
function Test-ACGCoreRegexPattern {
    param([string]$Value, [string]$PatternName, [switch]$AllowPartialMatch)

    try {
        $pattern = Get-ACGCoreRegexPattern $PatternName
        
        if (!$AllowPartialMatch) {
            $pattern = "^$pattern$"
        }

        if ($value -match $pattern) {
            return $matches.Clone()
        }

        return $false
    } catch {
        return $false
    }

}