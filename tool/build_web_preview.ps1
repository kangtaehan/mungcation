param(
    [string]$WorkRoot = 'D:\MungcationDev\WebBuilds',
    [string]$OutputRoot = 'D:\MungcationDev\artifacts\web-preview',
    [string]$BaseHref = '/'
)
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$workRootPath = [System.IO.Path]::GetFullPath($WorkRoot)
$outputRootPath = [System.IO.Path]::GetFullPath($OutputRoot)
$buildPath = Join-Path $workRootPath ('mungcation-web-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $buildPath -Force | Out-Null
foreach ($name in @('lib', 'web', 'assets', 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml')) {
    Copy-Item -LiteralPath (Join-Path $sourceRoot $name) -Destination $buildPath -Recurse
}
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$previousPubCache = $env:PUB_CACHE
try {
    $env:TEMP = $buildPath
    $env:TMP = $buildPath
    $env:PUB_CACHE = 'D:\MungcationDev\Builds\pub-cache'
    Push-Location -LiteralPath $buildPath
    try {
        flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }
        flutter build web --target lib/main_preview.dart --release --base-href $BaseHref
        if ($LASTEXITCODE -ne 0) { throw 'Flutter web preview build failed.' }
    } finally {
        Pop-Location
    }
    New-Item -ItemType Directory -Path $outputRootPath -Force | Out-Null
    Copy-Item -Path (Join-Path $buildPath 'build\web\*') -Destination $outputRootPath -Recurse -Force
    Write-Output "Web preview ready: $outputRootPath"
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    $env:PUB_CACHE = $previousPubCache
    Write-Output "Web build workspace retained: $buildPath"
}
