<#
.SYNOPSIS
    Create or refresh the project-local build environment with uv.

.DESCRIPTION
    Installs the Python interpreter pinned by .python-version and the dependencies in
    pyproject.toml (SCons) into .venv, using uv.lock for exact versions.

.PARAMETER PythonVersion
    Override the interpreter, e.g. -PythonVersion 3.13. Defaults to .python-version.

.EXAMPLE
    .\Tools\Build\setup-env.cmd
#>
param(
    [string]$PythonVersion
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    throw "uv not found. Install it first: https://docs.astral.sh/uv/ (winget install astral-sh.uv)"
}

Push-Location $repo
try {
    if ($PythonVersion) { & uv sync --python $PythonVersion } else { & uv sync }
    if ($LASTEXITCODE -ne 0) { throw "uv sync failed with exit code $LASTEXITCODE" }

    $py = Join-Path $repo '.venv\Scripts\python.exe'
    Write-Host ''
    Write-Host "Python : $(& $py --version)"
    & $py -m SCons --version | Select-Object -First 2
} finally {
    Pop-Location
}