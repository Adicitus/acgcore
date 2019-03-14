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

function _ensureShoutOutLogFile {
    param(
        [string]$logFile,
        [string]$MsgType
    )

    if (!(Test-Path $logFile -PathType Leaf)) {
        $logDir = Split-Path $logFile -Parent
        try {
            return new-Item $logFile -ItemType File
        } catch {
            "Unable to create log file '{0}' for '{1}'." -f $logFile, $msgType | shoutOut -MsgType Error
            "Messages marked with '{0}' will be redirected." -f $msgType | shoutOut -MsgType Error
            shoutOut $_
            throw $_
        }
    }

    return gi $logFile
}

function _ensureshoutOutLogHandler {
    param(
        [scriptblock]$logHandler,
        [string]$msgType
    )

    $params = $logHandler.Ast.ParamBlock.Parameters

    if ($params.count -eq 0) {
        "Invalid handler, no parameters found: {0}" -f $logHandler | shoutOut -MsgType Error
        "Messages marked with '{0}' will not be redirected using this handler." -f $msgType | shoutOut -MsgType Error
        throw "No parameters declared by the givn handler."
    }

    $paramName = '$message'
    $param = $params | ? { $_.Name.Extent.Text -eq $paramName }

    if (!$param) {
        "Invalid handler, no '{0}' parameter found" -f $paramName | shoutOut -MsgType Error
        "Messages marked with '{0}' will not be redirected using this handler." -f $msgType | shoutOut -MsgType Error
        throw "No 'message' parameter declared by handler."
    }

    if (($t = $param.StaticType) -and !($t.IsAssignableFrom([String])) ) {
        "Invalid handler, the '{0}' parameter should accept values of type String." -f $paramName | shoutOut -MsgType Error
        "Messages marked with '{0}' will not be redirected using this handler." -f $msgType | shoutOut -MsgType Error
        throw "Message parameter is of invalid type (not assignable from [string])."
    }

    return $logHandler
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
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)][string]$msgType,
        [Parameter(ParameterSetName="StringPath", Mandatory=$true)][string]$LogFile,
        [Parameter(ParameterSetName="Scriptblock", Mandatory=$true)][scriptblock]$LogHandler
    )


    $log = $null
    switch ($PSCmdlet.ParameterSetName) {
    "Scriptblock" {
        $params = $logHandler.Ast.ParamBlock.Parameters

        if ($params.count -eq 0) {
            "Invalid handler, no parameters found: {0}" -f $logHandler | shoutOut -MsgType Error
            "Messages marked with '{0}' will not be redirected using this handler." -f $msgType | shoutOut -MsgType Error
            return
        }

        $paramName = '$message'
        $param = $params | ? { $_.Name.Extent.Text -eq $paramName }

        if (!$param) {
            "Invalid handler, no '{0}' parameter found" -f $paramName | shoutOut -MsgType Error
            "Messages marked with '{0}' will not be redirected using this handler." -f $msgType | shoutOut -MsgType Error
            return
        }

        if (($t = $param.StaticType) -and !($t.IsAssignableFrom([String])) ) {
            "Invalid handler, the '{0}' parameter should accept values of type String." -f $paramName | shoutOut -MsgType Error
            "Messages marked with '{0}' will not be redirected using this handler." -f $msgType | shoutOut -MsgType Error
            return
        }
        $log = $LogHandler
        break
    }
    "StringPath" {
            if (!(Test-Path $logFile -PathType Leaf)) {
                $logDir = Split-Path $logFile -Parent
                try {
                    new-Item $logFile -ItemType File | Out-Null
                } catch {
                    "Unable to create log file '{0}' for '{1}'." -f $logFile, $msgType | shoutOut -MsgType Error
                    "Messages marked with '{0}' will be redirected." -f $msgType | shoutOut -MsgType Error
                    shoutOut $_
                    return $_
                }

            }

            $log = $LogFile
        }
    }

    $oldLog = $_ShoutOutSettings.LogFile
    if ($_ShoutOutSettings.LogFileRedirection.ContainsKey($msgType)) {
        $oldLog = $_ShoutOutSettings.LogFileRedirection[$msgType]
    }
    "Redirecting messages of type '{0}' to '{1}'." -f $msgType, ($log | Out-String) | shoutOut -MsgType $msgType
    $_ShoutOutSettings.LogFileRedirection[$msgType] = $log
    "Messages of type '{0}' have been redirected to '{1}'." -f $msgType, $log | shoutOut -MsgType $msgType
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
		[parameter(Mandatory=$false, position=3)]$Log=$null,
		[parameter(Mandatory=$false, position=4)][Int32]$ContextLevel=1, # The number of levels to proceed up the call
                                                                         # stack when reporting the calling script.
        [parameter(Mandatory=$false)] [bool] $LogContext = (
            !$_ShoutOutSettings.ContainsKey("LogContext") -or ($_ShoutOutSettings.ContainsKey("LogContext") -and $_ShoutOutSettings.LogContext)
        ),
        [parameter(Mandatory=$false)] [Switch] $NoNewline,
        [parameter(Mandatory=$false)] [Switch] $Quiet
	)
    
    process {
        $defaultLogHandler = { param($msg) $msg | Out-File $Log -Encoding utf8 -Append }

        # Apply global settings.
        if ( ( $settingsV = Get-Variable "_ShoutOutSettings" ) -and ($settingsV.Value -is [hashtable]) ) {
            $settings = $settingsV.Value
            if (!$MsgType -and $settings.containsKey("DefaultMsgType")) { $MsgType = $settings.DefaultMsgType }
            if (!$Log -and $settings.containsKey("LogFile")) { $Log = $settings.LogFile }
            if ($settings.LogFileRedirection.ContainsKey($MsgType)) { $Log = $settings.LogFileRedirection[$MsgType] }
            
            if ($settings.containsKey("MsgStyles") -and ($settings.MsgStyles -is [hashtable]) -and $settings.MsgStyles.containsKey($MsgType)) {
                $msgStyle = $settings.MsgStyles[$MsgType]
            }
        }

        # Hard-coded defaults just in case.
        if (!$MsgType) { $MsgType = "Information" }
        if (!$Log) { $Log = ".\setup.log" }
        
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

        $createRecord = {
            param($m)
            "{0}|{1}|{2}|{3}|{4:yyyyMMdd-HH:mm:ss}|{5}" -f $MsgType, $env:COMPUTERNAME, $pid, $parentContext, [datetime]::Now, $m
        }

        $record = . $createRecord $Message

        if ($log -is [scriptblock])  {
            try {
                . $Log -Message $record
            } catch {
                $errorMsgRecord1 = . $createRecord ("An error occurred while trying to log a message to '{0}'" -f ( $Log | Out-String))
                $errorMsgRecord2 = . $createRecord "The following is the record that would have been written:"
                $Log = "{0}\shoutOut.error.{1}.{2}.{3:yyyyMMddHHmmss}.log" -f $env:APPDATA, $env:COMPUTERNAME, $pid, [datetime]::Now
                $errorRecord = . $createRecord ($_ | Out-String)
                . $defaultLogHandler $errorMsgRecord1
                . $defaultLogHandler $errorRecord
                . $defaultLogHandler $errorMsgRecord2
                . $defaultLogHandler $record
            }
        } else {
            . $defaultLogHandler $record
        }
        
    }
}