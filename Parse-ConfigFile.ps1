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
    Include -> #\include\s+(?<jobname>[a-zA-Z0-9]+)
    Comment -> \s*#.*
    Empty 	-> 
#>

function Parse-ConfigFile {
    param (
        [parameter(Mandatory=$true, Position=1)] [String]$Path,              # Name of the job-file to parse (including extension)
        [parameter(Mandatory=$false, Position=2)] [Hashtable]$Config = @{},  # Pre-existing configuration, if given we'll simply add to this one.
        [parameter(Mandatory=$false)] [Switch] $NoInclude,                   # Tells the parser to skip any include statements
        [Parameter(Mandatory=$false)] [Switch] $NotStrict,                   # Tells the parser to not generate any exceptions.
        [Parameter(Mandatory=$false)] [Switch] $Silent,                      # Supresses all commandline-output from the parser.
        [parameter(Mandatory=$false)] [Hashtable] $MetaData,                 # Hashtable used to capture MetaData while parsing.
                                                                             # This will record Includes as '$MetaData.includes'.
        [parameter(Mandatory=$false)] [Switch] $Loud,                        # Equivalent of $Verbose
        [parameter(Mandatory=$false)] [array]
        $duplicatesAllowed = @("Operation","Pre","Post"),                    # Declarations for which duplicate values are allowed.
        [parameter(Mandatory=$false)] [string]$IncludeRootPath               # The root directory used to resolve includes.
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

                    Parse-ConfigFile @parseArgs | Out-Null
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

    return $conf
}