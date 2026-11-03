<#
.SYNOPSIS
    Load the built GDExtension in a headless engine run and verify class registration.

.DESCRIPTION
    The engine reads .godot/extension_list.cfg at startup, which the editor generates.
    A project that was never opened therefore needs one scan pass first.

.PARAMETER Engine
    Path to the Godot executable. Defaults to $env:THEONE_ENGINE, then to the
    legacy project's custom engine build.

.EXAMPLE
    .\Tools\Build\Test-Extension.ps1
#>
param(
    [string]$Engine = $(if ($env:THEONE_ENGINE) { $env:THEONE_ENGINE } else { 'D:\VibeSpace\ProjectAbyss\Engine\bin\godot.windows.editor.x86_64.console.exe' })
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$project = Join-Path $repo 'Project'

if (-not (Test-Path -LiteralPath $Engine)) { throw "Engine not found: $Engine (pass -Engine or set THEONE_ENGINE)" }

# 1. Ensure the extension list exists (editor scan, no window).
& $Engine --headless --editor --quit --path $project | Out-Null

# 2. Run the smoke script.
& $Engine --headless --path $project --script 'res://Tests/smoke_extension.gd'
if ($LASTEXITCODE -ne 0) { throw "Extension smoke test failed (exit $LASTEXITCODE)" }