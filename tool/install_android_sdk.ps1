param(
    [string]$SdkRoot = 'C:\Android\Sdk',
    [switch]$AcceptSdkLicenses
)
$ErrorActionPreference = 'Stop'
if (-not $AcceptSdkLicenses) {
    throw 'Review https://developer.android.com/studio/terms and rerun with -AcceptSdkLicenses only after agreeing to the Android SDK license.'
}
$resolvedSdk = [System.IO.Path]::GetFullPath($SdkRoot)
if ($resolvedSdk.TrimEnd('\') -eq [System.IO.Path]::GetPathRoot($resolvedSdk).TrimEnd('\')) { throw 'Choose a dedicated SDK directory, not a drive root.' }
New-Item -ItemType Directory -Path $resolvedSdk -Force | Out-Null
$manager = Join-Path $resolvedSdk 'cmdline-tools\latest\bin\sdkmanager.bat'
if (-not (Test-Path -LiteralPath $manager)) {
    $downloads = Join-Path $resolvedSdk '.downloads'
    New-Item -ItemType Directory -Path $downloads -Force | Out-Null
    $archive = Join-Path $downloads 'commandlinetools-win-15859902_latest.zip'
    $expectedHash = '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a'
    if (-not (Test-Path -LiteralPath $archive)) {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip' -OutFile $archive
    }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) { throw 'Android command-line tools checksum mismatch.' }
    $expanded = Join-Path $downloads 'commandlinetools-15859902'
    if (-not (Test-Path -LiteralPath (Join-Path $expanded 'cmdline-tools\bin\sdkmanager.bat'))) { Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force }
    $latest = Join-Path $resolvedSdk 'cmdline-tools\latest'
    New-Item -ItemType Directory -Path $latest -Force | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $expanded 'cmdline-tools') -Force | Copy-Item -Destination $latest -Recurse -Force
}
if (-not $env:JAVA_HOME -and (Test-Path -LiteralPath 'C:\Program Files\Java\jdk-23')) { $env:JAVA_HOME = 'C:\Program Files\Java\jdk-23' }
1..100 | ForEach-Object { 'y' } | & $manager "--sdk_root=$resolvedSdk" --licenses
if ($LASTEXITCODE -ne 0) { throw 'Android SDK license acceptance did not complete.' }
& $manager "--sdk_root=$resolvedSdk" 'platform-tools' 'platforms;android-35' 'platforms;android-36' 'build-tools;35.0.0' 'build-tools;36.0.0' 'ndk;28.2.13676358' 'cmake;3.22.1'
if ($LASTEXITCODE -ne 0) { throw 'Android SDK package installation failed.' }
Write-Output "Android SDK ready: $resolvedSdk"
