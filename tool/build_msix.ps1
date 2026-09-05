<#
.SYNOPSIS
  Build MSIX for EastmarkHK Snowball (sideload or Microsoft Store).
  Run this on Windows from the repo root.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\build_msix.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\build_msix.ps1 -Store `
    -IdentityName "EastmarkHK.Snowball" `
    -Publisher "CN=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" `
    -PublisherDisplayName "EastmarkHK" `
    -MsixVersion "1.0.0.0"
#>

param(
  [switch]$Store,
  [string]$IdentityName = $env:EMHK_STORE_IDENTITY_NAME,
  [string]$Publisher = $env:EMHK_STORE_PUBLISHER,
  [string]$PublisherDisplayName = $env:EMHK_STORE_PUBLISHER_DISPLAY_NAME,
  [string]$MsixVersion = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Invoke-Flutter {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  if (Get-Command fvm -ErrorAction SilentlyContinue) {
    & fvm flutter @Args
  } else {
    & flutter @Args
  }
  if ($LASTEXITCODE -ne 0) { throw "flutter $($Args -join ' ') failed ($LASTEXITCODE)" }
}

Write-Host '==> flutter pub get'
Invoke-Flutter pub get

$defineArgs = @()
if (Test-Path (Join-Path $root 'dart_defines.json')) {
  $defineArgs += '--dart-define-from-file=dart_defines.json'
}

Write-Host '==> flutter build windows --release'
Invoke-Flutter build windows --release @defineArgs

$msixArgs = @()
if ($Store) {
  if ([string]::IsNullOrWhiteSpace($IdentityName)) {
    throw 'Store mode: -IdentityName required (Partner Center Package/Identity/Name).'
  }
  if ([string]::IsNullOrWhiteSpace($Publisher)) {
    throw 'Store mode: -Publisher required (Partner Center Package/Properties/Publisher).'
  }
  if ([string]::IsNullOrWhiteSpace($PublisherDisplayName)) {
    throw 'Store mode: -PublisherDisplayName required (PublisherDisplayName).'
  }
  $msixArgs += @(
    '--store',
    '--identity-name', $IdentityName,
    '--publisher', $Publisher,
    '--publisher-display-name', $PublisherDisplayName
  )
  Write-Host "==> Microsoft Store mode: $IdentityName"
} else {
  Write-Host '==> Sideload mode (local test certificate)'
}

if ([string]::IsNullOrWhiteSpace($MsixVersion) -and $Store) {
  $pubspec = Get-Content (Join-Path $root 'pubspec.yaml') -Raw
  if ($pubspec -match '(?m)^version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)') {
    $MsixVersion = "$($Matches[1]).$($Matches[2]).$($Matches[3]).0"
    Write-Host "==> Store version from pubspec: $MsixVersion"
  }
}
if (-not [string]::IsNullOrWhiteSpace($MsixVersion)) {
  if ($Store -and $MsixVersion -notmatch '^\d+\.\d+\.\d+\.0$') {
    throw "Store MSIX version must be x.y.z.0 (got '$MsixVersion')."
  }
  $msixArgs += @('--version', $MsixVersion)
}

Write-Host "==> dart run msix:create $msixArgs"
if (Get-Command fvm -ErrorAction SilentlyContinue) {
  & fvm dart run msix:create --build-windows false @msixArgs
} else {
  & dart run msix:create --build-windows false @msixArgs
}
if ($LASTEXITCODE -ne 0) { throw "msix:create failed ($LASTEXITCODE)" }

$outDir = Join-Path $root 'build\windows\x64\runner\Release'
$easyDir = Join-Path $root 'windows\build'

if (Test-Path $easyDir) { Remove-Item $easyDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $easyDir | Out-Null
& robocopy $outDir $easyDir /E /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Failed to copy Release bundle to windows\build (robocopy $LASTEXITCODE)" }
$global:LASTEXITCODE = 0

$exeEasy = Join-Path $easyDir 'eastmarkhk_snowball.exe'
$msixEasy = Get-ChildItem $easyDir -Filter '*.msix' -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
if (-not (Test-Path $exeEasy)) { throw "Missing exe after copy: $exeEasy" }
if (-not $msixEasy) { throw "Missing msix after copy in $easyDir" }

Write-Host "==> Ready folder: $easyDir"
Write-Host "    EXE : $exeEasy"
$sizeMb = [math]::Round($msixEasy.Length / 1MB, 1)
Write-Host "    MSIX: $($msixEasy.FullName) ($sizeMb MB)"
Write-Host '    Launch the EXE from this folder — DLLs and data\ must stay next to it.'
