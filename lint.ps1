[CmdletBinding()]
param(
    [string[]]$Paths,
    [switch]$FailOnWarning
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProjectRoot = $PSScriptRoot
$LintConfig = Import-PowerShellDataFile (Join-Path $ProjectRoot 'lint.psd1')

function Get-GDScriptLexicalData {
    param([string]$Text)

    $masked = $Text.ToCharArray()
    $inString = New-Object bool[] $Text.Length
    $strings = [System.Collections.Generic.List[object]]::new()
    $comments = [System.Collections.Generic.List[object]]::new()
    $i = 0
    while ($i -lt $Text.Length) {
        if ($Text[$i] -eq '#') {
            $start = $i
            while ($i -lt $Text.Length -and $Text[$i] -ne "`n" -and $Text[$i] -ne "`r") {
                $masked[$i] = ' '
                $i++
            }
            $comments.Add([pscustomobject]@{ Offset = $start; Text = $Text.Substring($start, $i - $start) })
        } elseif ($Text[$i] -eq '"' -or $Text[$i] -eq "'") {
            $start = $i
            $quote = [string]$Text[$i]
            $delimiter = $quote
            if ($i + 2 -lt $Text.Length -and $Text.Substring($i, 3) -eq ($quote * 3)) {
                $delimiter = $quote * 3
            }
            $i += $delimiter.Length
            $contentStart = $i
            $contentEnd = $Text.Length
            while ($i -lt $Text.Length) {
                if ($Text[$i] -eq '\') {
                    $i = [Math]::Min($i + 2, $Text.Length)
                } elseif ($i + $delimiter.Length -le $Text.Length -and
                    $Text.Substring($i, $delimiter.Length) -eq $delimiter) {
                    $contentEnd = $i
                    $i += $delimiter.Length
                    break
                } else {
                    $i++
                }
            }
            $strings.Add([pscustomobject]@{
                Offset = $start
                Value = $Text.Substring($contentStart, $contentEnd - $contentStart)
            })
            for ($j = $start; $j -lt $i; $j++) {
                $inString[$j] = $true
                if ($Text[$j] -ne "`n" -and $Text[$j] -ne "`r") {
                    $masked[$j] = ' '
                }
            }
        } else {
            $i++
        }
    }
    [pscustomobject]@{ Code = -join $masked; InString = $inString; Strings = $strings; Comments = $comments }
}

function Get-GDScriptLintDiagnostics {
    param([string]$FilePath)

    $text = [System.IO.File]::ReadAllText($FilePath)
    $lexical = Get-GDScriptLexicalData $text
    $lines = [regex]::Split($text, '\r\n|\n|\r')
    $codeLines = [regex]::Split($lexical.Code, '\r\n|\n|\r')
    $diagnostics = [System.Collections.Generic.List[object]]::new()
    $lineStarts = [System.Collections.Generic.List[int]]::new()
    $lineStarts.Add(0)
    foreach ($newline in [regex]::Matches($text, '\r\n|\n|\r')) {
        $lineStarts.Add($newline.Index + $newline.Length)
    }
    $suppressions = @{}
    foreach ($comment in $lexical.Comments) {
        $line = 1
        while ($line -lt $lineStarts.Count -and $lineStarts[$line] -le $comment.Offset) { $line++ }
        if ($comment.Text -match '^#\s*lint:ignore\s+([a-z-]+(?:\s*,\s*[a-z-]+)*)\s+--\s+\S') {
            $suppressions[$line] = @($Matches[1] -split '\s*,\s*')
        }
    }
    function Add-Diagnostic {
        param([int]$Line, [int]$Column, [string]$Severity, [string]$Rule, [string]$Message)
        if ($suppressions.ContainsKey($Line) -and $suppressions[$Line] -ccontains $Rule) { return }
        $diagnostics.Add([pscustomobject]@{
            File = $FilePath; Line = $Line; Column = $Column
            Severity = $Severity; Rule = $Rule; Message = $Message
        })
    }

    $fileLines = $lines.Count
    if ($text -match '(\r\n|\n|\r)$') { $fileLines-- }
    if ($fileLines -gt $LintConfig.MaxFileLines) {
        Add-Diagnostic 1 1 'info' 'file-length' "File has $fileLines lines; target is $($LintConfig.MaxFileLines)."
    }
    $firstContent = [regex]::Match($text, '\S')
    if ($firstContent.Success -and $text.Substring($firstContent.Index) -notmatch '^(#|class_name\b|extends\b)') {
        Add-Diagnostic 1 1 'info' 'file-header' 'Begin meaningful content with a header comment, class_name, or extends.'
    }
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $lineNumber = $index + 1
        $line = $lines[$index]
        $code = $codeLines[$index]
        $offset = $lineStarts[$index]
        $indentation = [regex]::Match($line, '^[ \t]+')
        if ($indentation.Success -and -not $lexical.InString[$offset]) {
            if ($indentation.Value.Contains("`t")) {
                Add-Diagnostic $lineNumber 1 'error' 'no-tabs' 'Use spaces for indentation; preserve legacy blocks during unrelated edits.'
            } elseif ($indentation.Length % 4 -ne 0) {
                Add-Diagnostic $lineNumber 1 'info' 'indent-width' 'Review indentation: use 4 spaces per level; continuation alignment may differ.'
            }
        }
        $trailing = [regex]::Match($line, '[ \t]+$')
        if ($trailing.Success -and -not $lexical.InString[$offset + $trailing.Index]) {
            Add-Diagnostic $lineNumber ($trailing.Index + 1) 'info' 'trailing-whitespace' 'Remove trailing whitespace outside string data.'
        }
        if ($line.Length -gt $LintConfig.MaxLineLength) {
            Add-Diagnostic $lineNumber ($LintConfig.MaxLineLength + 1) 'info' 'line-length' "Line has $($line.Length) characters; target is $($LintConfig.MaxLineLength)."
        }
        if ($code -cmatch '^\s*class_name\s+([\p{L}_][\p{L}\p{N}_]*)') {
            if ($Matches[1] -cnotmatch '^[A-Z][A-Za-z0-9]*$') {
                Add-Diagnostic $lineNumber 1 'warning' 'class-name-style' 'Use PascalCase for class_name declarations.'
            }
        }
        if ($code -cmatch '^\s*const\s+([\p{L}_][\p{L}\p{N}_]*)') {
            if ($Matches[1] -cnotmatch '^_?[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)*$') {
                Add-Diagnostic $lineNumber 1 'warning' 'const-style' 'Use UPPER_SNAKE_CASE for constants (one leading underscore is allowed).'
            }
        }
        foreach ($match in [regex]::Matches($code, '(?<![\p{L}\p{N}_.])print\s*\(')) {
            if ($code.Substring(0, $match.Index) -match '\bfunc\s+$') { continue }
            Add-Diagnostic $lineNumber ($match.Index + 1) 'info' 'debug-print' 'Review print output: intentional CLI/test output is allowed; remove temporary debugging.'
        }
        if ($code -match '^\s*breakpoint\s*;?\s*$') {
            Add-Diagnostic $lineNumber 1 'warning' 'breakpoint' 'Remove temporary breakpoint statements.'
        }
        foreach ($match in [regex]::Matches($code, '[\p{L}_][\p{L}\p{N}_]*')) {
            if ($match.Value -match '[^\x00-\x7F]') {
                Add-Diagnostic $lineNumber ($match.Index + 1) 'info' 'non-ascii' 'Review non-ASCII identifiers; intentional localized strings and comments are allowed.'
            }
        }
    }
    foreach ($initializer in [regex]::Matches(
        $lexical.Code,
        '(?m)^[ \t]*(?:@export(?:_[a-z_]+)?(?:\([^)]*\))?[ \t]+)?(?:static[ \t]+)?var[ \t]+\w+[^=\r\n]*=\s*\(*\s*(?:preload|load)\s*\('
    )) {
        $line = 1
        while ($line -lt $lineStarts.Count -and $lineStarts[$line] -le $initializer.Index) { $line++ }
        Add-Diagnostic $line 1 'info' 'load-in-var' 'Review fixed dependencies for a preload constant; preserve intentional runtime/deferred loading.'
    }
    foreach ($literal in $lexical.Strings) {
        $prefix = $lexical.Code.Substring(0, $literal.Offset)
        if ($prefix -notmatch '\b(?:load|preload)\s*\(\s*$') { continue }
        $line = 1
        while ($line -lt $lineStarts.Count -and $lineStarts[$line] -le $literal.Offset) { $line++ }
        $column = $literal.Offset - $lineStarts[$line - 1] + 1
        if ($literal.Value -match '(^|/)\.\./') {
            Add-Diagnostic $line $column 'info' 'relative-load' 'Prefer res:// for project resource loads; preserve valid uid:// and user:// identities.'
        }
        if ($literal.Value -match '\.(png|jpe?g|wav|ogg)$') {
            Add-Diagnostic $line $column 'info' 'dynamic-asset-load' 'Review literal image/audio dependencies for reusable preloads when appropriate.'
        }
    }
    $diagnostics.ToArray()
}

function Get-ProjectLintFiles {
    param([string[]]$InputPaths)

    $files = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($inputPath in $InputPaths) {
        $path = $inputPath
        if (-not [System.IO.Path]::IsPathRooted($path)) { $path = Join-Path $ProjectRoot $path }
        $item = Get-Item -LiteralPath $path -ErrorAction Stop
        if ($item.PSIsContainer) {
            $candidates = @(Get-ChildItem -LiteralPath $item.FullName -Filter '*.gd' -Recurse -File)
        } elseif ($item.Extension -eq '.gd') {
            $candidates = @($item)
        } else {
            throw "Expected a GDScript file or directory: $path"
        }
        foreach ($candidate in $candidates) {
            if (-not $candidate.FullName.StartsWith($ProjectRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Lint targets must be inside the project: $($candidate.FullName)"
            }
            $relative = $candidate.FullName.Substring($ProjectRoot.Length + 1).Replace('\', '/')
            $excluded = $false
            foreach ($directory in $LintConfig.ExcludeDirectories) {
                if ($relative.StartsWith($directory + '/', [System.StringComparison]::OrdinalIgnoreCase) -or
                    ($directory -notmatch '/' -and ($relative -split '/') -contains $directory)) {
                    $excluded = $true
                    break
                }
            }
            if (-not $excluded) { [void]$files.Add($candidate.FullName) }
        }
    }
    @($files)
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if (-not $Paths) { $Paths = $LintConfig.Roots }
        $files = @(Get-ProjectLintFiles $Paths)
        if ($files.Count -eq 0) { throw 'No project-owned GDScript files matched the requested paths.' }
        $diagnostics = @(foreach ($file in $files) { Get-GDScriptLintDiagnostics $file })
        foreach ($diagnostic in $diagnostics) {
            '{0}:{1}:{2}: {3}: [{4}] {5}' -f $diagnostic.File, $diagnostic.Line,
                $diagnostic.Column, $diagnostic.Severity, $diagnostic.Rule, $diagnostic.Message
        }
        $errors = @($diagnostics | Where-Object Severity -eq 'error').Count
        $warnings = @($diagnostics | Where-Object Severity -eq 'warning').Count
        $information = @($diagnostics | Where-Object Severity -eq 'info').Count
        "Linted $($files.Count) scripts: $errors errors, $warnings warnings, $information advisory findings."
        if ($errors -gt 0 -or ($FailOnWarning -and $warnings -gt 0)) { exit 1 }
        exit 0
    } catch {
        [Console]::Error.WriteLine("Lint failed: $($_.Exception.Message)")
        exit 2
    }
}
