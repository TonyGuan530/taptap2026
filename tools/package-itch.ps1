# Package the latest (or given) build into a zip ready for itch.io upload.
# Usage: .\tools\package-itch.ps1 [-Version v0.0.1-demo]   (no args = newest build)
param([string]$Version = "")
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
$builds = Join-Path $repo "builds"

if (-not $Version) {
  $latest = Get-ChildItem $builds -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "index.html") } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $latest) { throw "No build with index.html found under builds/" }
  $Version = $latest.Name
}

$src = Join-Path $builds $Version
$dist = Join-Path $repo "dist-itch"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist "$Version.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path (Join-Path $src "*") -DestinationPath $zip

Write-Host ""
Write-Host "OK: $zip" -ForegroundColor Green
Write-Host ""
Write-Host "itch.io upload steps:" -ForegroundColor Cyan
Write-Host "  1. https://itch.io/game/new  (or Dashboard -> Create new project)"
Write-Host "  2. Kind of project: HTML"
Write-Host "  3. Upload this zip, tick 'This file will be played in the browser'"
Write-Host "  4. Viewport: 960 x 540"
Write-Host "  5. Save & view page -> published instantly, no review"
Write-Host "  6. Semi-private playtest: set Visibility to Restricted, share the link"
