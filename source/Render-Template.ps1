<#
.SYNOPSIS
Renders a template file.

.DESCRIPTION
Renders a template file of any type (HTML, CSS, RDP, etc..) using powershell expressions
written between '<<' and '>>' markers to interpolate dynamic values.

Files may also be included into the template by using <<(<path to file>)>>, if the file is
a .ps1 file it will be interpreted as an expression to be executed, otherwise it will be
treated as a template file and rendered using the same Values.

.PARAMETER templatePath
The path to the template file that should be rendered (relative or fully qualified,
UNC paths not supported).

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

.PARAMETER StartTag
Tag used to indicate the start of a section in the text that should be interpolated.

This string will be treated as a regular expression, so any special characters
('*', '+', '[', ']', '(', ')', '\', '?', '{', '}', etc) should be escaped with a '\'.

The default start tag is '<<'.


.PARAMETER EndTag
Tag used to indicate the end of a section in the text that should be interpolated.

This string will be treated as a regular expression, so any special characters
('*', '+', '[', ']', '(', ')', '\', '?', '{', '}', etc) should be escaped with a '\'.

The default end tag is '>>'.

.EXAMPLE
Contents of .\page.template.html:
    <h1><<$Title>></he1>
	<h2><<$values.Chapter1>></h2>
	
	<<(.\pages\1.html)>>

Contents of .\pages\1.html:

	It was the best of times, it was the worst of times.

Running:
    $details = @{
        Title  = "A tale of two cities"
        Chapter1 = "The Period"
    }
    Render-Template .\page.template.html $details

Will yield:
    <h1>A tale of two cities</h1>
	<h2>The Period</h2>
	
	It was the best of times, it was the worst of times.


.NOTES
The markup using the default '<<' and '>>' tags to denote the start and end of an interpolated
expression precludes the use of the '>>' output operator in the expressions. This is considered
acceptable, since the intention of the expressions is to introduce values into the text,
rather than writing to the disk.

Any expression that is so complicated that you might need to write to the disk should
probably be handled as a closure or a function passed in via the $values parameter, or
a file included using a <<()>> expression.

Alternatively, you can use the the EndTag parameter top provide another acceptable end tag (e.g. '!>>').

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
		[hashtable]$Cache = $null,
		[Parameter(
            Mandatory=$false,
            HelpMessage='Tag used to open interpolation sections. Regular Expression.'
        )]
		[string]$StartTag = $script:__InterpolationTags.Start,
		[Parameter(
            Mandatory=$false,
            HelpMessage='Tag used to close interpolation sections. Regular expression.'
        )]
		[string]$EndTag	= $script:__InterpolationTags.End
    )

	
	$script:__InterpolationTagsHistory.Push($script:__InterpolationTags)

	$script:__InterpolationTags = @{
		Start	= $StartTag
		End		= $EndTag
	}

	trap {
		$script:__InterpolationTags = $script:__InterpolationTagsHistory.Pop()
		throw $_
	}

	$EndTagStart = $EndTag[0]
	if ($EndTagStart -eq '\') {
		$EndTagStart.Substring(0, 2)
	}
	$EndTagRemainder = $EndTag.Substring($EndTagStart.Length)
	$InterpolationRegex = "{0}(\((?<path>.+)\)|(?<command>([^{1}]|{1}(?!{2}))+)){3}" -f $StartTag, $EndTagStart, $EndTagRemainder, $EndTag

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
		$script:__RenderCache = $Cache
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

	# Defining TemplateDir here to make it accessible when evaluating scriptblocks.
    $TemplateDir = $templatePath | Split-Path -Parent
    
	if (!$__RenderCache[$templatePath].ContainsKey("Digest")) {
		$__buildDigest = {
			param($templateCache)
			
			Write-Debug "Building digest..."
			$__c__ = $templateCache
			$__c__.Digest = @()
			
			$__regex__ = New-Object regex ($InterpolationRegex, [System.Text.RegularExpressions.RegexOptions]::Multiline)
			$__meta__ = @{ LastIndex = 0 }
			
			$__regex__.Replace(
				$template,
				{
					param($match)
					# Isolate information about the expression.
					$__li__ = $__meta__.LastIndex
					$__g0__ = $match.Groups[0]
					$__path__	= $match.Groups["path"]
					$__command__= $match.Groups["command"]
					
					# Collect string literal preceeding this expression and add it to the digest.
					$__ls__ = $template.Substring($__li__, ($__g0__.index - $__li__))
					$__meta__.LastIndex = $__g0__.index + $__g0__.length
					$__c__.Digest += $__ls__
					
					# Process the expression:
					if ($__command__.Success) {
						# Expression is a command: turn it into a script block and add it to the digest.
						$__c__.Digest += [scriptblock]::create($__command__.value)
					} elseif ($__path__.Success){
						# Expand any variables in the path and add the expanded path to digest:
						$p = $ExecutionContext.InvokeCommand.ExpandString($__path__.Value)
						$__c__.Digest += @{ path=$p }						
					}
					
					$__meta__ | Out-String | Write-Debug
					
				}
			) | Out-Null
			
			
			if ($__meta__.LastIndex -lt $template.length) {
				$__c__.Digest += $template.substring($__meta__.LastIndex)
			}
		}

		& $__buildDigest $__RenderCache[$templatePath]
	}
	
	# Expand values into user-space to make them more accessible during render.
    $values.GetEnumerator() | % {
        New-Variable $_.Name $_.Value
    }
	
	Write-Debug "Starting Render..."
	$__parts__ = $__RenderCache[$templatePath].Digest | % {
		$__part__ = $_
		switch ($__part__.GetType()) {
			"hashtable" {
				if ($__part__.path) {
					Write-Debug "Including path..." 
					$__c__ = Render-Template $__part__.path $Values

					if ($__part__.path -like "*.ps1") {
						$__s__ = [scriptblock]::create($__c__)
						try {
							$__s__.Invoke()
						} catch {
							$msg = "An unexpected exception occurred while Invoking '{0}' as part of '{1}'." -f $__part__.path, $templatePath
							$e = New-Object System.Exception $msg, $_.Exception

							throw $e
						}
					} else {
						$__c__
					}
				}
			}

			"scriptblock" {
				try {
					$__part__.invoke()
				} catch {
					$msg = "An unexpected exception occurred while rendering an expression in '{0}': {1}" -f $templatePath, $__part__
					$e = New-Object System.Exception $msg, $_.Exception

					throw $e
				}
			}

			default {
				$__part__
			}
		}
	}

	$script:__InterpolationTags = $script:__InterpolationTagsHistory.Pop()
	
	$__parts__ -join ""

	
}