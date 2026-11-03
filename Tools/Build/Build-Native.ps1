<#
.SYNOPSIS
    Build the native GDExtension (godot-cpp + Source) with the project-local uv environment.

.DESCRIPTION
    Uses .venv created by `uv sync` (see Setup-Env.ps1). Two machine-specific details
    are handled here:

    * TMP/TEMP are redirected to .build-temp. link.exe fails with
      "LNK1104: cannot open file ...\lnk{GUID}.tmp" when it uses the default user
      temp directory on this machine.
    * VSLANG=1033 keeps MSVC output in English (avoids GBK mojibake in logs).

.PARAMETER Target
    template_debug (default) or template_release.

.PARAMETER Jobs
    Parallel compile jobs. Defaults to 8.

.PARAMETER Python
    Python interpreter that has SCons. Defaults to $env:THEONE_PYTHON, then to the
    repository .venv.

.EXAMPLE
    .\Tools\Build\build-native.cmd
    .\Tools\Build\build-native.cmd -Target template_release -Jobs 12
#>
param(
    [ValidateSet('template_debug', 'template_release')]
    [string]$Target = 'template_debug',
    [int]$Jobs = 8,
    [string]$Python
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))

if (-not $Python) {
    $Python = if ($env:THEONE_PYTHON) { $env:THEONE_PYTHON } else { Join-Path $repo '.venv\Scripts\python.exe' }
}
if (-not (Test-Path -LiteralPath $Python)) {
    throw "Python with SCons not found: $Python`nRun Tools\Build\setup-env.cmd (uv sync) first, or pass -Python / set THEONE_PYTHON."
}

$temp = Join-Path $repo '.build-temp'
New-Item -ItemType Directory -Force -Path $temp | Out-Null
$env:TMP = $temp
$env:TEMP = $temp
$env:VSLANG = '1033'

Write-Host "Interpreter : $Python"
Write-Host "Temp        : $temp"
Write-Host "Target      : $Target (jobs=$Jobs)"

Push-Location $repo
try {
    & $Python -m SCons platform=windows "target=$Target" "-j$Jobs"
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}

if ($code -ne 0) { throw "SCons failed with exit code $code" }
Write-Host "Built: Project/bin/theone.windows.$Target.x86_64.dll"