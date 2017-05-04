$Script:RegexPatterns = @{ }

$Script:RegexPatterns.IPv4AddressByte = "(25[0-4]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[0-9])" # A byte in an IPv4 Address
$IPv4AB = $Script:RegexPatterns.IPv4AddressByte
$Script:RegexPatterns.IPv4NetMaskByte = "(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9][0-9]|[1-9])" # A non-full byte in a IPv4 Netmask
$IPv4NMB = $Script:RegexPatterns.IPv4NetMaskByte

$ItemChars = "[^\\/:*`"|<>]"
$Script:RegexPatterns.Directory = '(?<directory>(?<root>[A-Z]+:|\.|\\.*)[\\/]({0}+[\\/]?)*)' -f $ItemChars
$Script:RegexPatterns.File = ( '(?<file>(?<directory>((?<root>[A-Z]+:|\.|\\.*)[\\/])?({0}+[\\/])*)(?<filename>([^\\/.]+)+(\.(?<extension>[^\\/.]+)?))' + ")" ) -f $ItemChars
$Script:RegexPatterns.IPv4Address = "($IPv4AB\.){3}$($IPv4AB)"
$Script:RegexPatterns.IPv4Netmask = "((255\.){3}$IPv4NMB)|((255\.){2}($IPv4NMB\.)0)|((255\.){1}($IPv4NMB\.)0\.0)|(($IPv4NMB\.)0\.0\.0)|0\.0\.0\.0"
$Script:RegexPatterns.GUID = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{10}"