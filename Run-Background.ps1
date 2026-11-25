#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Student','Teacher')][string]$Mode = 'Student',
    [string]$AlertFolder = '',
    [string]$DiscordWebhook = '',
    [string]$DataFolder = (Join-Path $env:LOCALAPPDATA 'SchoolInstallAlert'),
    [switch]$NoSpeech,
    [ValidateRange(0,86400)][int]$RunSeconds = 0
)
$ErrorActionPreference = 'Stop'
[void][IO.Directory]::CreateDirectory($DataFolder)
$transcriptActive = $false
$resultCode = 0
try {
    Start-Transcript -LiteralPath (Join-Path $DataFolder ("Background-{0}-{1}.log" -f $Mode, (Get-Date -Format yyyy-MM-dd))) -Append | Out-Null
    $transcriptActive = $true
    & (Join-Path $PSScriptRoot 'InstallAlert.ps1') -Mode $Mode -AlertFolder $AlertFolder -DiscordWebhook $DiscordWebhook -DataFolder $DataFolder -NoSpeech:$NoSpeech -RunSeconds $RunSeconds
} catch {
    Write-Output $_.Exception.ToString()
    $resultCode = 1
} finally {
    if ($transcriptActive) { Stop-Transcript | Out-Null }
}
exit $resultCode
