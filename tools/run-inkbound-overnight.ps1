param([ValidateSet('continue','release','smoke','check')][string]$Mode='continue')
$ErrorActionPreference='Stop'
$taskRepo=Split-Path $PSScriptRoot -Parent
$taskScratch=Join-Path $taskRepo '.codex-tmp/inkbound-v10/overnight'
$taskNode=(Get-Command node).Source
$taskStamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$taskProcess=Start-Process -FilePath $taskNode -ArgumentList @(('"'+(Join-Path $PSScriptRoot 'overnight-inkbound.mjs')+'"'),$Mode) -WorkingDirectory $taskRepo -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $taskScratch ($taskStamp+'-'+$Mode+'.launcher.log')) -RedirectStandardError (Join-Path $taskScratch ($taskStamp+'-'+$Mode+'.launcher.err.log'))
exit $taskProcess.ExitCode
