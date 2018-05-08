. "$PSScriptRoot\ShoutOut.ps1"

function Install-Feature ($featureName){
    
    if ( (Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue) -and ($r = Get-WindowsFeature -Name $featureName) ) {
        shoutOut "Using Server Manager... " Cyan -NoNewline
        if (!$r.Installed) {
            shoutOut "Installing..." Cyan
            $result = { Install-WindowsFeature -Name $featureName -IncludeAllSubFeature -IncludeManagementTools } | Run-Operation
            shoutOut "Outcome: $($result.ExitCode)"

            if ($result.RestartNeeded -ne "No") {
                shoutOut "Restarting to complete the installation..."
                shutdown /r /t 0
                exit
            }
        } else {
            shoutOut "Already Installed!" Green
            shoutOut "InstallState: " Cyan -NoNewline
            shoutOut $r.InstallState
            if ($r.InstallState -eq "InstallPending") {
                shoutOut "Restarting to complete the installation"
            }
        }
    } else {
        shoutOut "Using DISM..." Cyan -NoNewline
        $r = { dism /online /get-FeatureInfo /FeatureName:$featureName } | Run-Operation

        if ($r -match "Error: (?<error>0x[0-9a-f]+)") {
            shoutOut "An error ($($Matches.Error)) occured while trying to inspect '$featureName' using dism!" Red
        } else {

            if ($r -match "^State : Disabled") {
                shoutOut "Installing..." Cyan
                $r = { dism /online /Enable-Feature /FeatureName:$featureName /All /NoRestart } | Run-Operation
                shoutOut "Done!"
                if ($r -match "^Restart Windows") {
                    shoutOut "Restarting to complete the installation..."
                    shutdown /r /t 0
                    exit
                }
            } else {
                shoutOut "Already Installed!" Green
            }
        }
    }
}