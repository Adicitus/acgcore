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

.PARAMETER Cache
A hashtable used to cache the results of loading template files.

Passing this parameter allows you to retain the cache between calls to Render-Template,
otherwise a new hashtable will be generated for each call to Render-Template.

Recursive calls to Render-Template will attempt to reuse the same cache object.

During rendering the cache is available as '$__RenderCache'.


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
    [CmdletBinding()]    
    param(
        [parameter(
            Mandatory=$true,
            HelpMessage="Path to the template file that should be rendered. Available when rendering."
        )]
        [String]$TemplatePath,
        [parameter(
            Mandatory=$true,
            HelpMessage="Hashtable with values used when interpolating expressions in the template. Available when rendering."
        )]
        [hashtable]$values,
        [Parameter(
            Mandatory=$false,
            HelpMessage='Optional Hashtable used to cache the content of files once they are loaded. Pass in a hashtable to retain cache between calls. Available as $__RenderCache when rendering.'
        )]
        [hashtable]$Cache = $null
    )


	if ($Cache) {
		Write-Debug "Cache provided by caller, updating global."
		$script:__RenderCache = $Cache
	}

    if ($null -eq $Cache) { 
        
        Write-Debug "Looking for cache..."
        
		if ($Cache = $script:__RenderCache) {
			Write-Debug "Using global cache."
		} elseif ($cacheVar = $PSCmdlet.SessionState.PSVariable.Get("__RenderCache")) {
			# This is a recursive call, we can reuse the cache from parent.
			$Cache = $cacheVar.Value
			Write-Debug "Found cache in parent context."
		}

    }

    if ($null -eq $cache) {
        Write-Debug "Failed to get cache from parent. Creating new cache."
        $Cache = @{}
    }

	$templatePath = Resolve-Path $templatePath

	Write-Debug "Path resolved to '$templatePath'"

    $template = $null

    if ($Cache.ContainsKey($templatePath)) {
		Write-Debug "Found path in cache..."
		try {
            $item = Get-Item $TemplatePath
            if ($item.LastWriteTime.Ticks -gt $Cache[$templatePath].LoadTime.Ticks) {
                Write-Debug "Cache is out-of-date, reloading..."
				$t = [System.IO.File]::ReadAllText($templatePath)
                $Cache[$templatePath] = @{ Value = $t; LoadTime = [datetime]::now }
            }
        } catch { <# Do nothing for now #> }
        $template = $Cache[$templatePath].Value
    } else {
		Write-Debug "Not in cache, loading..."
        $template = [System.IO.File]::ReadAllText($templatePath)
        $Cache[$templatePath] = @{ Value = $template; LoadTime = [datetime]::now }
    }

    # Move Cache out of the of possible user-space values.
    $__RenderCache = $Cache
    Remove-Variable "Cache"

    $TemplateDir = $templatePath | Split-Path -Parent

    $values.GetEnumerator() |% {
            New-Variable $_.Name $_.Value
    }

    $regex = New-Object regex ('<<(([^>]|>(?!>))+)>>', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    
	Write-Debug "Starting Render..."
	$regex.Replace($template, {param($match) Invoke-Expression $match.Groups[1].Value })
    
}