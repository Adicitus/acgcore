# Install-Chocolatey.ps1

function Install-Chcolatey() {
    $chocolateyDir = "$($env:ALLUSERSPROFILE)\chocolatey\bin"
    $chocolateyInstalled = $false
    if ($Env:Path -like "*$chocolateyDir*"){
        shoutOut "'$chocolateyDir' is in the system Path." Green
    } else {
        shoutOut "Adding '$chocolateyDir' to system Path... "
        [Environment]::SetEnvironmentVariable("Path", "$($Env:Path);$chocolateyDir")
        shoutOUt "Done!" green
    }
    shoutOut "Is Chocolatey installed... " -NoNewline
    if (!(test-Path "$chocolateyDir\choco.exe")) {
        shoutOut "No!" Red
        shoutout "Installing Chocolatey..." Cyan
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    } else {
        shoutOut "Yes! (Probably)" Green
    }
}