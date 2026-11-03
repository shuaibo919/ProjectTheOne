<#
.SYNOPSIS
    Load the built GDExtension in a headless engine run and verify class registration.

.DESCRIPTION
    The engine reads .godot/extension_list.cfg at startup, which the editor generates.
    A project that was never opened therefore needs one scan pass first.

    Engine resolution order:
      1. -Engine parameter
      2. $env:THEONE_ENGINE
      3. Engine/bin/ (a locally built engine)
      4. the legacy ProjectAbyss engine binary (same 4.7 fork commit)

.EXAMPLE
    .\Tools\Build\test-extension.cmd
#>
param(
    [string]$Engine
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$project = Join-Path $repo 'Project'

if (-not $Engine) {
    if ($env:THEONE_ENGINE) {
        $Engine = $env:THEONE_ENGINE
    } else {
        $local = Join-Path $repo 'Engine\bin\godot.windows.editor.x86_64.console.exe'
        $legacy = 'D:\VibeSpace\ProjectAbyss\Engine\bin\godot.windows.editor.x86_64.console.exe'
        $Engine = if (Test-Path -LiteralPath $local) { $local } else { $legacy }
    }
}
if (-not (Test-Path -LiteralPath $Engine)) {
    throw "Engine not found: $Engine`nPass -Engine or set THEONE_ENGINE (or build Engine/ first)."
}

Write-Host "Engine  : $Engine"
Write-Host "Project : $project"

# 1. Ensure the extension list exists (editor scan, no window).
& $Engine --headless --editor --quit --path $project | Out-Null

# 2. Run the smoke script.
& $Engine --headless --path $project --script 'res://Tests/smoke_extension.gd'
if ($LASTEXITCODE -ne 0) { throw "Extension smoke test failed (exit $LASTEXITCODE)" }