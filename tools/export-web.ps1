# Export the Godot project to a Web build and register it in the review site.
# Usage: .\tools\export-web.ps1 [-Version v0.0.2] [-Notes "fix xxx"] [-GodotPath godot]
param(
  [string]$Version = ("v" + (Get-Date -Format "yyyy.MMdd-HHmm")),
  [string]$Notes = "",
  [string]$GodotPath = ""
)
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
$buildDir = Join-Path $repo "builds\$Version"
# Godot 导出要求目标文件夹已存在
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

# 守卫：校验 main_scene 与版本号前缀一致（防打包错误游戏）
$proj = Get-Content (Join-Path $repo "gameproject.godot") -Raw
if ($proj -match 'run/main_scene="res://(demod+)[^"]*"') {
	$scenePrefix = $Matches[1]
	$verPrefix = ($Version -replace '-vd+
if (-not $GodotPath) {
  $bundled = Get-ChildItem (Join-Path $repo "tools\godot") -Filter "*_console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  $GodotPath = if ($bundled) { $bundled.FullName } else { "godot" }
}

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
# PS5.1 的 Set-Content -Encoding UTF8 会写 BOM，站点 JSON.parse 读 BOM 会失败，必须无 BOM 写出
$metaJson = $meta | ConvertTo-Json
[System.IO.File]::WriteAllText((Join-Path $buildDir "build.json"), $metaJson + "`n")

Write-Host ""
Write-Host "OK: exported build builds/$Version" -ForegroundColor Green
Write-Host "   Start the review site (node server/server.js) to playtest it;"
Write-Host "   or run tools/package-itch.ps1 -Version $Version to build an itch.io zip."
, '')
	if ($scenePrefix -ne $verPrefix) {
		throw "导出守卫：main_scene 是 $scenePrefix，但版本号是 $Version —— 先把 project.godot 的 main_scene 切到对应场景再导出"
	}
}

# 未指定 Godot 时优先用仓库自带的（tools/godot/），否则退回 PATH 里的 godot
if (-not $GodotPath) {
  $bundled = Get-ChildItem (Join-Path $repo "tools\godot") -Filter "*_console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  $GodotPath = if ($bundled) { $bundled.FullName } else { "godot" }
}

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
# PS5.1 的 Set-Content -Encoding UTF8 会写 BOM，站点 JSON.parse 读 BOM 会失败，必须无 BOM 写出
$metaJson = $meta | ConvertTo-Json
[System.IO.File]::WriteAllText((Join-Path $buildDir "build.json"), $metaJson + "`n")

Write-Host ""
Write-Host "OK: exported build builds/$Version" -ForegroundColor Green
Write-Host "   Start the review site (node server/server.js) to playtest it;"
Write-Host "   or run tools/package-itch.ps1 -Version $Version to build an itch.io zip."
