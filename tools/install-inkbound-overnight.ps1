param([switch]$Remove)
$ErrorActionPreference='Stop'
$taskRepo=Split-Path $PSScriptRoot -Parent
$taskNames=@('Inkbound-V10-Continue','Inkbound-V10-Release')
if($Remove){foreach($taskName in $taskNames){Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue};return}
$taskRunner=Join-Path $taskRepo 'tools/run-inkbound-overnight.ps1'
$taskOwner=[Security.Principal.WindowsIdentity]::GetCurrent().Name
$taskPrincipal=New-ScheduledTaskPrincipal -UserId $taskOwner -LogonType Interactive -RunLevel Limited
$taskSettings=New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
foreach($taskMode in @('continue','release')){
  $taskInterval=if($taskMode -eq 'continue'){[TimeSpan]::FromMinutes(20)}else{[TimeSpan]::FromHours(1)}
  $taskStart=if($taskMode -eq 'continue'){(Get-Date).AddMinutes(2)}else{(Get-Date).Date.AddHours((Get-Date).Hour+1).AddMinutes(5)}
  $taskAction=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -File "'+$taskRunner+'" -Mode '+$taskMode) -WorkingDirectory $taskRepo
  $taskTrigger=New-ScheduledTaskTrigger -Once -At $taskStart -RepetitionInterval $taskInterval
  $taskName=if($taskMode -eq 'continue'){$taskNames[0]}else{$taskNames[1]}
  Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Principal $taskPrincipal -Description 'User authorized Inkbound V10 overnight work. Headless only; shared worker lock; stops at COMPLETE or STOP; evidence required before Pages publication.' -Force | Out-Null
}
Get-ScheduledTask -TaskName $taskNames | Select-Object TaskName,State,@{Name='Interval';Expression={$_.Triggers.Repetition.Interval}}
