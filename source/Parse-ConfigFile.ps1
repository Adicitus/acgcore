<#
.SYNOPSIS
Parsing function used for ACGroup-style .ini configuration files.

.DESCRIPTION
Used to parse ACGroup-style .ini files.

Grammar: 
    file  -> <lines>
    lines -> <line> | <line><lines>
    line  -> <include> | <section header> | <declaration> | <comment> | <empty>
    include        -> is<comment>
    section header -> sh<comment>
    declarations   -> sd<comment> 
    comment        -> c
    empty          -> e

Terminals:
    is: Include Statement
        ^#include\s[^\s#]+

    sh: Section Header
        ^\s*\[[^\]]+\]

    sd: Setting Declaration
        ^\s*[^\s=#]+\s*(=\s*([^#]|\\#)+|`"[^`"]*`"|'[^']*')?

    c: Comment
        (?<![\\])#.*

    e: Empty line
        \s*

Additional Rules:
    - The first declaration of the file must be preceeded by a section header.
    - If more than one value is declared for a setting, they will be collected
      into an array.
    - All values will be read as strings and the application using the
      configuration must determine how to interpret the values.

.PARAMETER Path
The path to the configuration file.

.PARAMETER Content
Alternatively content to be parsed can be provided as a string.

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

.PARAMETER Cache
Hashtable used to cache the results of each file parsed. Useful to minimize
reads from disk when parsing multiple job files using the common includes.

.PARAMETER Loud
Causes the parser to output extra information to the console.

.PARAMETER duplicatesAllowed
Names of settings for which duplicate values are allowed.

By default, if there are two declarations of the same setting with the same value,
the second occurence of the value will be discarded. When a setting name is
specified here, the second occurrence will instead be appended to the list of
values for the setting.

.PARAMETER IncludeRootPath
The root path to use when resolving includes. If this value isn't provided
then it will default to the directory part of $Path.

Include-paths that start with '\' or '/' will use this value when resolving
where to look for the included file.

Paths that do not start with either '\' or '/' will use the directory of the
file currently being processed.

If the command is called using the "String" parameter set, then this value will
default to $pwd (current working directory).

All included files will be parsed using the same IncludeRootPath.

.EXAMPLE
Normal Read:
    $conf = Parse-Config "C:\Config.ini"

Accumulating information into a configuration hashtable:
    $conf = Parse-Config "C:\Config2.ini" $config

Skipping #include statements:
    $conf = Parse-Config "C:\Config.ini" -NoInclude

Stop the parser from throwing an exception on error (use MetaData object to record errors):
    $metadata = @{}
    $conf = Parse-Config "C:\Config.ini" -NotStrict -MetaData $metadata
    # Echo out the errors:
    $metadata.Errors | % { Write-Host $_ }

.NOTES
General notes
#>
function Parse-ConfigFile {
    [CmdletBinding(DefaultParameterSetName="File")]
    param (
        [parameter(
            Mandatory=$true,
            Position=1,
            ParameterSetName="File",
            HelpMessage="Path to the file."
        )] [String] $Path,              # Name of the job-file to parse (including extension)
        [parameter(
            Mandatory=$true,
            Position=1,
            ParameterSetName="String",
            HelpMessage="Content to be parsed instead of reading from the file path. If this option is used and the path is not an actual file path, then 'IncludeRootPath' MUST be specified. Path must be specified regardless."
        )] [string]$Content,
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
        [Parameter(
            Mandatory=$false,
            HelpMessage='Hashtable used to cache includes to minimize reads from disk when rapidly parsing multiple files using common includes.'
        )][Hashtable] $Cache,
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
    

    switch ($PSCmdlet.ParameterSetName) {
    
        "File" {
            if( $Path -and ([System.IO.File]::Exists($Path)) ) {
                $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
            } else {
                . $handleError -Message "<InvalidPath>The given path doesn't lead to an existing file: '$Path'"
                return
            }

            $currentDir = [System.IO.Directory]::GetParent($Path)

        }

        "String" {
            $lines = $Content -split "`n"
            $currentDir = "$pwd"
        }
    }

    if (!$PSBoundParameters.ContainsKey("IncludeRootPath")) {
        $IncludeRootPath = $currentDir
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
   
                $parseArgs = @{
                    Config=$conf;
                    MetaData=$MetaData;
                    Cache=$Cache
                    IncludeRootPath=$IncludeRootPath;
                }

                if ($includePath -match "^[/\\]") {
                    $parseArgs.Path = "$IncludeRootPath${includePath}.ini" # Absolute path.
                } else {
                    $parseArgs.Path = "$currentDir\${includePath}.ini"; # Relative path.
                }

                if ($PSBoundParameters.ContainsKey("Verbose")) { $parseArgs.Verbose = $Verbose }
                if ($PSBoundParameters.ContainsKey("NotStrict")) { $parseArgs.NotStrict = $NotStrict }
                if ($PSBoundParameters.ContainsKey("Silent"))  { $parseArgs.Silent = $Silent }

                try {

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
                        $conf = Merge-Configs $conf $ic -duplicatesAllowed $duplicatesAllowed
                    } else {
                        Parse-ConfigFile @parseArgs | Out-Null
                    }
                    
                } catch {
                    if ($_.Exception -like "<InvalidPath>*") {
                        . $handleError -Message $_
                    } else {
                        . $handleError "An unknown exception occurred while parsing the include file at '$($parseArgs.Path)' (in root file '$Path'): $_"
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
                    $v = if ($null -eq $value) { "" } else { $value } # Convertion to match the behaviour of Read-Conf
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
        [Parameter(Mandatory=$true,  HelpMessage="Configuration 1, values from this object will appear first in the cases where values overlap.")]
        [ValidateNotNull()][hashtable]$C1,
        [Parameter(Mandatory=$true,  HelpMessage="Configuration 2, values from this object will appear last in the cases where values overlap.")]
        [ValidateNotNull()][hashtable]$C2,
        [parameter(Mandatory=$false, HelpMessage="Array of settings for which values can be duplicated.")]
        [array] $duplicatesAllowed = @("Operation","Pre","Post")
    )

    $combineValues = {
        param($n, $v1, $v2)

        $da = $n -in $duplicatesAllowed

        if ($v1 -is [array]) {
            if ($v2 -isnot [array]) {
                if (!$da -and ($v2 -in $v1)) {
                    return $v1
                }
                return $v1 + $v2
            } else {
                $v = $v1
                $v2 | Where-Object {
                    $da -or $_ -notin $v
                } | ForEach-Object {
                    $v += $_
                }
                return $v
            }
        } else {
            if ($v2 -isnot [Array] ) {
                if (!$da -and $v1 -eq $v2) {
                    return $v1
                }
                return @($v1, $v2)
            } else {
                $v = @($v1)
                $v2 | Where-Object {
                    $da -or $_ -notin $v
                } | ForEach-Object { $v += $_ }
                return $v
            }
        } 
    }

    $NC = @{}

    $C1.Keys | Where-Object {
        $_ -and ($C1[$_] -is [hashtable])
    } | ForEach-Object {
        $s = $_
        $NC[$s] = @{}
        $C1[$s].GetEnumerator() | ForEach-Object {
            $NC[$s][$_.Name] = $C1[$s][$_.Name]
        }
    }
    $C2.Keys | Where-Object {
        $_ -ne $null -and ($C2[$_] -is [hashtable])
    } | ForEach-Object {
        $s = $_
        if (!$NC.ContainsKey($s)) {
            $NC[$s] = @{}
        }
        $C2[$s].GetEnumerator() | ForEach-Object {
            $n = $_.Name
            $v = $_.Value

            if (!$NC[$s].ContainsKey($n)) {
                $NC[$s][$n] = $v
                return
            }

            $NC[$s][$n] = . $combineValues $n $NC[$s][$n] $v
        }
    }
    
    return $NC
}