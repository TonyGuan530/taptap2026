param(
  [string]$GodotPath = 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
  [switch]$Rebuild
)
$ErrorActionPreference = 'Stop'
$demoRoot = Split-Path $PSScriptRoot -Parent
$demoVersions = @(
  @{ Id='demo-02-v8'; Scene='demo02_physics'; Title='物性变换谜题 2D'; Notes='L3 横漂距离缩短约 13%，落点加宽；1/2/3 快捷切词条，保留组合解法。' },
  @{ Id='demo-02-3d-v16'; Scene='demo02_3d'; Title='物性变换谜题 3D（第三人称）'; Notes='默认第三人称、可见球体及相机避障；L1 朝向目标，首次操作后起步、接收区加宽；通关提示与下一关按钮/N。V 可切第一人称。' }
)
foreach ($demoVersion in $demoVersions) {
  $demoStage = Join-Path ([System.IO.Path]::GetTempPath()) ('taptap-demo02-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path (Join-Path $demoStage 'fonts') -Force | Out-Null
  foreach ($demoSuffix in @('gd','tscn')) {
    Copy-Item -LiteralPath (Join-Path $demoRoot "game\$($demoVersion.Scene).$demoSuffix") -Destination $demoStage
  }
  Copy-Item -LiteralPath (Join-Path $demoRoot 'game\fonts\NotoSansSC.ttf') -Destination (Join-Path $demoStage 'fonts')
  Copy-Item -LiteralPath (Join-Path $demoRoot 'game\icon.svg') -Destination $demoStage
  if ($demoVersion.Scene -eq 'demo02_3d') {
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
  [System.IO.File]::WriteAllText((Join-Path $demoOutput 'build.json'), ($demoMeta | ConvertTo-Json) + "`n")
  Write-Output "EXPORTED $($demoVersion.Id) stage=$demoStage"
}
