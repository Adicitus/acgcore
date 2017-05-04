
<#  V1.0
    Requires: shoutOut
    
    The input for this function should be hashtable like this:
    
    $settings = @{}
    $settings.switchName = "*Internal Virtual Network*"
    $settings.IPAddress = "10.10.10.9"
    $settings.DNSAddress = "10.10.10.10"
    $settings.defaultGateway = "10.10.10.10"
    $settings.prefixLength = 24

    All fields are currently mandatory and will be used by the function.

#>


function PatchNetwork(){
    
    param(
        [parameter(Mandatory=$true)] [Hashtable] $Settings
    )

    if (!$Settings.SwitchName -or !$Settings.IPAdress -or !$Settings.DNSAdress -or !$Settings.DefaultGateway -or !$Settings.PrefixLength) {
        shoutOut "One or more settings were not specified, exiting!"
        exit
    }

    shoutOut "Checking IP Configuration... (Looking for '$($settings.switchName)')"
    $address = Get-NetIPAddress -AddressFamily IPv4 | ? { $_.InterfaceAlias -like $settings.switchName }
    if ($address) {
        shoutOut "We have an adress for that network! (On interface '$($address.ifIndex)')"  Green
        shoutOut "Checking if the configuration is correct..." -NoNewline
        $netconfig = Get-NetIPConfiguration -InterfaceIndex $address.ifIndex
        if (($address.IPv4Address -ne $settings.IPAddress) -or
            ($netconfig.IPv4DefaultGateway -ne $settings.defaultGateway) -or
            ($address.PrefixLength -ne $settings.prefixLength)) {
            shoutOut "No!"  Red
            shoutOut "Reconfiguring interface..."
            shoutOut "Removing old configuration..."
            $address | Remove-NetIPAddress -Confirm
            shoutOut "Creating new configuration..."
            New-NetIPAddress -InterfaceIndex $address.ifIndex -IPAddress $settings.IPAddress -PrefixLength $settings.prefixLength
        } else {
            shoutOut "Yup! Looks good!"  Green
        }
        shoutOut "Checking if the default Gateway is set correctly..." -NoNewline
        $dfg = Get-NetRoute -InterfaceIndex $address.ifIndex -DestinationPrefix "0.0.0.0/0"
        if ($dfg.NextHop -ne $settings.defaultGateway) {
            shoutOut "No! (next hop is '$($dfg.NextHop)')"
            shoutOut "Changing the default gateway..."
            $dfg | Remove-NetRoute
            New-NetRoute -InterfaceIndex $address.ifIndex -DestinationPrefix "0.0.0.0/0" -NextHop $settings.defaultGateway
        } else {
            shoutOut "Yes!"  Green
        }
        shoutOut "Checking if we are using the correct DNS server..." -NoNewline
        $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -InterfaceIndex $address.ifIndex
        if ($dns) {
            $correct = $false
            foreach ($dnsAddress in $dns.ServerAddresses) {
                if ($dnsAddress -eq $settings.DNSAddress) {
                    $correct = $true
                    break
                }
            }
            if (!$correct) {
                shoutOut "Nope!"  Red
                shoutOut "Adding '10.10.10.10' to DNS server list for $($address.InterfaceAlias)"
                Set-DnsClientServerAddress -InterfaceIndex $address.ifIndex -ServerAddresses ($dns.ServerAddresses + "10.10.10.10")
            } else {
                shoutOut "Yup!"  Green
            }
        } else {
            shoutOut "No DNS server-list available for the interface!"  Red
            shoutOut "This should not be happening... Giving up!"
            pause
            exit
        }
    }

}