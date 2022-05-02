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

Passing this parameter allows you to retain the cache between calls to Format-Template,
otherwise a new hashtable will be generated for each call to Format-Template.

Recursive calls to Format-Template will attempt to reuse the same cache object.

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
    Format-Template .\page.template.html $details

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
function Format-Template{
    [CmdletBinding(DefaultParameterSetName="TemplatePath")]    
    param(
        [parameter(
            Mandatory=$true,
            Position=1,
            ParameterSetName="TemplatePath",
            HelpMessage="Path to the template file that should be rendered. Available when rendering."
        )]
        [String]$TemplatePath,
        [parameter(
            Mandatory=$true,
            Position=1,
            ParameterSetName="TemplateString",
            HelpMessage="Template string to render."
        )]
        [String]$TemplateString,
        [parameter(
            Mandatory=$true,
            Position=2,
            HelpMessage="Hashtable with values used when interpolating expressions in the template. Available when rendering."
        )]
        [hashtable]$Values,
        [Parameter(
            Mandatory=$false,
            Position=3,
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
        [string]$EndTag    = $script:__InterpolationTags.End
    )

    
    $script:__InterpolationTagsHistory.Push($script:__InterpolationTags)

    $script:__InterpolationTags = @{
        Start    = $StartTag
        End        = $EndTag
    }

    trap {
        $script:__InterpolationTags = $script:__InterpolationTagsHistory.Pop()
        throw $_
    }

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

    # Getting template string:
    $template = $null
    switch ($PSCmdlet.ParameterSetName) {
        TemplatePath {
            # Loading template from file, and adding it to cache:
            $templatePath = Resolve-Path $templatePath

            Write-Debug "Path resolved to '$templatePath'"

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
        }

        TemplateString {
            $template = $TemplateString
        }
    }

    # Move Cache out of the of possible user-space values.
    $__RenderCache = $Cache
    Remove-Variable "Cache"

    # Defining TemplateDir here to make it accessible when evaluating scriptblocks.
    $TemplateDir = switch ($PSCmdlet.ParameterSetName) {
        TemplatePath {
            $templatePath | Split-Path -Parent
        }
        TemplateString {
            # Using a template string, so use current working directory:
            $pwd.Path
        }
    }
    
    # Get the digest of the template string:
    $__digest__ = switch ($PSCmdlet.ParameterSetName) {
        TemplatePath {
            # Using a template file, check if we already have a digest in the cache:
            if (!$__RenderCache[$templatePath].ContainsKey("Digest")) {
                _buildTemplateDigest $template $StartTag $EndTag $__RenderCache[$templatePath]
            }

            $__RenderCache[$templatePath].Digest
        }
        TemplateString {
            # Using a template string, don't add it to the cache:
            $c = @{}
            _buildTemplateDigest $template $StartTag $EndTag $c
            $c.Digest
        }
    }
    
    # Expand values into user-space to make them more accessible during render.
    $values.GetEnumerator() | ForEach-Object {
        New-Variable $_.Name $_.Value
    }
    
    Write-Debug "Starting Render..."
    $__parts__ = $__digest__ | ForEach-Object {
        $__part__ = $_
        switch ($__part__.GetType()) {
            "hashtable" {
                if ($__part__.path) {
                    Write-Debug "Including path..." 
                    $__c__ = Format-Template -TemplatePath $__part__.path -Values $Values

                    if ($__part__.path -like "*.ps1") {
                        $__s__ = [scriptblock]::create($__c__)
                        try {
                            $__s__.Invoke()
                        } catch {
                            $msg = "An unexpected exception occurred while Invoking '{0}'." -f $__part__.path
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
                    $msg = "An unexpected exception occurred while rendering an expression: '{0}'." -f $__part__
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