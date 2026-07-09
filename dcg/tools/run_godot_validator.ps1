param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Script,

    [string]$GodotPath = "C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe",
    [string]$ProjectPath = "",
    [switch]$FailOnWarnings
)

$ErrorActionPreference = "Stop"

if ($ProjectPath -eq "") {
    $ProjectPath = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")
}

if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    Write-Error "Godot executable not found: $GodotPath"
    exit 64
}

if ($Script -notmatch "^res://") {
    $Script = "res://tools/$Script"
}

$stdoutPath = Join-Path ([System.IO.Path]::GetTempPath()) ("dcg_godot_validator_{0}_stdout.log" -f $PID)
$stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) ("dcg_godot_validator_{0}_stderr.log" -f $PID)
Remove-Item -LiteralPath $stdoutPath, $stderrPath -ErrorAction SilentlyContinue

$arguments = @("--headless", "--path", $ProjectPath, "--script", $Script)
$process = Start-Process `
    -FilePath $GodotPath `
    -ArgumentList $arguments `
    -NoNewWindow `
    -Wait `
    -PassThru `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath

$godotExitCode = $process.ExitCode

$stdout = @()
$stderr = @()
if (Test-Path -LiteralPath $stdoutPath) {
    $stdout = Get-Content -LiteralPath $stdoutPath
}
if (Test-Path -LiteralPath $stderrPath) {
    $stderr = Get-Content -LiteralPath $stderrPath
}

if ($stdout.Count -gt 0) {
    $stdout | ForEach-Object { Write-Output $_ }
}
if ($stderr.Count -gt 0) {
    $stderr | ForEach-Object { [Console]::Error.WriteLine($_) }
}

Remove-Item -LiteralPath $stdoutPath, $stderrPath -ErrorAction SilentlyContinue

$joinedOutput = (($stdout + $stderr) | Out-String)
$hasError = $joinedOutput -match "(?m)^(ERROR|SCRIPT ERROR|Parse Error|ERROR:|SCRIPT ERROR:)"
$hasWarning = $joinedOutput -match "(?m)^WARNING:"

if ($godotExitCode -ne 0) {
    exit $godotExitCode
}

if ($hasError) {
    exit 1
}

if ($hasWarning -and $FailOnWarnings) {
    exit 2
}

exit 0
