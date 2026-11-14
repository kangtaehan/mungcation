param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Require-File([string]$relative) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relative))) {
        $failures.Add("Missing required file: $relative")
    }
}

foreach ($file in @(
    'pubspec.yaml',
    'pubspec.lock',
    'lib\main.dart',
    'lib\main_preview.dart',
    'android\app\src\main\AndroidManifest.xml',
    'ios\Podfile',
    'ios\Runner\Info.plist',
    'ios\Runner.xcodeproj\project.pbxproj',
    'codemagic.yaml',
    'PRIVACY.md'
)) { Require-File $file }

$pubspec = Get-Content -LiteralPath (Join-Path $root 'pubspec.yaml') -Raw -Encoding UTF8
if ($pubspec -notmatch '(?m)^version:\s+\d+\.\d+\.\d+\+\d+\s*$') {
    $failures.Add('pubspec.yaml needs a semantic version and build number.')
}

$plistPath = Join-Path $root 'ios\Runner\Info.plist'
try { [xml](Get-Content -LiteralPath $plistPath -Raw -Encoding UTF8) | Out-Null }
catch { $failures.Add('ios/Runner/Info.plist is not valid XML.') }

$project = Get-Content -LiteralPath (Join-Path $root 'ios\Runner.xcodeproj\project.pbxproj') -Raw -Encoding UTF8
foreach ($source in @('MungcationMapPlugin.swift', 'MungcationFilesPlugin.swift')) {
    if ($project -notmatch [regex]::Escape($source)) {
        $failures.Add("iOS project does not reference $source")
    }
}

$sensitiveExtensions = @('*.p8', '*.p12', '*.mobileprovision', '*.jks', '*.keystore')
foreach ($pattern in $sensitiveExtensions) {
    $found = Get-ChildItem -LiteralPath $root -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike '*\.dart_tool\*' -and $_.FullName -notlike '*\build\*' }
    if ($found) { $failures.Add("Signing credential found in project: $($found[0].FullName)") }
}

if ($project -match 'PRODUCT_BUNDLE_IDENTIFIER = com\.mungcation\.mungcation;') {
    $warnings.Add('Bundle ID is still the temporary com.mungcation.mungcation value.')
}
if ((Get-Content -LiteralPath (Join-Path $root 'PRIVACY.md') -Raw -Encoding UTF8) -match 'DRAFT_STATUS: pre-release') {
    $warnings.Add('PRIVACY.md still needs operator contact details and a public URL before store submission.')
}

if ($failures.Count -gt 0) {
    Write-Host 'Preflight failed:' -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
Write-Host 'Preflight checks passed.' -ForegroundColor Green
if ($warnings.Count -gt 0) {
    Write-Host 'Before store submission:' -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  - $_" }
}
