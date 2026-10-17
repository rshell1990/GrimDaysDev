[CmdletBinding()]
param(
    [string]$EnginePath = (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe'),
    [string]$ProjectPath,
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 600
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$process = $null
$stdout = $null
$stderr = $null
$outputReported = $false
try {
    if (-not $ProjectPath) { $ProjectPath = Split-Path $PSScriptRoot -Parent }
    $engine = (Get-Item -LiteralPath $EnginePath).FullName
    $project = (Get-Item -LiteralPath $ProjectPath).FullName.TrimEnd('\')
    if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))) {
        throw "No project.godot found in $project"
    }
    $editors = @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^Godot.*\.exe$' -and $_.CommandLine -match '(?:^|\s)(?:--editor|-e)(?:\s|$)' -and
        $_.CommandLine -match ('(?i)--path\s+"?' + [regex]::Escape($project) + '"?(?:\s|$)')
    })
    if ($editors.Count -gt 0) {
        throw "Close the Godot editor for this project before validation to avoid concurrent imports (PID $($editors.ProcessId -join ', '))."
    }
    $stdout = [System.IO.Path]::GetTempFileName()
    $stderr = [System.IO.Path]::GetTempFileName()
    $process = Start-Process -FilePath $engine -ArgumentList @(
        '--headless', '--editor', '--path', "`"$project`"", '--import'
    ) -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    # Retain the process handle so PowerShell 5.1 can read ExitCode after waiting.
    $null = $process.Handle
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -ErrorAction Stop
        $process.WaitForExit()
        throw "Godot validation exceeded $TimeoutSeconds seconds. Increase -TimeoutSeconds if initial imports need longer."
    }
    $process.WaitForExit()
    $output = [System.IO.File]::ReadAllText($stdout) + "`n" + [System.IO.File]::ReadAllText($stderr)
    Write-Output $output
    $outputReported = $true
    if ($process.ExitCode -ne 0 -or $output -match '(?m)^\s*(?:SCRIPT ERROR|ERROR):') {
        throw "Godot import/compilation validation failed (engine exit code $($process.ExitCode)); inspect the diagnostics above."
    }
    Write-Output 'Godot project import/compilation validation passed. This is not a runtime test or an exhaustive check of unused scripts.'
    exit 0
} catch {
    if (-not $outputReported) {
        if ($stdout -and (Test-Path -LiteralPath $stdout)) { Get-Content -LiteralPath $stdout }
        if ($stderr -and (Test-Path -LiteralPath $stderr)) { Get-Content -LiteralPath $stderr }
    }
    [Console]::Error.WriteLine("Validation failed: $($_.Exception.Message)")
    exit 1
} finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -ErrorAction Stop
        $process.WaitForExit()
    }
    if ($stdout -and (Test-Path -LiteralPath $stdout)) { Remove-Item -LiteralPath $stdout }
    if ($stderr -and (Test-Path -LiteralPath $stderr)) { Remove-Item -LiteralPath $stderr }
}
