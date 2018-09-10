# ShoutOut.ps1

if ( !(Get-variable "_ShoutOutSettings" -ErrorAction SilentlyContinue) -or $script:_ShoutOutSettings -isnot [hashtable]) {
    $script:_ShoutOutSettings = @{
        ForegroundColor="White"
        LogFile="C:\temp\shoutOut.$env:COMPUTERNAME.$pid.log"
        LogContext=$true
    }
}

# First-things first: Logging function (is the realest, push the message and let the harddrive feel it.)
function shoutOut {
	param(
		[parameter(Mandatory=$false,  position=1, ValueFromPipeline=$true)] [Object]$Message,
		[parameter(Mandatory=$false, position=2)][String]$ForegroundColor=$null,
		[parameter(Mandatory=$false, position=3)][String]$LogFile=$null,
		[parameter(Mandatory=$false, position=4)][Int32]$ContextLevel=1, # The number of levels to proceed up the call
                                                                         # stack when reporting the calling script.
        [parameter(Mandatory=$false)] [bool] $LogContext = (
            !$_ShoutOutSettings.ContainsKey("LogContext") -or ($_ShoutOutSettings.ContainsKey("LogContext") -and $_ShoutOutSettings.LogContext)
        ),
        [parameter(Mandatory=$false)] [Switch] $NoNewline,
		[parameter(Mandatory=$false)] [Switch] $Quiet
	)
    
    process {
        # Apply global settings.
        if ( ( $settingsV = Get-Variable "_ShoutOutSettings" ) -and ($settingsV.Value -is [hashtable]) ) {
            $settings = $settingsV.Value
            if (!$ForegroundColor -and $settings.containsKey("ForegroundColor")) { $ForegroundColor = $settings.ForegroundColor }
            if (!$LogFile -and $settings.containsKey("LogFile")) { $LogFile = $settings.LogFile }
        }

        # Hard-coded defaults just in case.
        if (!$ForegroundColor) { $ForegroundColor = "White" }
        if (!$LogFile) { $LogFile = ".\setup.log" }
        # Apply formatting to make output more readable.
        if ($Message -isnot [String]) {
            $message = $message | Out-String
        }

        $logDir = Split-Path $LogFile -Parent
        if (!(Test-Path $logDir)) {
            New-Item $logDir -ItemType Directory
        }

	    if ([Environment]::UserInteractive -and !$Quiet) { Write-Host -ForegroundColor $ForegroundColor -Object $Message -NoNewline:$NoNewline }
        
        $parentContext = if ($LogContext) {
            $cs = Get-PSCallStack
            switch ($cs.Length) {
                2 { "<commandline>" }
                
                default {
                    $parentCall = $cs[$ContextLevel]
                    if ($parentCall.ScriptName) {
                        "{0}:{1}" -f $parentCall.ScriptName,$parentCall.ScriptLineNumber
                    } else {
                        for($i = $ContextLevel; $i -lt $cs.Length; $i++) {
                            $level = $cs[$i]
                            if ($level.ScriptName) {
                                break;
                            }
                        }

                        if ($level.ScriptName) {
                            "{0}:{1}\<scriptblock>" -f $level.ScriptName,$level.ScriptLineNumber
                        } else {
                            "<commandline>\<scriptblock>"
                        }
                    }
                }
            }
        } else {
            "[context logging disabled]"
        }
	    "$($env:COMPUTERNAME)|$parentContext@$(Get-Date -Format 'MMdd-HH:mm.ss'): $Message" | Out-File $LogFile -Encoding utf8 -Append
    }
}