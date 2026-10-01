# Export the Godot project to a Web build and register it in the review site.
# Usage: .\tools\export-web.ps1 [-Version v0.0.2] [-Notes "fix xxx"] [-GodotPath godot]
param(
  [string]$Version = ("v" + (Get-Date -Format "yyyy.MMdd-HHmm")),
  [string]$Notes = "",
  [string]$GodotPath = "godot"
)
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
$buildDir = Join-Path $repo "builds\$Version"

& $GodotPath --headless --path (Join-Path $repo "game") --export-release "Web" (Join-Path $buildDir "index.html")
if ($LASTEXITCODE -ne 0) {
  throw "Godot export failed (exit $LASTEXITCODE). Make sure Godot 4.x is installed and Export Templates are downloaded (Editor -> Manage Export Templates)."
}

$meta = [ordered]@{
  title   = "TapTap2026 Demo"
  version = $Version
  date    = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
  author  = $env:USERNAME
  notes   = $Notes
}
$meta | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $buildDir "build.json")

Write-Host ""
Write-Host "OK: exported build builds/$Version" -ForegroundColor Green
Write-Host "   Start the review site (node server/server.js) to playtest it;"
Write-Host "   or run tools/package-itch.ps1 -Version $Version to build an itch.io zip."
