<# [Strict]Parse-ConfigFile.ps1
    An attempt to recreate the Deploy job-file parser in a strict fail-fast manner.

    Not quite correct RG for the parser:

    File 	-> Lines
    Lines 	-> Line, Line\nLines
    Line 	-> Include, Section, Directive, Empty
    Section -> \[[^\]]+\] 
    Directive -> \s*Name\s*(=\s*Value)?
    Name 	-> [^\s=#]+
    Value 	-> [^#]+|"[^"]*"|'[^']*'
    Include -> #include\s+(?<jobname>[a-zA-Z0-9]+)
    Comment -> \s*#.*
    Empty 	-> 
#>
<#
.SYNOPSIS
Parsing function used for ACGroup-style .ini configuration files.

.DESCRIPTION
Long description

.PARAMETER Path
The path to the configuration file.

.PARAMETER Config
Pre-populated configuration hashtable. If provided, the parser will add new settings to the hashtable.
The default behavior is to generate a new hashtable.

.PARAMETER NoInclude
Causes the parser skip include statements.

.PARAMETER NotStrict
Stops the parser from throwing an exceptions when errors are encountered.

.PARAMETER Silent
Stops the parser from outputting anything to the console.

.PARAMETER MetaData
Hashtable used to record MetaData while parsing.
Presently only records Includes and errors.

.PARAMETER Loud
Causes the parser to output extra information to the console.

.PARAMETER duplicatesAllowed
Names of settings for which duplicate values are allowed.

.PARAMETER IncludeRootPath
The root path to use when resolving includes. If this value isn't provided
then it will default to the directory part of $Path.

Include-paths that start with '\' or '/' will use this value when resolving
where to look for the included file.

Paths that do not start with either '\' or '/' will use the directory of the
of the file currently being processed.

All included files will be parsed using the same IncludeRootPath, 

.EXAMPLE
An example

.NOTES
General notes
#>
function Parse-ConfigFile {
    param (
        [parameter(
            Mandatory=$true,
            Position=1,
            HelpMessage="Path to the file."
        )] [String] $Path,              # Name of the job-file to parse (including extension)
        [parameter(
            Mandatory=$false,
            Position=2,
            HelpMessage="Pre-populated configuration hashtable. If provided, any options read from the given file will be appended."
        )] [Hashtable] $Config = @{},  # Pre-existing configuration, if given we'll simply add to this one.
        [parameter(
            Mandatory=$false,
            HelpMessage="Tells the parser to skip include stetements."
        )] [Switch] $NoInclude,                   # Tells the parser to skip any include statements
        [Parameter(
            Mandatory=$false,
            HelpMessage="Tells the parser not to throw an exception on parsing errors."
        )] [Switch] $NotStrict,                   # Tells the parser to not generate any exceptions.
        [Parameter(
            Mandatory=$false,
            HelpMessage="Suppresses all command-line output from the parser."
        )] [Switch] $Silent,                      # Supresses all commandline-output from the parser.
        [parameter(
            Mandatory=$false,
            HelpMessage='Hashtable used to record MetaData. Includes will be recorded in $MetaData.Includes.'
        )] [Hashtable] $MetaData,                 # Hashtable used to capture MetaData while parsing.
                                                  # This will record Includes as '$MetaData.includes'.
        [Parameter(Mandatory=$false)][Hashtable] $Cache,
        [parameter(
            Mandatory=$false,
            HelpMessage="Causes the Parser to output extra information to the console."
        )] [Switch] $Loud,                        # Equivalent of $Verbose
        [parameter(
            Mandatory=$false,
            HelpMessage="Array of settings for which values can be duplicated."
        )] [array]
        $duplicatesAllowed = @("Operation","Pre","Post"),                    # Declarations for which duplicate values are allowed.
        [parameter(
            Mandatory=$false,
            HelpMessage="The root directory used to resolve includes. Defaults to the directory of the config file."
        )] [string]$IncludeRootPath               # The root directory used to resolve includes.
    )
	
    # Error-handling specified here for reusability.
    $handleError = {
        param(
            [parameter(Mandatory=$true)] [String] $Message
        )
        if ($MetaData) {
            $MetaData.Errors = $Message
        }
        
        if ($NotStrict) {
            if (!$Silent) { write-host $Message -ForegroundColor Red }
        } else {
            throw $Message
        }
    }

    $Verbose = if (($Verbose -or $Loud) -and !$Silent) { $true } else { $false }
	
    if($Path -and (Test-Path $Path -PathType Leaf)) {
        $lines = Get-Content $Path -Encoding UTF8
    } else {
        . $handleError -Message "<InvalidPath>The given path doesn't lead to an existing file: '$Path'"
        return
    }

    $Item = Get-Item $Path -Force # Without -Force, Get-Item will generate an error for hidden files.

    if (!$PSBoundParameters.ContainsKey("IncludeRootPath")) {
        $IncludeRootPath = $Item.DirectoryName
    }

    $conf = @{}
    if ($Config) { # Protect against NULL-values.
        $conf = $Config
    }

    if ($MetaData) {
        if (!$MetaData.Includes) { $MetaData.Includes = @() }
        if (!$MetaData.Errors)   { $MetaData.Errors = @() }
    }
    
    $regex = @{ }
    $regex.Comment = "(?<![\\])#(?<comment>.*)"
    $regex.Include = "^#include\s+(?<include>[^\s#]+)\s*($($regex.Comment))?$"
    $regex.Heading = "^\s*\[(?<heading>[^\]]+)\]\s*($($regex.Comment))?$"
    $regex.Setting = "^\s*(?<name>[^\s=#]+)\s*(=\s*(?<value>([^#]|\\#)+|`"[^`"]*`"|'[^']*'))?\s*($($regex.Comment))?$"
    $regex.Entry   = "^\s*(?<entry>.+)\s*"
    $regex.Empty   = "^\s*($($regex.Comment))?$"  

    $linenum = 0
    $CurrentSection = $null
    foreach($line in $lines) {
        $linenum++
        switch -Regex ($line) {
            $regex.Include {
                if ($Verbose) {
                    write-host -ForegroundColor Green "Include: '$line'";
                    Write-Host "------[Start:$($Matches.include)]".PadRight(80, "-")
                }
                if ($NoInclude) { continue }
                if ($MetaData) { $MetaData.includes += $Matches.include }
                
                $includePath = $Matches.include

                try {
                    
                    $parseArgs = @{
                        Config=$conf;
                        MetaData=$MetaData;
                        IncludeRootPath=$IncludeRootPath;
                    }

                    if ($includePath -match "^[/\\]") {
                        $parseArgs.Path = "$IncludeRootPath${includePath}.ini" # Absolute path.
                    } else {
                        $parseArgs.Path = "$($Item.DirectoryName)\${includePath}.ini"; # Relative path.
                    }

                    if ($PSBoundParameters.ContainsKey("Verbose")) { $parseArgs.Verbose = $Verbose }
                    if ($PSBoundParameters.ContainsKey("NotStrict")) { $parseArgs.NotStrict = $NotStrict }
                    if ($PSBoundParameters.ContainsKey("Silent"))  { $parseArgs.Silent = $Silent }
                    
                    if ($Cache) {
                        $parseArgs.Remove("Config")
                        if ($Cache.ContainsKey($parseArgs.Path)) {
                            if ($Loud) { Write-Host "Found include file in the cache!" -ForegroundColor Green }
                            $ic = $Cache[$parseArgs.Path]
                        } else {
                            if ($Loud) { Write-Host "include file not found in the cache, parsing file..." -ForegroundColor Yellow }
                            $ic = Parse-ConfigFile @parseArgs
                            $Cache[$parseArgs.Path] = $ic
                        }
                        $conf = Merge-Configs $conf $ic
                    } else {
                        Parse-ConfigFile @parseArgs | Out-Null
                    }
                } catch {
                    if ($_.Exception -like "<InvalidPath>*") {
                        . $handleError -Message $_
                    } else {
                        . $handleError "An unknown exception occurred while parsing the include file at '$($Item.DirectoryName)\${includePath}.ini' (in root file '$Path'): $_"
                    }
                }

                if ($Verbose) {
                    Write-Host "------[End:$includePath]".PadRight(80, "-")
                }
                break;
            }
            $regex.Heading {
                if ($Verbose) {  write-host -ForegroundColor Green "Heading: '$line'"; }
                $CurrentSection = $Matches.Heading
                if (!$conf[$Matches.Heading]) {
                    $conf[$Matches.Heading] = @{ }
                } 
                break;
            }
            $regex.Setting {
                if (!$CurrentSection) {
                    . $handleError -Message "<OrphanSetting>Ecountered a setting before any headings were declared (line $linenum in '$Path'): '$line'"
                }

                if ($Verbose) { Write-Host -ForegroundColor Green "Setting: '$line'"; }
                $value = $Matches.Value -replace "\\#","#" # Strip escape character from literal '#'s
                if ($conf[$CurrentSection][$Matches.Name]) {
                    if ($conf[$CurrentSection][$Matches.Name] -is [Array]) {
                        if ( ($Matches.Name -in $duplicatesAllowed) -or (-not $conf[$CurrentSection][$Matches.Name].Contains($value)) ) {
                            $conf[$CurrentSection][$Matches.Name] += $value
                        }
                    } else {
                        $conf[$CurrentSection][$Matches.Name] = @( $conf[$CurrentSection][$Matches.Name], $value )
                    }
                } else {
                    $v = if ($value -eq $null) { "" } else { $value } # Convertion to match the behaviour of Read-Conf
                    $conf[$CurrentSection][$Matches.Name] = $v
                }
                break;
            }
            $regex.Empty   {
                if ($Verbose) {  Write-Host -ForegroundColor Green "Empty: '$line'"; }
                break;
            }
            default {
                . $handleError "<MalformedLine>Found an unrecognizable line (line $linenum in $path): $line"
                break;
            }
        }
    }

    if ($Cache) {
        $Cache[$Path] = $conf
    }

    return $conf
}

function Merge-Configs {
    param(
        [Paramater(Mandatory=$true, HelpMessage="Configuration 1, values from this object will appear first in the cases where values overlap.")]
        [ValidateNotNull()][hashtable]$C1,
        [Paramater(Mandatory=$true, HelpMessage="Configuration 1, values from this object will appear last in the cases where values overlap.")]
        [ValidateNotNull()][hashtable]$C2
    )

    $NC = @{}

    $C1.Keys | ? { $_ -and ($C1[$_] -is [hashtable]) } | % {
        $s = $_
        $NC[$s] = @{}
        $C1[$s].GetEnumerator() | % {
            $NC[$s][$_.Name] = $C1[$s][$_.Name]
        }
    }
    $C2.Keys | ? { $_ -ne $null -and ($C2[$_] -is [hashtable]) } | % {
        $s = $_
        if (!$NC.ContainsKey($s)) {
            $NC[$s] = @{}
        }
        $C2[$s].GetEnumerator() | % {
            $n = $_.Name
            $v = $_.Value
            
            if (!$NC[$s].ContainsKey($n)) {
                $NC[$s][$n] = $v
                return
            }

            if ($NC[$s][$n] -is [array]) {
                if ($v -isnot [array]) {
                    $NC[$s][$n] += $v
                    return 
                }

                $NC[$s][$n] = $NC[$s][$n] + $v | ? { $_ -ne $null }
            } else {
                if ($v -isnot [array]) {
                    $NC[$s][$n] = @($NC[$s][$n], $v)
                    return
                }

                $NC[$s][$n] = @($NC[$s][$n]) + $v
            }
        }
    }
    
    $NC
}