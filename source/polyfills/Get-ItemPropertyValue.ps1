# Polyfill to ensure Get-ItemPropertyValue is available on older OS.
if (!(Get-Command "Get-ItemPropertyValue" -ErrorAction SilentlyContinue )) {
    function Get-ItemPropertyValue {
        [CmdletBinding()]
        param(
            [paramater(
                Position=0,
                ParameterSetName="Path",
                Mandatory=$false,
                ValueFromPipeLine=$true,
                ValueFromPipelineByPropertyName=$true,
                ValueFromRemainingArguments=$false,
                DontShow=$false
            )]
            [ValidateNotNullOrEmpty()]
            [string[]]$Path,
            [paramater(
                ParameterSetName="LiteralPath",
                Mandatory=$true,
                ValueFromPipeLine=$false,
                ValueFromPipelineByPropertyName=$true,
                ValueFromRemainingArguments=$false,
                DontShow=$false
            )]
            [Alias('PSPath')]
            [string[]]$LiteralPath,
            [paramater(
                Position=1,
                Mandatory=$true,
                ValueFromPipeLine=$false,
                ValueFromPipelineByPropertyName=$false,
                ValueFromRemainingArguments=$false,
                DontShow=$false
            )]
            [Alias('PSProperty')]
            [string[]]$Name,
            [paramater(
                Mandatory=$false,
                ValueFromPipeLine=$false,
                ValueFromPipelineByPropertyName=$false,
                ValueFromRemainingArguments=$false,
                DontShow=$false
            )]
            [string]$Filter,
            [paramater(
                Mandatory=$false,
                ValueFromPipeLine=$false,
                ValueFromPipelineByPropertyName=$false,
                ValueFromRemainingArguments=$false,
                DontShow=$false
            )]
            [string[]]$Include,
            [paramater(
                Mandatory=$false,
                ValueFromPipeLine=$false,
                ValueFromPipelineByPropertyName=$false,
                ValueFromRemainingArguments=$false,
                DontShow=$false
            )]
            [string[]]$Exclude,
            [paramater(
                Mandatory=$false,
                ValueFromPipeLine=$false,
                ValueFromPipelineByPropertyName=$true,
                ValueFromRemainingArguments=$false,
                DontShow=$false
            )]
            [Credential()]
            [System.Management.Automation.PSCredential]$Credential
        )

        $params = $MyInvocation.Boundparameters

        $r = Get-ItemProperty @params
        

        foreach($n in $Name) {
            $r.$n
        }
        
    }
}