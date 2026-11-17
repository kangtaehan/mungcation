param(
    [string]$SdkRoot = $env:ANDROID_HOME,
    [string]$WorkRoot,
    [string]$OutputRoot,
    [string]$GradleCacheRoot
)
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
if (-not $SdkRoot) {
    if (Test-Path -LiteralPath 'D:\MungcationDev\Android\Sdk\platforms\android-36\android.jar') { $SdkRoot = 'D:\MungcationDev\Android\Sdk' }
    elseif (Test-Path -LiteralPath 'C:\Android\Sdk') { $SdkRoot = 'C:\Android\Sdk' }
    else { $SdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
}
if (-not (Test-Path -LiteralPath (Join-Path $SdkRoot 'platforms\android-36\android.jar'))) { throw 'Android SDK 36 is required. Install Android Studio SDK tools or run tool/install_android_sdk.ps1 after reviewing its license option.' }
if (-not $WorkRoot) { $WorkRoot = Join-Path $SdkRoot '..\..\Builds' }
$WorkRoot = [System.IO.Path]::GetFullPath($WorkRoot)
if (-not $GradleCacheRoot) { $GradleCacheRoot = Join-Path $WorkRoot 'gradle-cache' }
New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null
$buildPath = Join-Path $WorkRoot ('mungcation-android-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $buildPath | Out-Null
foreach ($name in @('lib','android','assets','pubspec.yaml','pubspec.lock','analysis_options.yaml')) { Copy-Item -LiteralPath (Join-Path $sourceRoot $name) -Destination $buildPath -Recurse }
$previousAndroid = $env:ANDROID_HOME
$previousAndroidRoot = $env:ANDROID_SDK_ROOT
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$previousGradle = $env:GRADLE_USER_HOME
$previousPubCache = $env:PUB_CACHE
$previousDebug = $env:DEBUG
try {
    $env:ANDROID_HOME = [System.IO.Path]::GetFullPath($SdkRoot)
    $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
    $env:TEMP = $buildPath
    $env:TMP = $buildPath
    $env:GRADLE_USER_HOME = [System.IO.Path]::GetFullPath($GradleCacheRoot)
    $env:PUB_CACHE = Join-Path $WorkRoot 'pub-cache'
    $env:DEBUG = $null
    Push-Location -LiteralPath $buildPath
    try {
        flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }
        flutter build apk --debug
        if ($LASTEXITCODE -ne 0) { throw 'Android debug APK build failed.' }
    } finally { Pop-Location }
    $builtApk = Join-Path $buildPath 'build\app\outputs\flutter-apk\app-debug.apk'
    function Copy-BuiltApk([string]$destination) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        $partial = Join-Path $destination 'app-debug.apk.partial'
        try {
            Copy-Item -LiteralPath $builtApk -Destination $partial -Force
            Move-Item -LiteralPath $partial -Destination (Join-Path $destination 'app-debug.apk') -Force
        } finally {
            if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }
        }
    }
    $defaultOutput = -not $OutputRoot
    if ($defaultOutput) { $OutputRoot = Join-Path $sourceRoot 'artifacts\android' }
    try { Copy-BuiltApk $OutputRoot }
    catch [System.IO.IOException] {
        if (-not $defaultOutput) { throw }
        $OutputRoot = Join-Path (Split-Path -Parent $WorkRoot) 'artifacts\android'
        Write-Warning "Project drive copy failed; saving APK beside the build drive: $OutputRoot"
        Copy-BuiltApk $OutputRoot
    }
    $apk = Join-Path $OutputRoot 'app-debug.apk'
    Write-Output "APK ready: $apk"
    Get-FileHash -LiteralPath $apk -Algorithm SHA256 | Select-Object Algorithm,Hash
} finally {
    $env:ANDROID_HOME = $previousAndroid
    $env:ANDROID_SDK_ROOT = $previousAndroidRoot
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    $env:GRADLE_USER_HOME = $previousGradle
    $env:PUB_CACHE = $previousPubCache
    $env:DEBUG = $previousDebug
    Write-Output "Android build workspace retained: $buildPath"
}
