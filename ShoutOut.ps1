# ShoutOut.ps1

if ( !(Get-variable "_ShoutOutSettings" -ErrorAction SilentlyContinue) -or $script:_ShoutOutSettings -isnot [hashtable]) {
    $script:_ShoutOutSettings = @{
        DefaultMsgType="Info"
        LogFile="C:\temp\shoutOut.{0}.{1}.{2:yyyyMMddHHmmss}.log" -f $env:COMPUTERNAME, $pid, [datetime]::Now
        LogFileRedirection=@{}
        MsgStyles=@{
            Exception =     @{ ForegroundColor="Red"; BackgroundColor="Black" }
            Error =         @{ ForegroundColor="Red" }
            Warning =       @{ ForegroundColor="Yellow"; BackgroundColor="Black" }
            Info =          @{ ForegroundColor="Cyan" }
            Result =        @{ ForegroundColor="White" }
        }
        LogContext=$true
    }
}

function Set-ShoutOutConfig {
  param(
    $DefaultMsgType,
    $LogFile,
    $LogContext
  )
  
  foreach( $k in $PSBoundParameters.Keys) {
    $t1 = $_shoutOutSettings[$k].GetType()
    $t2 = $PSBoundParameters[$k].GetType()
    if ($t1.IsAssignableFrom($t2)) {
        $_shoutOutSettings[$k] = $PSBoundParameters[$k]
    }
  }
}

function Get-ShoutOutConfig {
  return $_ShoutOutSettings
}

function Set-ShoutOutRedirect {
    param(
        [string]$msgType,
        [string]$logFile
    )

    if (!(Test-Path $logFile -PathType Leaf)) {
        $logDir = Split-Path $logFile -Parent
        try {
            new-Item $logFile -ItemType File | Out-Null
        } catch {
            "Unable to create log file '{0}' for '{1}'." -f $logFile, $msgType | shoutOut
            "Messages marked with '{0}' will be recorded in the default log file." -f $msgType | shoutOut
            shoutOut $_
            return $_
        }
    }

    $oldLogFile = $_ShoutOutSettings.LogFile
    if ($_ShoutOutSettings.LogFileRedirection.ContainsKey($msgType)) {
        $oldLogFile = $_ShoutOutSettings.LogFileRedirection[$msgType]
    }
    "Redirecting messages of type '{0}' to '{1}'." -f $msgType, $logFile | shoutOut -LogFile $oldLogFile
    $_ShoutOutSettings.LogFileRedirection[$msgType] = $logFile
    "Messages of type '{0}' have been redirected to '{1}'." -f $msgType, $logFile | shoutOut -LogFile $logFile
}

function Clear-ShoutOutRedirect {
    param(
        [string]$msgType
    )

    if ($_ShoutOutSettings.LogFileRedirection.ContainsKey($msgType)) {
        $l = $_ShoutOutSettings.LogFileRedirection[$msgType]
        "Removing message redirection for '{0}', messages of this type will be logged in the default log file ('{1}')." -f $msgType, $_ShoutOutSettings.LogFile | shoutOut -LogFile $l
        $_ShoutOutSettings.LogFileRedirection.Remove($msgType)
        "Removed message redirection for '{0}', previously messages were written to '{1}'." -f $msgType, $l | shoutOut
    }
}

# First-things first: Logging function (is the realest, push the message and let the harddrive feel it.)
function shoutOut {
	param(
        [parameter(Mandatory=$false,  position=1, ValueFromPipeline=$true)] [Object]$Message,
        [Alias("ForegroundColor")]
		[parameter(Mandatory=$false, position=2)][String]$MsgType=$null,
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
            if (!$MsgType -and $settings.containsKey("DefaultMsgType")) { $MsgType = $settings.DefaultMsgType }
            if (!$LogFile -and $settings.containsKey("LogFile")) { $LogFile = $settings.LogFile }
            if ($settings.LogFileRedirection.ContainsKey($MsgType)) { $logFile = $settings.LogFileRedirection[$MsgType] }
            
            if ($settings.containsKey("MsgStyles") -and ($settings.MsgStyles -is [hashtable]) -and $settings.MsgStyles.containsKey($MsgType)) {
                $msgStyle = $settings.MsgStyles[$MsgType]
            }
        }

        # Hard-coded defaults just in case.
        if (!$MsgType) { $MsgType = "Information" }
        if (!$LogFile) { $LogFile = ".\setup.log" }
        
        if (!$msgStyle) {
            if ($MsgType -in [enum]::GetNames([System.ConsoleColor])) {
                $msgStyle = @{ ForegroundColor=$MsgType }
            } else {
                $msgStyle = @{ ForegroundColor="White" }
            }
        }
        
        # Apply formatting to make output more readable.
        if ($Message -isnot [String]) {
            $message = $message | Out-String
        }

        $logDir = Split-Path $LogFile -Parent
        if (!(Test-Path $logDir)) {
            New-Item $logDir -ItemType Directory
        }

	    if ([Environment]::UserInteractive -and !$Quiet) {
            $p = @{
                Object = $Message
                NoNewline = $NoNewline
            }
            if ($msgStyle.ForegroundColor) { $p.ForegroundColor = $msgStyle.ForegroundColor }
            if ($msgStyle.BAckgroundColor) { $p.BackgroundColor = $msgStyle.BackgroundColor }

            Write-Host @p
        }
        
        $parentContext = if ($LogContext) {
            $cs = Get-PSCallStack
            $csd = @($cs).Length
            # CallStack Depth, should always be greater than or equal to 2. 1 would indicate that we
            # are running the directly on the command line, but since we are inside the shoutOut
            # function there should always be at least one level to the callstack in addition to the
            # calling context.
            switch ($csd) {
                2 { "[{0}]<commandline>" -f $csd }
                
                default {
                    $parentCall = $cs[$ContextLevel]
                    if ($parentCall.ScriptName) {
                        "[{0}]{1}:{2}" -f $csd, $parentCall.ScriptName,$parentCall.ScriptLineNumber
                    } else {
                        for($i = $ContextLevel; $i -lt $cs.Length; $i++) {
                            $level = $cs[$i]
                            if ($level.ScriptName) {
                                break;
                            }
                        }

                        if ($level.ScriptName) {
                            "[{0}]{1}:{2}\<scriptblock>" -f $csd, $level.ScriptName,$level.ScriptLineNumber
                        } else {
                            "[{0}]<commandline>\<scriptblock>" -f $csd
                        }
                    }
                }
            }
        } else {
            "[context logging disabled]"
        }
	    "{0}|{1}|{2}|{3}|{4:yyyyMMdd-HH:mm:ss}|{5}" -f $MsgType, $env:COMPUTERNAME, $pid, $parentContext, [datetime]::Now, $Message | Out-File $LogFile -Encoding utf8 -Append
    }
}