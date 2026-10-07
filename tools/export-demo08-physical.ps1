param(
  [string]$GodotPath = 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
  [switch]$Rebuild
)
$ErrorActionPreference = 'Stop'
$demoRoot = Split-Path $PSScriptRoot -Parent
$demoVersions = @(
  @{ Id='demo-08-3d-v27'; Scene='demo08_3d'; Title='纸飞机 · 3D 折纸与物理试飞（5关）'; Notes='五关：折法、低抛、逆风、侧风、顺风；真实纸面翻折、五步示范与回退；折后几何驱动三维近似气动力；自由试飞保留折法。' }
)
foreach ($demoVersion in $demoVersions) {
  $demoStage = Join-Path ([System.IO.Path]::GetTempPath()) ('taptap-demo08-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path (Join-Path $demoStage 'fonts') -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $demoRoot 'game\demo08_3d.tscn') -Destination $demoStage
  Copy-Item -LiteralPath (Join-Path $demoRoot 'game\demo08_3d') -Destination $demoStage -Recurse
  Copy-Item -LiteralPath (Join-Path $demoRoot 'game\fonts\NotoSansSC.ttf') -Destination (Join-Path $demoStage 'fonts')
  Copy-Item -LiteralPath (Join-Path $demoRoot 'game\icon.svg') -Destination $demoStage
  if ($demoVersion.Scene -eq 'demo08_3d') {
    Copy-Item -LiteralPath (Join-Path $demoRoot 'game\comic_style') -Destination $demoStage -Recurse
  }
  $demoProject = @"
config_version=5
[application]
config/name="$($demoVersion.Title)"
run/main_scene="res://$($demoVersion.Scene).tscn"
config/features=PackedStringArray("4.7")
config/icon="res://icon.svg"
[display]
window/size/viewport_width=960
window/size/viewport_height=540
window/stretch/mode="canvas_items"
[gui]
theme/custom_font="res://fonts/NotoSansSC.ttf"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
environment/defaults/default_clear_color=Color(0.06,0.075,0.1,1)
"@
  # Fresh imports must create the font cache before the project theme reads it.
  $demoImportProject = $demoProject -replace 'theme/custom_font="res://fonts/NotoSansSC.ttf"', ''
  [System.IO.File]::WriteAllText((Join-Path $demoStage 'project.godot'), $demoImportProject)
  $demoPreset = [System.IO.File]::ReadAllText((Join-Path $demoRoot 'game\export_presets.cfg'))
  $demoPreset = $demoPreset -replace 'export_scenes=PackedStringArray\([^)]*\)', ('export_scenes=PackedStringArray("res://' + $demoVersion.Scene + '.tscn")')
  [System.IO.File]::WriteAllText((Join-Path $demoStage 'export_presets.cfg'), $demoPreset)
  $demoOutput = Join-Path $demoRoot "builds\$($demoVersion.Id)"
  if ((Test-Path -LiteralPath (Join-Path $demoOutput 'index.html')) -and -not $Rebuild) {
    throw "Build already exists; choose a fresh version: $($demoVersion.Id)"
  }
  New-Item -ItemType Directory -Path $demoOutput -Force | Out-Null
  foreach ($demoStep in @('import','export')) {
    $demoArgs = @('--headless','--path',('"' + $demoStage + '"'))
    if ($demoStep -eq 'import') { $demoArgs += @('--editor','--import','--quit') }
    else {
      [System.IO.File]::WriteAllText((Join-Path $demoStage 'project.godot'), $demoProject)
      $demoArgs += @('--export-release','Web',('"' + (Join-Path $demoOutput 'index.html') + '"'))
    }
    $demoStdout = Join-Path $demoStage "$demoStep.stdout.log"
    $demoStderr = Join-Path $demoStage "$demoStep.stderr.log"
    $demoProcess = Start-Process -FilePath $GodotPath -ArgumentList $demoArgs -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $demoStdout -RedirectStandardError $demoStderr
    $demoLog = [System.IO.File]::ReadAllText($demoStdout) + [System.IO.File]::ReadAllText($demoStderr)
    if ($demoProcess.ExitCode -ne 0 -or $demoLog -match 'SCRIPT ERROR|(?m)^ERROR:') {
      Write-Output $demoLog
      throw "$($demoVersion.Id) $demoStep failed; exit=$($demoProcess.ExitCode) logs=$demoStage"
    }
    Write-Output "$($demoVersion.Id) $demoStep exit=$($demoProcess.ExitCode)"
  }
  foreach ($demoArtifact in @('index.html','index.js','index.wasm','index.pck')) {
    if (-not (Test-Path -LiteralPath (Join-Path $demoOutput $demoArtifact))) { throw "Missing export: $demoArtifact" }
  }
  $demoMeta = [ordered]@{ title=$demoVersion.Title; version=$demoVersion.Id; date=[DateTimeOffset]::UtcNow.ToString('o'); author='Codex'; notes=$demoVersion.Notes }
  [System.IO.File]::WriteAllText((Join-Path $demoOutput 'build.json'), (($demoMeta | ConvertTo-Json) -replace "`r`n", "`n") + "`n")
  $demoHtmlPath = Join-Path $demoOutput 'index.html'
  [System.IO.File]::WriteAllText($demoHtmlPath, [System.IO.File]::ReadAllText($demoHtmlPath).TrimEnd() + "`n")
  Copy-Item -LiteralPath (Join-Path $demoRoot 'game\demo08_3d\vendor\LICENSE-addmix.txt') -Destination $demoOutput
  Copy-Item -LiteralPath (Join-Path $demoRoot 'game\demo08_3d\vendor\README.md') -Destination (Join-Path $demoOutput 'THIRD_PARTY.md')
  Write-Output "EXPORTED $($demoVersion.Id) stage=$demoStage"
}
