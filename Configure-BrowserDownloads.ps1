#requires -Version 5.1
<# Optional machine-wide browser policy. Risky is NOT an all-EXE ban. #>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Risky','All')][string]$Restriction = 'Risky',
    [switch]$Restore
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$paths = @('HKLM:\SOFTWARE\Policies\Microsoft\Edge','HKLM:\SOFTWARE\Policies\Google\Chrome')
$policyName = 'DownloadRestrictions'
$value = 2
if ($Restriction -eq 'All') { $value = 3 }
$action = 'Set Edge and Chrome DownloadRestrictions to ' + $value
if ($Restore) { $action = 'Restore the previously saved Edge and Chrome download policy values' }
if (-not $PSCmdlet.ShouldProcess('This PC, all Windows users', $action)) { return }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Open Windows PowerShell as administrator for browser policy changes.' }
$backupFolder = Join-Path $env:ProgramData 'SchoolInstallAlert'
$backupFile = Join-Path $backupFolder 'BrowserPolicyBackup.json'
if ($Restore) {
    if (-not (Test-Path -LiteralPath $backupFile)) { throw 'No original browser policy backup exists on this PC.' }
    $backup = Get-Content -LiteralPath $backupFile -Raw | ConvertFrom-Json
    if ($backup.Computer -ne $env:COMPUTERNAME -or @($backup.Entries).Count -ne 2) { throw 'Invalid backup for this computer.' }
    # Do not overwrite a newer policy change made by school IT.
    foreach ($entry in $backup.Entries) {
        if ($entry.Path -notin $paths) { throw 'Unexpected registry path in backup.' }
        $currentExists = $false
        $current = $null
        if (Test-Path -LiteralPath $entry.Path) {
            $currentKey = Get-Item -LiteralPath $entry.Path
            if ($currentKey.GetValueNames() -contains $policyName) {
                $currentExists = $true
                if ($currentKey.GetValueKind($policyName) -ne 'DWord') { throw 'The download policy data type has changed. Ask IT to reconcile it.' }
                $current = [int]$currentKey.GetValue($policyName)
            }
        }
        $isApplied = $currentExists -and $current -eq $backup.AppliedValue
        $isOriginal = ($entry.Existed -and $currentExists -and $current -eq $entry.Value) -or (-not $entry.Existed -and -not $currentExists)
        if (-not $isApplied -and -not $isOriginal) { throw 'A download policy has changed since this script ran. Ask IT to reconcile it before restoring.' }
    }
    foreach ($entry in $backup.Entries) {
        if ($entry.Existed) {
            New-ItemProperty -LiteralPath $entry.Path -Name $policyName -PropertyType DWord -Value ([int]$entry.Value) -Force | Out-Null
        } elseif (Test-Path -LiteralPath $entry.Path) { Remove-ItemProperty -LiteralPath $entry.Path -Name $policyName -ErrorAction SilentlyContinue }
    }
    Remove-Item -LiteralPath $backupFile
    Write-Host 'Original browser policy values restored. Restart both browsers and check their policy pages.'
    return
}
if (Test-Path -LiteralPath $backupFile) { throw 'A saved policy backup already exists. Restore the previous change before applying a different restriction.' }
$entries = foreach ($path in $paths) {
    $oldValue = $null
    $existed = $false
    if (Test-Path -LiteralPath $path) {
        $key = Get-Item -LiteralPath $path
        if ($key.GetValueNames() -contains $policyName) {
            if ($key.GetValueKind($policyName) -ne 'DWord') { throw 'Existing download policy has an unexpected data type. Ask IT to review it.' }
            $oldValue = [int]$key.GetValue($policyName)
            $existed = $true
            if ($oldValue -eq 3 -and $value -ne 3) { throw 'All downloads are already blocked. This script will not weaken that rule.' }
        }
    }
    [pscustomobject]@{Path=$path; Existed=$existed; Value=$oldValue}
}
[void][IO.Directory]::CreateDirectory($backupFolder)
[pscustomobject]@{Computer=$env:COMPUTERNAME; AppliedValue=$value; Entries=@($entries)} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $backupFile -Encoding UTF8
foreach ($path in $paths) {
    if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
    New-ItemProperty -LiteralPath $path -Name $policyName -PropertyType DWord -Value $value -Force | Out-Null
}
Write-Host 'Policy saved. Restart Edge and Chrome; check DownloadRestrictions in edge://policy and chrome://policy.'
if ($value -eq 2) { Write-Warning 'This blocks downloads classified as risky. It does NOT ban every EXE file.' }
else { Write-Warning 'All normal browser downloads are blocked, including school documents. This is not an EXE-only rule.' }
Write-Warning 'Users with administrator rights can reverse local policies. Other programs can still download files.'
