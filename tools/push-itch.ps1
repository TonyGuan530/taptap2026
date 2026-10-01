# Push a build to itch.io with butler (official CLI).
# Usage:
#   .\tools\push-itch.ps1 -Version v0.0.1-demo -ApiKey YOUR_KEY
#   .\tools\push-itch.ps1 -Version v0.0.1-demo                 (uses BUTLER_API_KEY env / saved butler login)
#   .\tools\push-itch.ps1                                      (auto-picks newest build)
param(
  [string]$Version = "",
  [string]$ApiKey = "",
  [string]$Target = "sxguan/taptap2026",
  [string]$Channel = "html",
  [string]$UserVersion = ""
)
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
$builds = Join-Path $repo "builds"
$butler = Join-Path $PSScriptRoot "butler\butler.exe"
if (-not (Test-Path $butler)) { throw "butler.exe not found (expected tools/butler/butler.exe)" }

if (-not $Version) {
  $latest = Get-ChildItem $builds -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "index.html") } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $latest) { throw "No build with index.html found under builds/" }
  $Version = $latest.Name
}
$src = Join-Path $builds $Version
if (-not $UserVersion) { $UserVersion = $Version }

$pushArgs = @("push", $src, "$Target`:$Channel", "--userversion", $UserVersion)

# 没显式给 Key 时，自动读本机 data/secrets.json（Review 站 /key 页保存的 itch Key）
if (-not ($ApiKey -or $env:BUTLER_API_KEY)) {
  $secretsPath = Join-Path $repo "data\secrets.json"
  if (Test-Path $secretsPath) {
    try {
      $j = Get-Content $secretsPath -Raw | ConvertFrom-Json
      if ($j.latest.value) { $ApiKey = $j.latest.value }
    } catch { }
  }
}

$keyFile = $null
if ($ApiKey -or $env:BUTLER_API_KEY) {
  $keyValue = if ($ApiKey) { $ApiKey } else { $env:BUTLER_API_KEY }
  $keyFile = Join-Path $env:TEMP "butler_creds.txt"
  Set-Content -Path $keyFile -Value $keyValue -NoNewline
  $pushArgs += @("-i", $keyFile)
}

Write-Host "Pushing builds/$Version -> $Target`:$Channel (userversion $UserVersion) ..."
& $butler @pushArgs
if ($LASTEXITCODE -ne 0) { throw "butler push failed (exit $LASTEXITCODE). If it is a network error, try again or push from CI instead." }
Write-Host ""
Write-Host "OK: https://$($Target.Split('/')[0]).itch.io/$($Target.Split('/')[1])" -ForegroundColor Green
