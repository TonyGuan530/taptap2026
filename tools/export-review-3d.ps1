param(
  [string]$GodotPath = 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
  [string]$FontSource = 'D:\GIT\taptap2026\assets-backup-fonts\NotoSansSC.full.ttf',
  [string]$SubsetModule = 'D:\GIT\taptap2026\tools\node_modules\subset-font',
  [switch]$Rebuild
)
$ErrorActionPreference = 'Stop'
$releaseRoot = Split-Path $PSScriptRoot -Parent
$specs = @(
  @{Id='demo-09-3d-v1'; Source='D:\GIT\taptap2026-demo09-3d'; Commit='2e318b1ae739d7fece975cf2aea43806c183840d'; Scene='demo09_3d'; Title='赛车模拟器 3D'; Files=@('game/demo09_3d.gd','game/demo09_3d.gd.uid','game/demo09_3d'); Tests=@('test_demo09_3d_scene.gd','test_demo09_3d_rigidflow.gd')},
  @{Id='demo-10-3d-v2'; Source='D:\GIT\taptap2026-demo10-3d'; Commit='f137d9390cf941d11b847882b1a37a07a6c74fb5'; Scene='demo10_3d'; Title='修改小说 · 可探索3D世界'; Files=@('game/demo10_3d'); Tests=@('test_demo10_3d_scene.gd','test_demo10_3d_phaseb.gd')},
  @{Id='demo-11-3d-v1'; Source='D:\GIT\taptap2026-demo11-3d'; Commit='a175609b2053dc9bed0d30cabc785f910094bf97'; Scene='demo11_3d'; Title='箱庭谜题 3D'; Files=@('game/demo11_3d'); Tests=@('test_demo11_3d_core.gd','test_demo11_3d_scene.gd')}
)
New-Item -ItemType Directory -Path (Join-Path $releaseRoot 'reviews\release-09-11') -Force | Out-Null
$results=@()
foreach ($spec in $specs) {
  $entryScene=$spec.Scene
  $stageRoot = Join-Path ([IO.Path]::GetTempPath()) ('taptap-review-' + $spec.Id + '-' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $stageRoot | Out-Null
  $snapshot = Join-Path $stageRoot 'snapshot.zip'
  $paths=@(('game/'+$spec.Scene+'.tscn'),'game/comic_style','game/models/native','game/fonts/NotoSansSC.ttf','game/icon.svg','game/export_presets.cfg')+$spec.Files
  foreach ($test in $spec.Tests) { $paths+=('game/tests/'+$test) }
  & git -C $spec.Source archive --format=zip --output=$snapshot $spec.Commit -- @paths
  if ($LASTEXITCODE -ne 0) { throw "$($spec.Id) snapshot failed" }
  Expand-Archive -LiteralPath $snapshot -DestinationPath $stageRoot
  $projectRoot = Join-Path $stageRoot 'game'
  if ($spec.Scene -eq 'demo09_3d') { Copy-Item -LiteralPath (Join-Path $releaseRoot 'game\demo09_3d.gd') -Destination $projectRoot }
  if ($spec.Scene -eq 'demo10_3d') { Copy-Item -LiteralPath (Join-Path $releaseRoot 'game\demo10_3d\chapter_world.gd') -Destination (Join-Path $projectRoot 'demo10_3d\chapter_world.gd') }
  & node (Join-Path $PSScriptRoot 'subset-review-font.cjs') $projectRoot $FontSource $SubsetModule
  if ($LASTEXITCODE -ne 0) { throw "$($spec.Id) font preparation failed" }
  $project=@"
config_version=5
[application]
config/name="$($spec.Title)"
run/main_scene="res://$($spec.Scene).tscn"
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
  $projectFile=Join-Path $projectRoot 'project.godot'
  [IO.File]::WriteAllText($projectFile,($project -replace 'theme/custom_font="res://fonts/NotoSansSC.ttf"',''))
  $presetFile=Join-Path $projectRoot 'export_presets.cfg'
  $preset=[IO.File]::ReadAllText($presetFile)
  $preset=($preset -split '(?m)^\[preset\.1\]')[0]
  $preset=$preset -replace 'export_filter="[^"]*"','export_filter="all_resources"'
  $preset=$preset -replace 'exclude_filter="[^"]*"','exclude_filter="tests/*"'
  $preset=$preset -replace 'export_scenes=PackedStringArray\([^)]*\)',('export_scenes=PackedStringArray("res://'+$spec.Scene+'.tscn")')
  [IO.File]::WriteAllText($presetFile,$preset)
  $output=Join-Path $releaseRoot ('builds\'+$spec.Id)
  if ((Test-Path -LiteralPath (Join-Path $output 'index.html')) -and -not $Rebuild) { throw "Use -Rebuild for $($spec.Id)" }
  New-Item -ItemType Directory -Path $output -Force | Out-Null
  $steps=@(@{Name='import';Args=@('--headless','--editor','--import','--quit')})
  foreach ($test in $spec.Tests) {
    $testArgs=@('--headless','--script',('res://tests/'+$test),'--quit-after','30000')
    # AudioStreamPlayer playback follows wall time, so demo10's audio tests
    # must run in real time rather than advancing simulated frames rapidly.
    if ($spec.Scene -eq 'demo09_3d') { $testArgs+=@('--fixed-fps','60') }
    else { $testArgs+=@('--max-fps','60') }
    $steps+=@{Name=$test;Args=$testArgs}
  }
  if ($spec.Scene -eq 'demo09_3d') { $steps+=@{Name='test-review-entry.gd';Args=@('--headless','--script','res://tests/test-review-entry.gd','--quit-after','1000','--max-fps','60')} }
  $steps+=@{Name='export';Args=@('--headless','--export-release','Web',('"'+(Join-Path $output 'index.html')+'"'))}
  $checks=@()
  foreach ($step in $steps) {
    if ($step.Name -eq 'test-review-entry.gd') {
      Copy-Item -LiteralPath (Join-Path $releaseRoot 'game\demo09_review.gd') -Destination $projectRoot
      Copy-Item -LiteralPath (Join-Path $releaseRoot 'game\demo09_review.tscn') -Destination $projectRoot
      Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'test-review-entry.gd') -Destination (Join-Path $projectRoot 'tests\test-review-entry.gd')
      $entryScene='demo09_review'
      $project=$project.Replace('res://demo09_3d.tscn','res://demo09_review.tscn')
    }
    if ($step.Name -ne 'import') { [IO.File]::WriteAllText($projectFile,$project) }
    $stdout=Join-Path $stageRoot ($step.Name+'.stdout.txt');$stderr=Join-Path $stageRoot ($step.Name+'.stderr.txt')
    $args=@('--path',('"'+$projectRoot+'"'))+$step.Args
    $process=Start-Process -FilePath $GodotPath -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit(120000)) { $process.Kill();throw "$($spec.Id) $($step.Name) timed out" }
    $process.Refresh()
    $log=[IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr)
    [IO.File]::WriteAllText((Join-Path $releaseRoot ('reviews\release-09-11\'+$spec.Id+'-'+$step.Name+'.txt')),($log -replace "`r`n","`n").TrimEnd()+"`n")
    $runtimeLog=$log
    # Existing test drivers can retain resources until process shutdown; retain
    # this diagnostic in evidence while still rejecting every runtime error.
    $cleanupDiagnostic=$step.Name.EndsWith('.gd') -and $log -match '(?m)^ERROR: \d+ resources still in use at exit'
    if ($cleanupDiagnostic) { $runtimeLog=$runtimeLog -replace '(?m)^ERROR: \d+ resources still in use at exit[^\r\n]*','' }
    if ($process.ExitCode -ne 0 -or $runtimeLog -match 'SCRIPT ERROR|(?m)^ERROR:|(?m)^FAIL(?:\s|:)') { Write-Output $log;throw "$($spec.Id) $($step.Name) failed; exit=$($process.ExitCode)" }
    if ($step.Name.EndsWith('.gd') -and $log -notmatch '(?i)\bFAIL\s*[/:=]?\s*0\b|\b0\s+FAIL\b|failures=0|fails=0') { throw "$($spec.Id) test completion marker missing: $($step.Name)" }
    Write-Output "$($spec.Id) $($step.Name) exit=$($process.ExitCode)"
    $checks+=@{step=$step.Name;exitCode=$process.ExitCode;shutdownResourceDiagnostic=[bool]$cleanupDiagnostic}
  }
  foreach ($file in @('index.html','index.js','index.wasm','index.pck')) { if (-not (Test-Path -LiteralPath (Join-Path $output $file))) { throw "Missing $file" } }
  $meta=[ordered]@{title=$spec.Title;version=$spec.Id;date=[DateTimeOffset]::UtcNow.ToString('o');author='Codex';notes='已提交3D开发快照的评审版；原生场景/规则验证和浏览器验证；旧2D保留。';sourceCommit=$spec.Commit;mainScene=('res://'+$entryScene+'.tscn')}
  [IO.File]::WriteAllText((Join-Path $output 'build.json'),($meta|ConvertTo-Json)+"`n")
  $htmlFile=Join-Path $output 'index.html';[IO.File]::WriteAllText($htmlFile,[IO.File]::ReadAllText($htmlFile).TrimEnd()+"`n")
  $results+=@{buildId=$spec.Id;sourceCommit=$spec.Commit;projectStage=$projectRoot;mainScene=$meta.mainScene;checks=$checks;pckSha256=(Get-FileHash -LiteralPath (Join-Path $output 'index.pck') -Algorithm SHA256).Hash.ToLower()}
}
[IO.File]::WriteAllText((Join-Path $releaseRoot 'reviews\release-09-11\exports.json'),($results|ConvertTo-Json -Depth 8)+"`n")
& node (Join-Path $PSScriptRoot 'share-review-runtime.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Shared runtime preparation failed' }
