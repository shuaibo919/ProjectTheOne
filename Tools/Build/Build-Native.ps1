<#
.SYNOPSIS
    Build the native GDExtension (godot-cpp + Source).

.DESCRIPTION
    Runs SCons from the repository root. godot-cpp itself is built on first run,
    so the first invocation takes a few minutes; later runs are incremental.

.PARAMETER Target
    template_debug (default) or template_release.

.PARAMETER Jobs
    Parallel compile jobs. Defaults to 8.

.PARAMETER Python
    Python interpreter that has SCons installed. Defaults to $env:THEONE_PYTHON,
    then to the shared venv of the legacy project.

.EXAMPLE
    .\Tools\Build\Build-Native.ps1
    .\Tools\Build\Build-Native.ps1 -Target template_release -Jobs 12
#>
param(
    [ValidateSet('template_debug', 'template_release')]
    [string]$Target = 'template_debug',
    [int]$Jobs = 8,
    [string]$Python = $(if ($env:THEONE_PYTHON) { $env:THEONE_PYTHON } else { 'D:\VibeSpace\ProjectAbyss\.venv\Scripts\python.exe' })
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))

if (-not (Test-Path -LiteralPath $Python)) {
    throw "Python with SCons not found: $Python (pass -Python or set THEONE_PYTHON)"
}
$env:VSLANG = '1033'   # English MSVC output; avoids GBK mojibake

Push-Location $repo
try {
    & $Python -m SCons platform=windows "target=$Target" "-j$Jobs"
    $code = $LASTEXITCODE
} finally {
    Pop-Location
}

if ($code -ne 0) { throw "SCons failed with exit code $code" }
Write-Host "Built: Project/bin/theone.windows.$Target.x86_64.dll"