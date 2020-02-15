function get-Features() {
    ShoutOut "Checking out feature list..."
    $features = @{ }
    dism -online -get-features -format:table | 
	    ?{ $_ -match "^(?<feature>[^\s]+)\s+\|\s*(?<status>Enabled|Disabled).*$" } |
	    %{ $features[$Matches.feature] = ($Matches.status -eq "Enabled") }
    return $features
}