param([string[]]$TestFiles = @(), [switch]$Browser)
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $env:SystemRoot 'Temp'))
$workPath = Join-Path $tempRoot ('mungcation-tests-' + [guid]::NewGuid().ToString('N'))
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$previousChrome = $env:CHROME_EXECUTABLE
$resultCode = 1
try {
    New-Item -ItemType Directory -Path $workPath | Out-Null
    foreach ($name in @('lib','test','assets','pubspec.yaml','pubspec.lock','analysis_options.yaml')) {
        Copy-Item -LiteralPath (Join-Path $sourceRoot $name) -Destination $workPath -Recurse
    }
    $env:TEMP = $workPath
    $env:TMP = $workPath
    Push-Location -LiteralPath $workPath
    try {
        flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }
        if ($Browser) {
            New-Item -ItemType Directory -Path (Join-Path $workPath 'test/fixtures') -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $workPath 'assets/data/national_parks.json') -Destination (Join-Path $workPath 'test/fixtures/national_parks.json')
            if (-not $env:CHROME_EXECUTABLE) {
                $edge = Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'
                if (Test-Path -LiteralPath $edge) { $env:CHROME_EXECUTABLE = $edge }
            }
            # Supply the installed package map: some prebuilt Windows Flutter
            # snapshots retain the SDK builder's absolute browser resource path.
            $flutterRoot = Split-Path -Parent (Split-Path -Parent (Get-Command flutter).Source)
            $dartTool = Join-Path $flutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
            $flutterSnapshot = Join-Path $flutterRoot 'bin\cache\flutter_tools.snapshot'
            $toolPackages = Join-Path $flutterRoot 'packages\flutter_tools\.dart_tool\package_config.json'
            & $dartTool "--packages=$toolPackages" $flutterSnapshot test @TestFiles --platform chrome --reporter expanded
        } else {
            flutter test @TestFiles --concurrency=1 --reporter expanded
        }
        $resultCode = $LASTEXITCODE
    } finally { Pop-Location }
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    $env:CHROME_EXECUTABLE = $previousChrome
    Write-Host ("Test workspace retained for inspection: $workPath")

}
exit $resultCode

