param([string]$Godot, [string]$AndroidSdk, [string]$JavaSdk, [switch]$PatternTest)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
if (-not $Godot) { $Godot = Join-Path $env:TEMP 'obesecat-godot\Godot_v4.7.2-stable_win64_console.exe' }
if (-not $AndroidSdk) { $AndroidSdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
if (-not $JavaSdk) { $JavaSdk = Split-Path (Split-Path (Get-Command java -ErrorAction Stop).Source) }
$sourceData = Join-Path $projectRoot '.godot\portable-data\Godot'
$buildData = Join-Path $projectRoot '.godot\android-build\Godot'
$output = Join-Path $projectRoot $(if ($PatternTest) { 'builds\android\ObeseCatMeltdown-PatternTest.apk' } else { 'builds\android\ObeseCatMeltdown.apk' })
$presetName = if ($PatternTest) { 'Android Pattern Test' } else { 'Android' }
$version = (& $Godot --version).Trim()
if ($version -notmatch '^4\.7\.2\.') { throw "Expected Godot 4.7.2, found $version" }
$templates = 'export_templates\4.7.2.stable'
New-Item -ItemType Directory -Force -Path (Join-Path $buildData $templates),(Split-Path $output) | Out-Null
foreach ($file in @('android_debug.apk','android_release.apk')) {
    $source = Join-Path (Join-Path $sourceData $templates) $file
    $destination = Join-Path (Join-Path $buildData $templates) $file
    if (-not (Test-Path -LiteralPath $source)) { throw "Missing installed export template: $source" }
    if (-not (Test-Path -LiteralPath $destination) -or (Get-Item $source).LastWriteTimeUtc -gt (Get-Item $destination).LastWriteTimeUtc) {
        Copy-Item -LiteralPath $source -Destination $destination
    }
}
$settings = Get-Content -LiteralPath (Join-Path $sourceData 'editor_settings-4.7.tres') -Raw
$settings = $settings -replace '(?m)^export/android/android_sdk_path = .*$', ('export/android/android_sdk_path = "' + $AndroidSdk.Replace('\','/') + '"')
$settings = $settings -replace '(?m)^export/android/java_sdk_path = .*$', ('export/android/java_sdk_path = "' + $JavaSdk.Replace('\','/') + '"')
[IO.File]::WriteAllText((Join-Path $buildData 'editor_settings-4.7.tres'),$settings)
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
$oldJavaHome = $env:JAVA_HOME
try {
    $env:APPDATA = Split-Path $buildData
    $env:LOCALAPPDATA = Join-Path $projectRoot '.godot\android-build-cache'
    $env:JAVA_HOME = $JavaSdk
    & $Godot --headless --path $projectRoot --export-debug $presetName $output --log-file (Join-Path $projectRoot 'build-android.log')
    if ($LASTEXITCODE -ne 0) { throw 'Android export failed. See build-android.log.' }
    $buildTools = Get-ChildItem (Join-Path $AndroidSdk 'build-tools') -Directory | Sort-Object Name -Descending | Select-Object -First 1
    & (Join-Path $buildTools.FullName 'apksigner.bat') verify --verbose $output
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    Write-Output "Verified debug APK: $output"
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
    $env:JAVA_HOME = $oldJavaHome
}
