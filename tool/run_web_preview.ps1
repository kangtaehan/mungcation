param(
    [int]$Port = 8080,
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $sourceRoot
try {
    $outputRoot = 'D:\MungcationDev\artifacts\web-preview'
    if (-not $SkipBuild) {
        & (Join-Path $PSScriptRoot 'build_web_preview.ps1') -OutputRoot $outputRoot
        if ($LASTEXITCODE -ne 0) { throw 'Web preview build failed.' }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $outputRoot 'index.html'))) {
        throw 'Web preview is missing. Run without -SkipBuild first.'
    }
    $addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        Select-Object -ExpandProperty IPAddress -Unique
    Write-Host 'iPhone과 노트북을 같은 Wi-Fi에 연결한 뒤 아래 주소를 Safari에서 여세요:'
    foreach ($address in $addresses) { Write-Host ("  http://{0}:{1}" -f $address, $Port) }
    Write-Host '종료: Ctrl+C'
    python -m http.server $Port --bind 0.0.0.0 --directory $outputRoot
    if ($LASTEXITCODE -ne 0) { throw 'Web preview server failed.' }
} finally {
    Pop-Location
}
