# ShoutOut.ps1

if ( !(Get-variable "_ShoutOutSettings" -ErrorAction SilentlyContinue) -or $script:_ShoutOutSettings -isnot [hashtable]) {
    $script:_ShoutOutSettings = @{
        ForegroundColor="White"
        LogFile=".\shoutOut.log"
    }
}

# First-things first: Logging function (is the realest, push the message and let the harddrive feel it.)
function shoutOut {
	param(
		[parameter(Mandatory=$true,  position=1)] [Object]$Message,
		[parameter(Mandatory=$false, position=2)][String]$ForegroundColor=$null,
		[parameter(Mandatory=$false, position=3)][String]$LogFile=$null,
		[parameter(Mandatory=$false, position=4)][Int32]$ContextLevel=1, # The number of levels to proceed up the call
                                                                         # stack when reporting the calling script.
        [parameter(Mandatory=$false)] [Switch] $NoNewline,
		[parameter(Mandatory=$false)] [Switch] $Quiet
	)

    if ( ( $settingsV = Get-Variable "_ShoutOutSettings" ) -and ($settingsV.Value -is [hashtable]) ) {
        $settings = $settingsV.Value
        if (!$ForegroundColor -and $settings.containsKey("ForegroundColor")) { $ForegroundColor = $settings.ForegroundColor }
        if (!$LogFile -and $settings.containsKey("LogFile")) { $LogFile = $settings.LogFile }
    }

    if (!$ForegroundColor) { $ForegroundColor = "White" }
    if (!$LogFile) { $LogFile = ".\setup.log" }
	
    if ($Message -isnot [String]) {
        $message = $message | Out-String
    }

	if (!$Quiet) { Write-Host -ForegroundColor $ForegroundColor -Object $Message -NoNewline:$NoNewline }
    
    $parentCall = (Get-PSCallStack)[$ContextLevel]
	"$($env:COMPUTERNAME)|$($parentCall.ScriptName):$($parentCall.ScriptLineNumber)@$(Get-Date -Format 'MMdd-HH:mm.ss'): $Message" >> $LogFile
}