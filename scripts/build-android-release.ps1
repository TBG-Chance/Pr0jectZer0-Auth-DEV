[CmdletBinding()]
param(
    [string]$VersionName = "0.6.0-beta.1",

    [ValidateRange(1, 2100000000)]
    [int]$BuildNumber = 1,

    [string]$Flutter = "C:\src\flutter\bin\flutter.bat",

    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$KeyProperties = Join-Path $Repository "android\key.properties"
if (-not (Test-Path -LiteralPath $KeyProperties -PathType Leaf)) {
    throw "android\key.properties is required. Follow docs\ANDROID_BETA_RELEASE.md to configure the upload key."
}
if (-not (Test-Path -LiteralPath $Flutter -PathType Leaf)) {
    throw "Flutter was not found at $Flutter. Pass the installed flutter.bat path."
}

Push-Location $Repository
try {
    & $Flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "Flutter dependency restore failed." }

    & $Flutter analyze
    if ($LASTEXITCODE -ne 0) { throw "Flutter analysis failed." }

    if (-not $SkipTests) {
        & $Flutter test
        if ($LASTEXITCODE -ne 0) { throw "Flutter tests failed." }
    }

    & $Flutter build appbundle --release --build-name $VersionName --build-number $BuildNumber
    if ($LASTEXITCODE -ne 0) { throw "Signed Android App Bundle build failed." }
}
finally {
    Pop-Location
}

$bundle = Join-Path $Repository "build\app\outputs\bundle\release\app-release.aab"
if (-not (Test-Path -LiteralPath $bundle -PathType Leaf)) {
    throw "The signed Android App Bundle was not created."
}

$ReleaseDirectory = Join-Path $Repository "release\android"
New-Item -ItemType Directory -Force -Path $ReleaseDirectory | Out-Null
$ReleaseBundle = Join-Path $ReleaseDirectory "Pr0jectZer0-Auth-$VersionName-$BuildNumber.aab"
Copy-Item -LiteralPath $bundle -Destination $ReleaseBundle -Force
$hash = (Get-FileHash -LiteralPath $ReleaseBundle -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $(Split-Path -Leaf $ReleaseBundle)" | Set-Content -LiteralPath ($ReleaseBundle + ".sha256") -Encoding ascii

$manifest = [ordered]@{
    product = "Pr0jectZer0 Auth"
    version_name = $VersionName
    version_code = $BuildNumber
    package_name = "com.pr0jectzer0.pr0jectzer0_auth"
    built_at = [DateTime]::UtcNow.ToString("o")
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ReleaseDirectory "build-manifest.json") -Encoding utf8
Write-Host "Signed Android beta bundle: $ReleaseBundle"
