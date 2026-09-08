param([string]$Godot, [switch]$Test, [switch]$Editor)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
if (-not $Godot) {
    $portable = Join-Path $env:TEMP 'obesecat-godot'
    $Godot = Join-Path $portable 'Godot_v4.7.2-stable_win64_console.exe'
    if (-not (Test-Path -LiteralPath $Godot)) {
        $command = Get-Command godot -ErrorAction SilentlyContinue
        if ($command) { $Godot = $command.Source }
    }
    if (-not (Test-Path -LiteralPath $Godot)) {
        $archive = Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64.exe.zip'
        if (-not (Test-Path -LiteralPath $archive)) {
            throw 'Pass -Godot with the path to your Godot 4 executable, or add godot to PATH.'
        }
        Expand-Archive -LiteralPath $archive -DestinationPath $portable -Force
    }
}
# Keep this prototype portable, including saves and editor caches.
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $projectRoot '.godot\portable-data'
    $env:LOCALAPPDATA = Join-Path $projectRoot '.godot\portable-cache'
    if ($Test) {
        & $Godot --headless --path $projectRoot --editor --import --quit
        if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
        & $Godot --headless --path $projectRoot --script tests/test_reactor.gd
    } elseif ($Editor) {
        & $Godot --path $projectRoot --editor
    } else {
        & $Godot --path $projectRoot
    }
    if ($LASTEXITCODE -ne 0) { throw "Godot exited with code $LASTEXITCODE" }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}
