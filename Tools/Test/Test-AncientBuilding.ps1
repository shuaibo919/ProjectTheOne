<#
.SYNOPSIS
    Run the AncientBuilding acceptance suite (M1-M5).

.DESCRIPTION
    Runs the GDScript checks and exercises the headless CLI:
    build -> bake -> inspect -> convert -> inspect -> revert -> inspect.

.PARAMETER Engine
    Godot executable. Defaults to $env:THEONE_ENGINE, then the legacy engine build.

.EXAMPLE
    .\Tools\Test\Test-AncientBuilding.ps1
#>
param(
    [string]$Engine = $(if ($env:THEONE_ENGINE) { $env:THEONE_ENGINE } else { 'D:\VibeSpace\ProjectAbyss\Engine\bin\godot.windows.editor.x86_64.console.exe' })
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$project = Join-Path $repo 'Project'
$cli = 'res://addons/ancient_building/cli/main.gd'
$scenePath = 'res://Generated/AncientBuilding/Samples/DA_House_A.tscn'
$sceneFile = Join-Path $project 'Generated\AncientBuilding\Samples\DA_House_A.tscn'
$failures = 0

if (-not (Test-Path -LiteralPath $Engine)) { throw "Engine not found: $Engine (pass -Engine or set THEONE_ENGINE)" }

function Check([bool]$condition, [string]$label) {
    if ($condition) {
        Write-Host "ok   $label"
    } else {
        Write-Host "FAIL $label" -ForegroundColor Red
        $script:failures++
    }
}

function Run-Godot([string[]]$arguments) {
    $output = & $Engine --headless --path $project @arguments 2>&1 | Out-String
    return @{ Code = $LASTEXITCODE; Text = $output }
}

function Run-Cli([string[]]$arguments) {
    $result = Run-Godot (@('--script', $cli, '--') + $arguments)
    $index = $result.Text.IndexOf('{')
    $json = if ($index -ge 0) { $result.Text.Substring($index) } else { '' }
    return @{ Code = $result.Code; Json = $json; Text = $result.Text }
}

Write-Host "Engine : $Engine"
Write-Host "Project: $project"
Write-Host ''

# The engine reads .godot/extension_list.cfg; generate it before any headless run.
& $Engine --headless --editor --quit --path $project | Out-Null

foreach ($check in @(
        'res://Tests/Checks/test_module_key.gd',
        'res://Tests/Checks/test_layout.gd',
        'res://Tests/Checks/test_roof.gd',
        'res://Tests/Checks/test_batch.gd')) {
    $result = Run-Godot @('--script', $check)
    Check ($result.Code -eq 0) "unit check $([IO.Path]::GetFileName($check))"
}

if (Test-Path -LiteralPath $sceneFile) { Remove-Item -LiteralPath $sceneFile -Force }

$build = Run-Cli @('build', '--file', 'res://addons/ancient_building/resources/presets/DA_House_A.json')
Check ($build.Code -eq 0) 'CLI build exits 0'
$buildJson = $build.Json | ConvertFrom-Json
Check ($buildJson.instances -eq 46) "build reports 46 instances (got $($buildJson.instances))"
Check ($buildJson.unique_meshes -eq 9) "build reports 9 unique meshes (got $($buildJson.unique_meshes))"
Check ($buildJson.errors.Count -eq 0) 'build reports no errors'

$bake = Run-Cli @('bake', '--file', 'res://addons/ancient_building/resources/presets/DA_House_A.json', '--out', $scenePath)
Check ($bake.Code -eq 0) 'CLI bake exits 0'
Check (Test-Path -LiteralPath $sceneFile) 'baked scene file exists'

$individual = Run-Cli @('inspect', '--scene', $scenePath) | ForEach-Object { $_.Json | ConvertFrom-Json }
Check ($individual.children -eq 46) "baked scene holds 46 nodes (got $($individual.children))"
Check ($individual.types.MeshInstance3D -eq 46) 'baked scene nodes are MeshInstance3D'

$convert = Run-Cli @('convert', '--scene', $scenePath)
Check ($convert.Code -eq 0) 'CLI convert exits 0'
$convertJson = $convert.Json | ConvertFrom-Json
Check ($convertJson.groups -eq 9) "convert groups 46 nodes into 9 MultiMeshes (got $($convertJson.groups))"
Check ($convertJson.instances -eq 46) 'convert keeps 46 instances'

$batched = Run-Cli @('inspect', '--scene', $scenePath) | ForEach-Object { $_.Json | ConvertFrom-Json }
Check ($batched.children -eq 9) "converted scene holds 9 MultiMesh nodes (got $($batched.children))"
Check ($batched.types.MultiMeshInstance3D -eq 9) 'converted nodes are MultiMeshInstance3D'

$revert = Run-Cli @('revert', '--scene', $scenePath)
Check ($revert.Code -eq 0) 'CLI revert exits 0'

$restored = Run-Cli @('inspect', '--scene', $scenePath) | ForEach-Object { $_.Json | ConvertFrom-Json }
Check ($restored.children -eq 46) "reverted scene holds 46 nodes (got $($restored.children))"
Check ($restored.layout_hash -eq $buildJson.layout_hash) 'layout hash survives bake/convert/revert'

Write-Host ''
if ($failures -gt 0) {
    Write-Host "ANCIENTBUILDING CHECK FAILED: $failures assertion(s)" -ForegroundColor Red
    exit 1
}
Write-Host 'ANCIENTBUILDING CHECK PASSED'
exit 0
