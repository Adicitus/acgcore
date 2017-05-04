function Parse-ConfigFile() {
    param(
        [Parameter(Mandatory=$true)]  [String] $Path,
        [Parameter(Mandatory=$false)] [Hashtable] $Config = @{},
        [Parameter(Mandatory=$false)] [Switch] $NoInclude
       #[Parameter(Mandatory=$false)] [Switch] $Verbose # Common parameter.
    )

    if (-not (Test-Path $Path -PathType Leaf)) {
        write-host "Parse-ConfigFile wants you to know that this path " -ForegroundColor Red
        Write-Host "`t'$Path'"
        write-host "does not lead to an existing file." -ForegroundColor Red

        return $false
    }

    $PathItem = Get-ChildItem $Path

    $lines = Get-Content $Path
    $section = $null
    $lineNum = 0

    $regex = @{}
    $regex.Comment   = "#.*$"
    $regex.Section   = "\s*\[(?<title>[^\]]+)\](\s*$($regex["Comment"]))?"
    $regex.Include   = "^#include\s+(?<include>[a-z0-9\-_]+)(\s+$($regex["Comment"]))?"
    $regex.Directive = "^\s*(?<name>[a-z09\-_]+)(=\s*(?<value>[^#]+|`".*`"|'.*'))?(\s*$($regex["Comment"]))?"
    $regex.Empty     = "^\s*($($regex["Comment"]))?$"

    foreach($line in $lines) {
        $lineNum++
        switch -Regex ($line){
            $regex.Include   {
                write-host -ForegroundColor Green "Include: '$line'"
                $includePath = "$($PathItem.DirectoryName)\$($Matches.include).ini"
                if (Test-Path $includePath -PathType Leaf){
                    if ($NoInclude) {
                        write-host "File found, but `$NoInclude flag is set so I'm ignoring it..."
                    } else {
                        Parse-ConfigFile -Path $includePath -Config $Config | Out-Null
                    }
                } else {
                    write-host -ForegroundColor Red "Include-file is missing!: " -NoNewline
                    write-host -ForegroundColor Green "'$includePath'"
                }
                break
            }

            $regex.Section {
                write-host -ForegroundColor Green "Section: '$line'"
                $section = $Matches.title
                if (!($Config[$section])) { $Config[$section] = @{} }
                break
            }

            $regex.Directive {
                write-host -ForegroundColor Green "Directive: '$line'"
                if (!$section) { 
                    write-host -ForegroundColor Red "No section has been declared!"
                    break
                }
                $name = $Matches.name
                $new_value = $Matches.value # This value may be blank

                if ($v = $Config[$section][$name]) {
                    if ($new_value -eq $null ) { break } # No point storing NULL values.
                    if ($v -is [Array]) {
                        if (!($v | ? { $_ -eq  $new_value })) { # Only keep unique entries
                            $Config[$section][$name] +=  $new_value
                        }
                    }
                    else {
                        if ($v -ne $new_value) { # No Duplicates
                            $Config[$section][$name] = @($v,  $new_value)
                        }
                    }
                } else {
                    $Config[$section][$name] = $new_value
                }
                break
            }

            $regex.Empty {
                write-host -ForegroundColor Green "Empty: '$line'"
                break
            }

            default {
                write-host -ForegroundColor Red "A line was not understood by Parse-ConfigFile: '$line'"
            }
        }
    }
    return $Config
}

