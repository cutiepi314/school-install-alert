#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Student','Teacher')][string]$Mode = 'Student')
$ErrorActionPreference = 'Stop'
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$taskName = "SchoolInstallAlert-$Mode-$sid"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    Stop-ScheduledTask -TaskName $taskName
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host 'Stopped the scheduled monitor and removed its automatic startup.'
} else { Write-Host 'No automatic startup task exists for this account and mode.' }
