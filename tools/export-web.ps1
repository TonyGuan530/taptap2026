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
$proj = Get-Content (Join-Path $repo "game\project.godot") -Raw
if ($proj -match 'run/main_scene="([^"]+)"') {
  $mainScene = $Matches[1]
  if ($proj -match 'run/main_scene="res://(demo\d+)[^"]*"') {
    $scenePrefix = $Matches[1]
    # demo-06-v5 → demo06（去掉版本尾巴与连字符）再比前缀，否则 demo-06 永远匹配不上 demo06
    $verPrefix = ($Version -replace '-v\d+', '') -replace '-', ''
    if (-not $verPrefix.StartsWith($scenePrefix)) {
      throw "main_scene=$scenePrefix but version=$Version (prefix mismatch) - refusing to export the wrong game"
    }
  }
  # pck 瘦身：按当前 main_scene 只导出该场景及其依赖（全项目 all_resources 曾致单 pck 15MB）
  # 每次导出前重写预设——并行任务各自调用本脚本时会按各自的 main_scene 自愈
  $presetPath = Join-Path $repo "game\export_presets.cfg"
  $preset = Get-Content $presetPath -Raw
  $preset = $preset -replace 'export_filter="[^"]*"', 'export_filter="selected_scenes"'
  $sceneEntry = 'export_scenes=PackedStringArray("' + $mainScene + '")'
  if ($preset -match 'export_scenes=PackedStringArray\([^)]*\)') {
    $preset = $preset -replace 'export_scenes=PackedStringArray\([^)]*\)', $sceneEntry
  } else {
    $preset = $preset -replace 'export_filter="selected_scenes"', ('export_filter="selected_scenes"' + "`r`n" + $sceneEntry)
  }
  [System.IO.File]::WriteAllText($presetPath, $preset)
}
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
