[CmdletBinding()]
param(
    [string]$EnginePath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe'),
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 240
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$process = $null
$stdout = $null
$stderr = $null
try {
    $engine = (Get-Item -LiteralPath $EnginePath).FullName
    # Track the actual engine, not its console launcher, so timeouts stop the owned process.
    if ($engine -match '_console\.exe$') {
        $engine = (Get-Item -LiteralPath ($engine -replace '_console\.exe$', '.exe')).FullName
    }
    $project = Split-Path $PSScriptRoot -Parent
    $cases = @(
        @{
            Name = 'Ownership and effect schema'
            Scene = 'res://editor_only_debug/scenes/teardown_smoke_test.tscn'
            Marker = 'TEARDOWN_SMOKE_TEST: PASS (7 ownership checks, 5 stat/effect suites)'
            Headless = $true
        },
        @{
            Name = 'Rendered portrait timeline'
            Scene = 'res://editor_only_debug/scenes/portraited_scene_operator_smoke_test.tscn'
            Marker = 'PORTRAITED_SCENE_OPERATOR_SMOKE_TEST: PASS'
            Headless = $false
        },
        @{
            Name = 'Rendered ordered story'
            Scene = 'res://editor_only_debug/scenes/ordered_story_smoke_test.tscn'
            Marker = 'ORDERED_STORY_SMOKE_TEST: PASS (46 dialogue handoffs, 3 preparations, 3 battles)'
            Headless = $false
        }
    )
    foreach ($case in $cases) {
        $stdout = [System.IO.Path]::GetTempFileName()
        $stderr = [System.IO.Path]::GetTempFileName()
        $arguments = @('--path', "`"$project`"")
        if ($case.Headless) {
            $arguments += '--headless'
        } else {
            $arguments += @('--max-fps', '60', '--resolution', '960x540')
        }
        $arguments += $case.Scene
        $process = Start-Process -FilePath $engine -ArgumentList $arguments `
            -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
        $null = $process.Handle
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            Stop-Process -Id $process.Id -ErrorAction Stop
            $process.WaitForExit()
            Get-Content -LiteralPath $stdout
            Get-Content -LiteralPath $stderr
            throw "$($case.Name) exceeded $TimeoutSeconds seconds."
        }
        $process.WaitForExit()
        $output = [System.IO.File]::ReadAllText($stdout) + "`n" + [System.IO.File]::ReadAllText($stderr)
        $output = $output -replace '\x1B\[[0-9;]*m', ''
        $badDiagnostics = $output -match (
            '(?m)^\s*(?:SCRIPT ERROR|ERROR):|Leaked instance:|' +
            'ObjectDB instances.*leaked|resources still in use'
        )
        if ($process.ExitCode -ne 0 -or $badDiagnostics -or -not $output.Contains($case.Marker)) {
            Write-Output $output
            throw "$($case.Name) failed (engine exit $($process.ExitCode)); inspect the diagnostics above."
        }
        Write-Output "$($case.Name): PASS (exit 0, no script errors or teardown leaks)"
        Remove-Item -LiteralPath $stdout, $stderr
        $stdout = $null
        $stderr = $null
    }
    Write-Output 'TEARDOWN_PROCESS_TEST: PASS (3 clean process exits)'
    exit 0
} catch {
    [Console]::Error.WriteLine("Teardown validation failed: $($_.Exception.Message)")
    exit 1
} finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -ErrorAction Stop
        $process.WaitForExit()
    }
    if ($stdout -and (Test-Path -LiteralPath $stdout)) { Remove-Item -LiteralPath $stdout }
    if ($stderr -and (Test-Path -LiteralPath $stderr)) { Remove-Item -LiteralPath $stderr }
}
