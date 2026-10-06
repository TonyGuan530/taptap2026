param([string]$GodotPath='D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',[string]$BuildId='demo-06-inkbound-v10')
# Keep this source UTF-8 with BOM for Windows PowerShell 5.1; generated JSON stays UTF-8 without BOM.
$ErrorActionPreference='Stop'
if($BuildId -notin @('demo-06-inkbound-v10','demo-06-inkbound-v10-touch')){throw 'Unsupported Inkbound build ID'}
$taskRepo=Split-Path $PSScriptRoot -Parent
$taskProject=Join-Path $taskRepo 'game/project.godot'
$taskPresets=Join-Path $taskRepo 'game/export_presets.cfg'
$taskProjectText=[IO.File]::ReadAllText($taskProject)
$taskPresetText=[IO.File]::ReadAllText($taskPresets)
$taskOut=Join-Path $taskRepo ('builds/'+$BuildId)
$taskScratch=Join-Path $taskRepo ('.codex-tmp/'+($BuildId -replace '^demo-06-',''))
New-Item -ItemType Directory -Force -Path $taskOut,$taskScratch | Out-Null
function Invoke-InkGodot([string[]]$TaskArgs,[string]$TaskName) {
  if($TaskArgs[0] -ne '--headless'){throw 'Headless Godot required'}
  $taskLog=Join-Path $taskScratch ($TaskName+'.out.log')
  $taskErr=Join-Path $taskScratch ($TaskName+'.err.log')
  $taskProcess=Start-Process -FilePath $GodotPath -ArgumentList $TaskArgs -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $taskLog -RedirectStandardError $taskErr
  $taskErrors=[IO.File]::ReadAllText($taskErr)
  $taskOutput=[IO.File]::ReadAllText($taskLog)
  if($taskProcess.ExitCode -ne 0 -or ($taskErrors+"`n"+$taskOutput) -match '(?m)^(SCRIPT ERROR|ERROR):') { Get-Content -LiteralPath $taskErr -Tail 30; throw ($TaskName+' failed') }
  Write-Output ($TaskName+' exit=0')
}
try {
  Invoke-InkGodot @('--headless','--path',('"'+(Join-Path $taskRepo 'game')+'"'),'--editor','--import') 'import'
  Invoke-InkGodot @('--headless','--path',('"'+(Join-Path $taskRepo 'game')+'"'),'res://v10/ink_world.tscn','--quit-after','10') 'native-start'
  $taskNewProject=$taskProjectText -replace 'run/main_scene="[^"]+"','run/main_scene="res://v10/ink_world.tscn"'
  $taskNewProject=$taskNewProject -replace 'config/name="[^"]+"','config/name="Inkbound V10"'
  [IO.File]::WriteAllText($taskProject,$taskNewProject,[Text.UTF8Encoding]::new($false))
  $taskNewPreset=$taskPresetText -replace 'export_filter="[^"]*"','export_filter="selected_scenes"'
  $taskNewPreset=$taskNewPreset -replace 'export_scenes=PackedStringArray\([^)]*\)','export_scenes=PackedStringArray("res://v10/ink_world.tscn")'
  $taskNewPreset=$taskNewPreset -replace 'exclude_filter="[^"]*"','exclude_filter="addons/dialogue_manager/**/*.cs,addons/dialogue_manager/example_balloon/ExampleBalloon.tscn,addons/dialogue_manager/example_balloon/SmallExampleBalloon.tscn,addons/dialogue_manager/nodes/dialogue_label/DialogueLabel.tscn"'
  [IO.File]::WriteAllText($taskPresets,$taskNewPreset,[Text.UTF8Encoding]::new($false))
  Invoke-InkGodot @('--headless','--path',('"'+(Join-Path $taskRepo 'game')+'"'),'--export-release','Web',('"'+(Join-Path $taskOut 'index.html')+'"')) 'export'
  $taskHtmlFile=Join-Path $taskOut 'index.html'
  [IO.File]::WriteAllText($taskHtmlFile,([IO.File]::ReadAllText($taskHtmlFile).TrimEnd()+"`n"),[Text.UTF8Encoding]::new($false))
  foreach($taskFile in @('index.html','index.js','index.wasm','index.pck')) {
    $taskArtifact=Join-Path $taskOut $taskFile
    if(-not(Test-Path -LiteralPath $taskArtifact) -or (Get-Item -LiteralPath $taskArtifact).Length -eq 0){throw ('Missing or empty '+$taskFile)}
  }
  $taskSourceCommit=git -C $taskRepo rev-parse HEAD
  $taskPckHash=(Get-FileHash -LiteralPath (Join-Path $taskOut 'index.pck') -Algorithm SHA256).Hash.ToLowerInvariant()
  $taskMeta=[ordered]@{title='墨迹漂流 / INKBOUND';version=$BuildId;date=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('o');sourceCommit=$taskSourceCommit;pckSha256=$taskPckHash;author='Codex';notes='黑墨多笔梯架与板面、真实尺寸攀爬与三段立体纸页；黄墨原笔迹挥砍、锋利切藤或黑墨搭梯绕行，抵达末页结局'}
  if($BuildId -eq 'demo-06-inkbound-v10-touch'){$taskMeta.notes+='；横屏多指触控摇杆、跳跃攀爬挥砍回收、手指绘画与点选搭建'}
  [IO.File]::WriteAllText((Join-Path $taskOut 'build.json'),(($taskMeta|ConvertTo-Json)+"`n"),[Text.UTF8Encoding]::new($false))
  Write-Output ('EXPORTED '+$BuildId)
} finally {
  [IO.File]::WriteAllText($taskProject,$taskProjectText,[Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText($taskPresets,$taskPresetText,[Text.UTF8Encoding]::new($false))
}
