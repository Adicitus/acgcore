function _buildTemplateDigest{
    param($template, $StartTag, $EndTag, $templateCache)
    
	$EndTagStart = $EndTag[0]
	if ($EndTagStart -eq '\') {
		$EndTagStart.Substring(0, 2)
	}
	$EndTagRemainder = $EndTag.Substring($EndTagStart.Length)
	$InterpolationRegex = "{0}(\((?<path>.+)\)|(?<command>([^{1}]|{1}(?!{2}))+)){3}" -f $StartTag, $EndTagStart, $EndTagRemainder, $EndTag
    
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