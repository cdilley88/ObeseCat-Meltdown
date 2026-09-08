param([string]$Godot)
$ErrorActionPreference = 'Stop'
if (-not $Godot) { $Godot = Join-Path $env:TEMP 'obesecat-godot\Godot_v4.7.2-stable_win64_console.exe' }
$projectRoot = $PSScriptRoot
$output = Join-Path $projectRoot 'builds\web'
New-Item -ItemType Directory -Force (Join-Path $output 'game') | Out-Null
$oldAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $projectRoot '.godot\portable-data'
    & $Godot --headless --path $projectRoot --export-release Web (Join-Path $output 'game\index.html') --log-file (Join-Path $projectRoot 'build-web.log')
    if ($LASTEXITCODE -ne 0) { throw 'Web export failed. See build-web.log.' }
    Copy-Item (Join-Path $projectRoot 'web\index.html') (Join-Path $output 'index.html') -Force
    Write-Output "Browser build ready: $output"
} finally { $env:APPDATA = $oldAppData }
