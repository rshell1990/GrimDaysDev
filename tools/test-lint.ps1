[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'lint.ps1')
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('godot-lint-tests-' + [guid]::NewGuid())
$fixture = Join-Path $temporaryDirectory 'fixture.gd'
$checks = 0

function Assert-Check {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:checks++
}

function Get-FixtureDiagnostics {
    param([string]$Source)
    [System.IO.File]::WriteAllText($fixture, $Source, [System.Text.UTF8Encoding]::new($false))
    @(Get-GDScriptLintDiagnostics $fixture)
}

function Assert-Rule {
    param([string]$Source, [string]$Rule, [int]$ExpectedCount)
    $found = @(Get-FixtureDiagnostics $Source | Where-Object Rule -eq $Rule)
    Assert-Check ($found.Count -eq $ExpectedCount) "$Rule expected $ExpectedCount finding(s), got $($found.Count)"
}

try {
    New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null
    $clean = "extends RefCounted`nclass_name LintFixture`n`nconst MAX_VALUE = 3`n`nfunc value() -> int:`n    return MAX_VALUE`n"
    Assert-Check (@(Get-FixtureDiagnostics $clean).Count -eq 0) 'Clean four-space script passes'
    Assert-Rule "extends Node`n`tpass`n" 'no-tabs' 1
    Assert-Rule "extends Node`n    pass`n" 'no-tabs' 0
    Assert-Rule "extends Node`n   pass`n" 'indent-width' 1
    Assert-Rule "extends Node `n" 'trailing-whitespace' 1
    Assert-Rule "extends Node`n# comment `n" 'trailing-whitespace' 1
    Assert-Rule ("extends Node`n# " + ('x' * 118)) 'line-length' 0
    Assert-Rule ("extends Node`n# " + ('x' * 119)) 'line-length' 1
    Assert-Rule ("extends Node`n" + ("# line`n" * 799)) 'file-length' 0
    Assert-Rule ("extends Node`n" + ("# line`n" * 800)) 'file-length' 1
    Assert-Rule 'class_name snake_case' 'class-name-style' 1
    Assert-Rule 'class_name lowercase' 'class-name-style' 1
    Assert-Rule 'class_name ValidClass2' 'class-name-style' 0
    Assert-Rule "extends Node`nconst lower = 1" 'const-style' 1
    Assert-Rule "extends Node`nconst _VALID_NAME = 1" 'const-style' 0
    Assert-Rule "extends Node`n    breakpoint # stop" 'breakpoint' 1
    Assert-Rule "extends Node`n    print(1)" 'debug-print' 1
    Assert-Rule "extends Node`nfunc print(value):`n    pass" 'debug-print' 0
    Assert-Rule "extends Node`n# print(1), breakpoint, class_name snake_case" 'debug-print' 0
    Assert-Rule 'extends Node; var text = "print(1) # breakpoint"' 'debug-print' 0
    Assert-Rule 'extends Node; var text = "escaped \" print(1)"' 'debug-print' 0
    Assert-Rule "extends Node`nvar text = 'print(1)'" 'debug-print' 0
    Assert-Rule @'
extends Node
var text = """
	print(1)   
    breakpoint
"""
'@ 'no-tabs' 0
    Assert-Rule @'
extends Node
var text = """
	print(1)   
    breakpoint
"""
'@ 'trailing-whitespace' 0
    Assert-Rule @'
extends Node
var text = """
    print(1)
"""
func run() -> void:
    print("PASS # this is string data")
'@ 'debug-print' 1
    Assert-Rule @'
extends Node
func run() -> void:
    print("PASS") # lint:ignore debug-print -- Intentional smoke-test output.
'@ 'debug-print' 0
    Assert-Rule @'
extends Node
func run() -> void:
    print("# lint:ignore debug-print -- Not a real comment.")
'@ 'debug-print' 1
    Assert-Rule "extends Node`n    print(1) # lint:ignore debug-print" 'debug-print' 1
    Assert-Rule "extends Node`nvar thing = load(`"../thing.tres`")" 'relative-load' 1
    Assert-Rule "extends Node`nvar text = `"../not_a_resource`"" 'relative-load' 0
    Assert-Rule "extends Node`nvar thing = load(`"uid://123`")" 'relative-load' 0
    Assert-Rule "extends Node`nvar thing = load(`"user://save.tres`")" 'relative-load' 0
    Assert-Rule "extends Node`nvar thing: Resource = load(`"res://thing.tres`")" 'load-in-var' 1
    Assert-Rule "extends Node`nvar thing = (`n    load(`"res://thing.tres`")`n)" 'load-in-var' 1
    Assert-Rule "extends Node`nvar thing =`n    load(`"res://thing.tres`")" 'load-in-var' 1
    Assert-Rule "extends Node`nconst THING = preload(`"res://thing.tres`")" 'load-in-var' 0
    Assert-Rule "extends Node`nvar thing = load(`"res://thing.png`")" 'dynamic-asset-load' 1
    Assert-Rule "extends Node`nvar text = `"res://thing.png`"" 'dynamic-asset-load' 0
    Assert-Rule "@tool`nextends Node" 'file-header' 1
    Assert-Rule "# Tool script.`n@tool`nextends Node" 'file-header' 0
    Assert-Rule ("extends Node`nvar " + [char]0x4E2D + ' = 1') 'non-ascii' 1
    Assert-Rule ("extends Node`nvar text = `"" + [char]0x4E2D + '"') 'non-ascii' 0
    $location = @(Get-FixtureDiagnostics "extends Node`r`nfunc run() -> void:`r`n    print(1)")
    Assert-Check ($location[0].Line -eq 3 -and $location[0].Column -eq 5) 'CRLF diagnostic location is correct'
    $projectFiles = @(Get-ProjectLintFiles $LintConfig.Roots)
    Assert-Check ($projectFiles.Count -gt 0) 'Default scope includes project scripts'
    Assert-Check (@($projectFiles | Where-Object { $_ -match '\\(?:addons|\.godot|imported)\\' }).Count -eq 0) 'Vendored/cache directories are excluded'
    Copy-Item -LiteralPath (Join-Path $ProjectRoot 'lint.ps1') -Destination $temporaryDirectory
    Copy-Item -LiteralPath (Join-Path $ProjectRoot 'lint.psd1') -Destination $temporaryDirectory
    $cli = Join-Path $temporaryDirectory 'lint.ps1'
    [System.IO.File]::WriteAllText($fixture, $clean)
    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cli -Paths $fixture)
    Assert-Check ($LASTEXITCODE -eq 0) 'Clean CLI run exits zero'
    Assert-Check (($output -join "`n") -match 'Linted 1 scripts: 0 errors, 0 warnings, 0 advisory findings.') 'CLI reports exact counts'
    [System.IO.File]::WriteAllText($fixture, "extends Node`n`tpass")
    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cli -Paths $fixture)
    Assert-Check ($LASTEXITCODE -eq 1) 'Style errors exit one'
    [System.IO.File]::WriteAllText($fixture, "extends Node`nconst lower = 1")
    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cli -Paths $fixture)
    Assert-Check ($LASTEXITCODE -eq 0) 'Warnings are non-blocking by default'
    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $cli -Paths $fixture -FailOnWarning)
    Assert-Check ($LASTEXITCODE -eq 1) 'FailOnWarning makes warnings blocking'
    $process = Start-Process powershell.exe -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$cli`"",
        '-Paths', "`"$(Join-Path $temporaryDirectory 'missing.gd')`""
    ) -Wait -PassThru -RedirectStandardError (Join-Path $temporaryDirectory 'expected-error.txt')
    Assert-Check ($process.ExitCode -eq 2) 'Invalid input exits two'
    "PASS: $checks lint checks."
} finally {
    foreach ($name in @('fixture.gd', 'lint.ps1', 'lint.psd1', 'expected-error.txt')) {
        $path = Join-Path $temporaryDirectory $name
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
    }
    if (Test-Path -LiteralPath $temporaryDirectory) { Remove-Item -LiteralPath $temporaryDirectory }
}
