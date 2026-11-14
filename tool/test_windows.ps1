param()
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$tempRoot = [System.IO.Path]::GetFullPath((Join-Path $env:SystemRoot 'Temp'))
$workPath = Join-Path $tempRoot ('mungcation-tests-' + [guid]::NewGuid().ToString('N'))
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
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
        flutter test --concurrency=1 --reporter expanded
        $resultCode = $LASTEXITCODE
    } finally { Pop-Location }
} finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    Write-Host ("Test workspace retained for inspection: $workPath")

}
exit $resultCode

