<#
.SYNOPSIS
Renders a template file.

.DESCRIPTION
Renders a template file of any type (HTML, CSS, RDP, etc..) using powershell expressions
written between '<<' and '>>' markers to interpolate dynamic values.

.PARAMETER templatePath
The path to the template file that should be rendered (relative of full).

.PARAMETER values
A hashtable of values that should be used when resolving powershell expressions.
The keys in this hashtable will introduced as variables into the resolution context.
The $values variable itself is available as well. 

.EXAMPLE
Contents of .\page.template.html:
    <header1><<$Title>></header1>
    <header2><<$values.Chapter1>></header2>

Running:
    $details = @{
        Title  = "A tale of two cities"
        Chapter1 = "The Period"
    }
    Render-Template .\page.template.html $details

Will yield:
    <header1>A tale of two cities</header1>
    <header2>The Period</header2>
.NOTES
The markup using '<<' and '>>' to denote the start and end of an interpolated expression
precludes the use of the '>>' output operator in the expressions. This is considered
acceptable, since the intention of the expressions is to introduce values into the text,
rather than writing to the disk.

Any expression that is so complicated that you might need to write to the disk should
probably be handled as a closure or a function passed in via the $values parameter.
#>
function Render-Template{
    param(
        [parameter(
            Mandatory=$true,
            HelpMessage="Path to the template file that should be rendered."
        )]
        [String]$templatePath,
        [parameter(
            Mandatory=$true,
            HelpMessage="Hashtable with values used when interpolating expressions in the template."
        )]
        [hashtable]$values
    )

    $values.GetEnumerator() |% {
        if (!(Get-Variable($_.Name) -ea SilentlyContinue)) {
            New-Variable $_.Name $_.Value
        }
    }

    $template = [System.IO.File]::ReadAllText($templatePath)

    $regex = [regex]::new('<<(([^>]|>(?!>))+)>>', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    $regex.Replace($template, {param($match) Invoke-Expression $match.Groups[1].Value })
    
}