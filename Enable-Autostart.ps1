#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Student','Teacher')][string]$Mode = 'Student',
    [string]$AlertFolder = '',
    [string]$DiscordWebhook = '',
    [switch]$NoSpeech,
    [switch]$Preview
)
$ErrorActionPreference = 'Stop'
if ($Mode -eq 'Teacher' -and -not $AlertFolder) { throw 'Teacher mode needs -AlertFolder.' }
$launcher = Join-Path $PSScriptRoot 'Run-Background.ps1'
if (-not (Test-Path -LiteralPath $launcher)) { throw 'Keep all package files together in a permanent folder.' }
if ($AlertFolder -match '["\r\n]') { throw 'Invalid alert-folder path.' }
if ($DiscordWebhook -match '["\r\n]') { throw 'Invalid Discord webhook URL.' }
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$taskName = "SchoolInstallAlert-$Mode-$sid"
$arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Mode {1}' -f $launcher, $Mode
if ($AlertFolder) { $arguments += ' -AlertFolder "{0}"' -f $AlertFolder }
if ($DiscordWebhook) { $arguments += ' -DiscordWebhook "{0}"' -f $DiscordWebhook }
if ($NoSpeech) { $arguments += ' -NoSpeech' }
$exeXml = [Security.SecurityElement]::Escape((Join-Path $PSHOME 'powershell.exe'))
$argsXml = [Security.SecurityElement]::Escape($arguments)
$workXml = [Security.SecurityElement]::Escape($PSScriptRoot)
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>School Install Alert: background voice alerts while this user is signed in.</Description></RegistrationInfo>
  <Triggers><LogonTrigger><Enabled>true</Enabled><UserId>$sid</UserId></LogonTrigger></Triggers>
  <Principals><Principal id="Author"><UserId>$sid</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <AllowStartOnDemand>true</AllowStartOnDemand><Enabled>true</Enabled>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <RestartOnFailure><Interval>PT1M</Interval><Count>999</Count></RestartOnFailure>
  </Settings>
  <Actions Context="Author"><Exec><Command>$exeXml</Command><Arguments>$argsXml</Arguments><WorkingDirectory>$workXml</WorkingDirectory></Exec></Actions>
</Task>
"@
if ($Preview) { $taskXml; return }
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) { Stop-ScheduledTask -TaskName $taskName }
Register-ScheduledTask -TaskName $taskName -Xml $taskXml -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Write-Host "Automatic background startup enabled for the CURRENT Windows account. Task: $taskName" -ForegroundColor Green
Write-Host 'It starts now and at each login. No admin privileges were granted. View Task Scheduler and background logs to check status.'
