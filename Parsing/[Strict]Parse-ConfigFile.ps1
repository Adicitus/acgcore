<# [Strict]Parse-ConfigFile.ps1
    An attempt to recreate the Deploy job-file parser in a strict fail-fast manner.
#>

function Parse-ConfigFile {
    param (
        [parameter(Mandatory=$true, Position=1)] [String]$Path,              # Name of the job-file to parse (including extension)
        [parameter(Mandatory=$false, Position=2)] [Hashtable]$Config = @{},  # Pre-existing configuration, if given we'll simply add to this one.
        [parameter(Mandatory=$false)] [Switch] $NoInclude,                   # Tells the parser to skip any include statements
        [Parameter(Mandatory=$false)] [Switch] $NotStrict,                   # Tells the parser to not generate any exceptions.
        [Parameter(Mandatory=$false)] [Switch] $Silent,                      # Supresses all commandline-output from the parser.
        [parameter(Mandatory=$false)] [Hashtable] $MetaData                  # Hashtable used to capture MetaData while parsing.
                                                                             # This will record Includes as '$MetaData.includes'.
    )
	
    function Handle-Error(){
        param(
            [parameter(Mandatory=$true)]  [String]    $Message,
            [parameter(Mandatory=$false)] [Hashtable] $MetaData,
            [parameter(Mandatory=$false)] [Switch] $NotStrict,
            [parameter(Mandatory=$false)] [Switch] $Silent
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

    $Verbose = if ($PSBoundParameters.Verbose -and !$Silent) { $true } else { $false }
	
    if($Path -and (Test-Path $Path -PathType Leaf)) {
        $lines = Get-Content $Path
    } else {
        if (!$Silent) { 
            Write-Host -ForegroundColor Red "This path:"
            Write-Host "`t'$Path'"
            Write-Host -ForegroundColor Red "does not lead to an existing file."
        }

        # Handle-Error -Message "<InvalidPath>The given path doesn't lead to an existing file: '$Path'" -MetaData $MetaData -NotStrict:$NotStrict -Silent:$Silent
        if (!$NotStrict) {
            throw "<InvalidPath>The given path doesn't lead to an existing file: '$Path'"
        } else {
            return # We can't continue from here!
        }
    }

    $Item = Get-Item $Path

    $conf = @{}
    if ($Config) { # Protect against NULL-values.
        $conf = $Config
    }

    if ($MetaData) {
        if (!$MetaData.Includes) { $MetaData.Includes = @() }
        if (!$MetaData.Errors)   { $MetaData.Errors = @() }
    }
    
    $regex = @{ }
    $regex.Comment = "#(?<comment>.*)"
    $regex.Include = "^#include\s+(?<include>[^\s]+)(\s+$($regex.Comment))?$"
    $regex.Heading = "^\s*\[(?<heading>[^\]]+)\](\s$($regex.Comment))?$"
    $regex.Setting = "^\s*(?<name>[^\s=#]+)\s*(=(?<value>[^#]+|`"[^`"]*`"|'[^']*'))?(\s*$($regex.Comment))?$" 
    $regex.Empty   = "^\s*($($regex.Comment))?$"  

    $linenum = 0
    $CurrentSection = $null
    foreach($line in $lines) {
        $linenum++
        switch -Regex ($line) {
            $regex.Include {
                if ($Verbose) {
                    write-host -ForegroundColor Green "Include: '$line'";
                    Write-Host ("-"*7+"$($Matches.include):"+"-"*(72-$Matches.include.Length))
                }
                if ($NoInclude) { continue }
                if ($MetaData) { $MetaData.includes += $Matches.include }
                try {
                    Parse-ConfigFile -Path "$($Item.DirectoryName)\$($Matches.include).ini" -Config $conf -Verbose:($Verbose) -NotStrict:($NotStrict) -Silent:($Silent) | Out-Null
                } catch {
                    if ($_.Exception -like "<InvalidPath>*") {
                        if ($Verbose) { write-host -ForegroundColor Red "The given path is does not lead to an existing file: '$Path'" }
                        if (!$NotStrict) { throw $_ } # This is not a valid Job-file anymore. Abort!
                    } else {
                        if (!$Silent) {
                            Write-Host -ForegroundColor Red "An unknown exception occurred while parsing the include file at:"
                            write-host "`t'$($Item.FullName)'"
                        }
                        if (!$NotStrict) { throw $_ } # I don't know what this is, let the caller sort it out.
                    }
                }

                if ($Verbose) {
                    Write-Host ("-"*6+"`\$($Matches.include)"+"-"*(73-$Matches.Include.Length))
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
                    if (!$Silent) {
                        Write-Host -ForegroundColor Red "Ecountered a setting before any headings were declared (line $linenum):" -NoNewline
                        Write-Host "'$line'"
                        Write-Host -ForegroundColor Red "While Parsing: "
                        Write-Host "'$Path'"
                    }
                    if (!$NotStrict) { throw "<OrphanSetting>The parser discovered an orphaned setting on line $linenum`: $Path" }
                }
                
                if ($Verbose) { Write-Host -ForegroundColor Green "Setting: '$line'"; }
                if ($conf[$CurrentSection][$Matches.Name]) {
                    if ($conf[$CurrentSection][$Matches.Name] -is [Array]) {
                        if (-not $conf[$CurrentSection][$Matches.Name].Contains($Matches.Value)) {
                            $conf[$CurrentSection][$Matches.Name] += $Matches.Value
                        }
                    } else {
                        $conf[$CurrentSection][$Matches.Name] = @( $conf[$CurrentSection][$Matches.Name], $Matches.Value )
                    }
                } else {
                    $conf[$CurrentSection][$Matches.Name] = $Matches.Value
                }
                break;
            }
            $regex.Empty   {
                if ($Verbose) {  Write-Host -ForegroundColor Green "Empty: '$line'"; }
                break;
            }
            default {
                if (!$Silent) {
                    Write-Host -ForegroundColor Red "Unrecognized: " -NoNewline
                    Write-Host "'$line'"
                }
                if (!$NotStrict) { throw "<MalformedLine>Found an unrecognizable line (line $linenum): $line" }
                break;
            }
        }
    }

    return $conf
}