# DEMO2 3D 统一「做完即传」标准导出（在 3D 工作树/分支上执行）
# 用法：powershell -File tools/export-web-3d.ps1 -Version demo-02-3d-vN [-Notes "..."]
# 流程：console exe 导出 Web → 无 BOM build.json → 拷贝到主仓库 builds/ →（主仓库轮）demos.json slot + push 触发 Pages → curl 验证
# 标准约定（2026-10-04 用户指令「统一标准 做完就能传」）：3D 版本完成即按本脚本导出并上 Pages，不等阶段收尾。
param(
  [string]$Version = "demo-02-3d-v1",
  [string]$Notes = "DEMO2 3D build",
  [string]$MainRepo = "D:\GIT\taptap2026"
)
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent
$godot = Join-Path $MainRepo "tools\godot\Godot_v4.7.2-stable_win64_console.exe"
$outDir = Join-Path $MainRepo "builds\$Version"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

& $godot --headless --path (Join-Path $repo "game") --export-release "Web" (Join-Path $outDir "index.html")
if ($LASTEXITCODE -ne 0) { throw "Godot export failed (exit $LASTEXITCODE)" }

$meta = [ordered]@{
  title   = "TapTap2026 Demo"
  version = $Version
  date    = (Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
  author  = $env:USERNAME
  notes   = $Notes
}
# 无 BOM 写出（PS5.1 的 -Encoding UTF8 会带 BOM）
[System.IO.File]::WriteAllText((Join-Path $outDir "build.json"), ($meta | ConvertTo-Json) + "`n")
Write-Host "OK: $Version exported to $outDir" -ForegroundColor Green
Write-Host "主仓库轮：git add builds/$Version → demos.json slot(buildId=$Version) → push 触发 Pages → curl 验证 build.json"
