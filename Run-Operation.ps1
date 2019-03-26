
<#
.WISHLIST
    - Update so that that output is fed to shoutOut as it is generated rather than using the result output.
      The goal is to generate logging data continuously so that it's clear whether the script has hung or not.
      [Done]
.SYNOPSIS
    Helper function to execute commands (strings or blocks) with error-handling/reporting.
.NOTES
   - Transforms ScriptBlocks to Strings prior to execution because of a quirk in iex where it will not allow the
     evaluation of ScriptBlocks without an input (a 'param' statement in the block). iex is used because it yields
     output as each line is evaluated, rather than waiting for the entire $OPeration to complete as would be the
     case with <ScriptBlock>.Invoke().
#>
function Run-Operation {
    param(
        [parameter(ValueFromPipeline=$true, position=1)] $Operation,
        [parameter()][Switch] $OutNull,
        [parameter()][Switch] $NotStrict
    )
    $color = "White"
    
    shoutOut "Running '$Operation'..." Cyan -ContextLevel 2
    
    if (!$NotStrict) {
        # Switch error action preference to catch any errors that might pop up.
        # Works so long as the internal operation doesn't also change the preference.
        $OldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    }

    $r = try {
        if ($Operation -is [scriptblock]) {
            # Under certain circumstances the iex cmdlet will not allow
            # the evaluation of ScriptBlocks without an input. However it will evaluate strings
            # just fine so we perform the transformation before evaluation.
            $Operation = $Operation.ToString()
        }
        Invoke-Expression $Operation | % { shoutOut "`t| $_" $color -ContextLevel 3; $_ } # Invoke-Expression allows us to receive
                                                                            # and handle output as it is generated,
                                                                            # rather than wait for the operation to finish
                                                                            # as opposed to <[scriptblock]>.invoke().
    } catch {
        $color = "Red"
        $_ | % { shoutOut "`t| $_" $color -ContextLevel 3 }
        $_
    }

    if (!$NotStrict) {
        $ErrorActionPreference = $OldErrorActionPreference
    }

    if ($OutNull) {
        return
    }
    return $r
}