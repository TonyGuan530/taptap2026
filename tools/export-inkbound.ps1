param([string]$GodotPath='D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe')
$ErrorActionPreference='Stop'
$taskRepo=Split-Path $PSScriptRoot -Parent
$taskProject=Join-Path $taskRepo 'game/project.godot'
$taskPresets=Join-Path $taskRepo 'game/export_presets.cfg'
$taskProjectText=[IO.File]::ReadAllText($taskProject)
$taskPresetText=[IO.File]::ReadAllText($taskPresets)
$taskOut=Join-Path $taskRepo 'builds/demo-06-inkbound-v9'
$taskScratch=Join-Path $taskRepo '.codex-tmp/inkbound'
New-Item -ItemType Directory -Force -Path $taskOut,$taskScratch | Out-Null
function Invoke-InkGodot([string[]]$TaskArgs,[string]$TaskName) {
  $taskLog=Join-Path $taskScratch ($TaskName+'.out.log')
  $taskErr=Join-Path $taskScratch ($TaskName+'.err.log')
  $taskProcess=Start-Process -FilePath $GodotPath -ArgumentList $TaskArgs -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $taskLog -RedirectStandardError $taskErr
  if($taskProcess.ExitCode -ne 0 -or [IO.File]::ReadAllText($taskErr) -match '(?m)^(SCRIPT ERROR|ERROR):') { Get-Content -LiteralPath $taskErr -Tail 30; throw ($TaskName+' failed') }
  Write-Output ($TaskName+' exit=0')
}
try {
  Invoke-InkGodot @('--headless','--path',('"'+(Join-Path $taskRepo 'game')+'"'),'--editor','--import') 'import'
  Invoke-InkGodot @('--headless','--path',('"'+(Join-Path $taskRepo 'game')+'"'),'res://v9/ink_world.tscn','--quit-after','10') 'native-start'
  $taskNewProject=$taskProjectText -replace 'run/main_scene="[^"]+"','run/main_scene="res://v9/ink_world.tscn"'
  $taskNewProject=$taskNewProject -replace 'config/name="[^"]+"','config/name="Inkbound V9"'
  [IO.File]::WriteAllText($taskProject,$taskNewProject,[Text.UTF8Encoding]::new($false))
  $taskNewPreset=$taskPresetText -replace 'export_filter="[^"]*"','export_filter="selected_scenes"'
  $taskNewPreset=$taskNewPreset -replace 'export_scenes=PackedStringArray\([^)]*\)','export_scenes=PackedStringArray("res://v9/ink_world.tscn")'
  $taskNewPreset=$taskNewPreset -replace 'exclude_filter="[^"]*"','exclude_filter="addons/dialogue_manager/**/*.cs,addons/dialogue_manager/example_balloon/ExampleBalloon.tscn,addons/dialogue_manager/example_balloon/SmallExampleBalloon.tscn,addons/dialogue_manager/nodes/dialogue_label/DialogueLabel.tscn"'
  [IO.File]::WriteAllText($taskPresets,$taskNewPreset,[Text.UTF8Encoding]::new($false))
  Invoke-InkGodot @('--headless','--path',('"'+(Join-Path $taskRepo 'game')+'"'),'--export-release','Web',('"'+(Join-Path $taskOut 'index.html')+'"')) 'export'
  foreach($taskFile in @('index.html','index.js','index.wasm','index.pck')) { if(-not(Test-Path -LiteralPath (Join-Path $taskOut $taskFile))) { throw ('Missing '+$taskFile) } }
  $taskMeta=[ordered]@{title='墨迹漂流 / INKBOUND';version='demo-06-inkbound-v9';date=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('o');author='Codex';notes='纸雕庭院、原创画家、真实画线与闭合造物、词条多解、完整三段流程'}
  [IO.File]::WriteAllText((Join-Path $taskOut 'build.json'),(($taskMeta|ConvertTo-Json)+"`n"),[Text.UTF8Encoding]::new($false))
  Write-Output 'EXPORTED demo-06-inkbound-v9'
} finally {
  [IO.File]::WriteAllText($taskProject,$taskProjectText,[Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText($taskPresets,$taskPresetText,[Text.UTF8Encoding]::new($false))
}
