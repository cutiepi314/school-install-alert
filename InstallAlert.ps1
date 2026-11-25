#requires -Version 5.1
<#
Windows PowerShell 5.1. Student: watch local installer activity and speak.
Teacher: read optional alerts from an authenticated school SMB share and speak.
No software is installed, blocked, or removed by this script.
#>
[CmdletBinding()]
param(
    [ValidateSet('Student', 'Teacher')][string]$Mode = 'Student',
    [string]$AlertFolder = '',
    [string]$DiscordWebhook = '',
    [string]$DataFolder = (Join-Path $env:LOCALAPPDATA 'SchoolInstallAlert'),
    [switch]$NoSpeech,
    [switch]$TestAlert,
    [ValidateRange(0, 86400)][int]$RunSeconds = 0
)

# --- Easy Configuration ---
# Paste your Discord webhook URL between the quotes below so Enable-Autostart.cmd
# and Test-Voice.cmd send alerts automatically without extra parameters.
$DefaultDiscordWebhook = 'https://discord.com/api/webhooks/1575080596252794960/PkLza9GK_Xt0zmTumPcFTCPL84lULMEzeok1OwNSEsXarfeI67MWD7KlWpFfAkbFLe-p'
# Set to $true if you want student PCs to stay silent and only send alerts to Discord.
$DefaultNoSpeech = $false

# Customize what the voice and Discord notifications say.
# Placeholders: {computer}, {kind}, {detail}, {time}
$SpeechMessages = @{
    Installed         = 'Software installation completed on {computer}. {detail}'
    Test              = 'Test alert from {computer}. Installation monitoring is working.'
    Possible          = 'Possible software installation on {computer}. Please check this computer.'
    InstallerActivity = 'Possible software installation on {computer}. Please check this computer.'
    StudentStart      = 'Installation monitoring started.'
    TeacherStart      = 'Teacher installation alerts started.'
}
$DiscordMessages = @{
    Installed         = '[{time}] **{computer}** | Installed: {detail}'
    Test              = '[{time}] **{computer}** | Test alert: {detail}'
    Possible          = '[{time}] **{computer}** | Possible install: {detail}'
    InstallerActivity = '[{time}] **{computer}** | Installer activity: {detail}'
}
# --- End Configuration ---

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    throw 'Use Windows PowerShell 5.1 (powershell.exe), not PowerShell 7.'
}
if (-not $DiscordWebhook -and $DefaultDiscordWebhook) {
    $DiscordWebhook = $DefaultDiscordWebhook
}
$DiscordWebhook = $DiscordWebhook.Trim()
if ($DiscordWebhook -and $DiscordWebhook -notmatch '^https://((canary|ptb)\.)?discord(app)?\.com/api/webhooks/\d+/[A-Za-z0-9._-]+$') {
    throw 'Invalid -DiscordWebhook URL. Expected https://discord.com/api/webhooks/...'
}
$speechDisabled = $NoSpeech.IsPresent -or $DefaultNoSpeech
if ($Mode -eq 'Teacher' -and -not $AlertFolder) {
    throw 'Teacher mode requires -AlertFolder, for example C:\InstallAlerts.'
}
[void][IO.Directory]::CreateDirectory($DataFolder)
$outbox = Join-Path $DataFolder 'Outbox'
$discordOutbox = Join-Path $DataFolder 'DiscordOutbox'
$processed = Join-Path $DataFolder 'Processed'
[void][IO.Directory]::CreateDirectory($outbox)
[void][IO.Directory]::CreateDirectory($discordOutbox)
[void][IO.Directory]::CreateDirectory($processed)
$script:synth = $null
$watcher = $null
$sourceProcess = 'SchoolInstallAlert.Process.' + [guid]::NewGuid().ToString('N')
$sourceMsi = 'SchoolInstallAlert.Msi.' + [guid]::NewGuid().ToString('N')
$lastAlert = @{}
$lastSpeech = [datetime]::MinValue
$lastNetworkWarning = [datetime]::MinValue
$lastDiscordWarning = [datetime]::MinValue
$started = Get-Date
$instanceMutex = $null
$ownsMutex = $false

function Clean-Text([string]$Value, [int]$Length = 160) {
    $valueClean = ($Value -replace '[\x00-\x1f\x7f]', ' ').Trim()
    if ($valueClean.Length -gt $Length) { return $valueClean.Substring(0, $Length) }
    return $valueClean
}

function Format-AlertMessage([hashtable]$Templates, [string]$Kind, [string]$Computer, [string]$Detail, [string]$TimeLocal) {
    $template = if ($Templates.ContainsKey($Kind)) { $Templates[$Kind] } else { $Templates['Possible'] }
    return $template.Replace('{computer}', $Computer).Replace('{kind}', $Kind).Replace('{detail}', $Detail).Replace('{time}', $TimeLocal)
}

function Say([string]$Text) {
    if ($script:synth) {
        try {
            # Discard an old spoken alert so a busy class does not build a long queue.
            $script:synth.SpeakAsyncCancelAll()
            [void]$script:synth.SpeakAsync($Text)
        } catch { Write-Warning ('Speech failed: ' + $_.Exception.Message) }
    }
}

function Show-Alert($Alert) {
    $computer = Clean-Text ([string]$Alert.Computer) 64
    $detail = Clean-Text ([string]$Alert.Detail)
    $kind = [string]$Alert.Kind
    $timeLocal = Get-Date -Format 'HH:mm:ss'
    Write-Host ('[{0}] {1} | {2} | {3}' -f $timeLocal, $computer, $kind, $detail) -ForegroundColor Yellow
    $dailyLog = Join-Path $DataFolder ('Alerts-{0}.jsonl' -f (Get-Date -Format yyyy-MM-dd))
    $Alert | ConvertTo-Json -Compress | Add-Content -LiteralPath $dailyLog -Encoding UTF8
    # Every alert is logged; speech is limited to one alert per five seconds.
    if (((Get-Date) - $script:lastSpeech).TotalSeconds -ge 5) {
        $script:lastSpeech = Get-Date
        Say (Format-AlertMessage $SpeechMessages $kind $computer $detail $timeLocal)
    }
}

function Publish-Alert([string]$Kind, [string]$Detail, [string]$Key) {
    $now = Get-Date
    if ($lastAlert.ContainsKey($Key) -and ($now - $lastAlert[$Key]).TotalSeconds -lt 30) { return }
    $lastAlert[$Key] = $now
    # Keep the deduplication table bounded during long-running sessions.
    foreach ($oldKey in @($lastAlert.Keys)) {
        if (($now - $lastAlert[$oldKey]).TotalMinutes -gt 10) { $lastAlert.Remove($oldKey) }
    }
    $alert = [pscustomobject]@{
        Version = 1
        Id = [guid]::NewGuid().ToString('N')
        TimeUtc = $now.ToUniversalTime().ToString('o')
        Computer = $env:COMPUTERNAME
        Kind = $Kind
        Detail = (Clean-Text $Detail)
    }
    Show-Alert $alert
    if ($AlertFolder) {
        $alert | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $outbox ($alert.Id + '.json')) -Encoding UTF8
    }
    if ($DiscordWebhook) {
        $alert | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $discordOutbox ($alert.Id + '.json')) -Encoding UTF8
    }
}

function Flush-Outbox {
    if (-not $AlertFolder) { return }
    # Bounded batches avoid starving the detection loop after a long outage.
    foreach ($file in @(Get-ChildItem -LiteralPath $outbox -Filter '*.json' -File | Select-Object -First 20)) {
        try {
            $target = Join-Path $AlertFolder $file.Name
            # Publish atomically: receiver ignores incomplete .tmp files.
            $temporary = $target + '.tmp'
            Copy-Item -LiteralPath $file.FullName -Destination $temporary -Force
            Move-Item -LiteralPath $temporary -Destination $target -Force
            Remove-Item -LiteralPath $file.FullName
        } catch {
            if (((Get-Date) - $script:lastNetworkWarning).TotalMinutes -ge 1) {
                Write-Warning ('Teacher delivery failed. Alerts stay in the local Outbox for retry. ' + $_.Exception.Message)
                $script:lastNetworkWarning = Get-Date
            }
            break
        }
    }
}

function Flush-DiscordOutbox {
    if (-not $DiscordWebhook) { return }
    $files = @(Get-ChildItem -LiteralPath $discordOutbox -Filter '*.json' -File | Sort-Object CreationTimeUtc | Select-Object -First 10)
    if ($files.Count -eq 0) { return }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {}
    foreach ($file in $files) {
        try {
            $alert = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $computer = Clean-Text ([string]$alert.Computer) 64
            $detail = Clean-Text ([string]$alert.Detail) 160
            $kind = [string]$alert.Kind
            $timeLocal = try { [datetimeoffset]::Parse([string]$alert.TimeUtc).ToLocalTime().ToString('HH:mm:ss') } catch { Get-Date -Format 'HH:mm:ss' }
            $content = Format-AlertMessage $DiscordMessages $kind $computer $detail $timeLocal
            if ($content.Length -gt 1900) { $content = $content.Substring(0, 1900) }
            $payload = @{
                content          = $content
                username         = 'School Install Alert'
                allowed_mentions = @{ parse = @() }
            } | ConvertTo-Json -Compress -Depth 4
            $bodyBytes = [Text.Encoding]::UTF8.GetBytes($payload)
            [void](Invoke-RestMethod -Uri $DiscordWebhook -Method Post -Body $bodyBytes -ContentType 'application/json; charset=utf-8' -TimeoutSec 10)
            Remove-Item -LiteralPath $file.FullName
            Start-Sleep -Milliseconds 300
        } catch {
            if (((Get-Date) - $script:lastDiscordWarning).TotalMinutes -ge 1) {
                Write-Warning ('Discord delivery failed. Alerts stay in DiscordOutbox for retry. ' + $_.Exception.Message)
                $script:lastDiscordWarning = Get-Date
            }
            break
        }
    }
}

function Read-TeacherAlerts {
    try { $files = @(Get-ChildItem -LiteralPath $AlertFolder -Filter '*.json' -File) }
    catch {
        if (((Get-Date) - $script:lastNetworkWarning).TotalMinutes -ge 1) {
            Write-Warning ('Cannot read teacher alert folder: ' + $_.Exception.Message)
            $script:lastNetworkWarning = Get-Date
        }
        return
    }
    foreach ($file in $files) {
        # Only the script's GUID filenames are accepted. Never execute incoming data.
        if ($file.BaseName -notmatch '^[a-fA-F0-9]{32}$' -or $file.Length -gt 16384) { continue }
        $receipt = Join-Path $processed $file.Name
        if (Test-Path -LiteralPath $receipt) { continue }
        try {
            $alert = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($alert.Version -ne 1 -or $alert.Id -ne $file.BaseName -or
                $alert.Kind -notin @('Possible', 'InstallerActivity', 'Installed', 'Test')) {
                throw 'Unrecognized alert format.'
            }
            [void][datetimeoffset]::Parse([string]$alert.TimeUtc)
            # Check field presence and normalize before logging and speaking.
            $alert.Computer = Clean-Text ([string]$alert.Computer) 64
            $alert.Detail = Clean-Text ([string]$alert.Detail)
            Show-Alert $alert
            # Local receipts survive restarts. The shared alert stays available for review.
            Set-Content -LiteralPath $receipt -Value 'received' -Encoding ASCII
        } catch { Write-Warning ('Cannot process ' + $file.Name + ': ' + $_.Exception.Message) }
    }
}

try {
    if (-not $TestAlert) {
        $instanceMutex = New-Object Threading.Mutex($false, ("Local\SchoolInstallAlert-$Mode"))
        try { $ownsMutex = $instanceMutex.WaitOne(0) }
        catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
        if (-not $ownsMutex) { Write-Host 'Already running in this Windows session.'; return }
    }
    if (-not $speechDisabled) {
        try {
            Add-Type -AssemblyName System.Speech
            $script:synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
            $script:synth.SetOutputToDefaultAudioDevice()
            $script:synth.Volume = 100
        } catch { Write-Warning ('Speech unavailable; console and file alerts remain active. ' + $_.Exception.Message) }
    }
    Write-Host "School Install Alert | $Mode mode | Ctrl+C to stop" -ForegroundColor Cyan
    Write-Host "Local logs: $DataFolder"
    if ($AlertFolder) { Write-Host "Teacher alert folder: $AlertFolder" }
    if ($DiscordWebhook) { Write-Host 'Discord webhook: configured' }

    if ($TestAlert) {
        if ($Mode -ne 'Student') { throw 'Use -TestAlert with Student mode.' }
        Publish-Alert 'Test' 'Simulated alert; no software was installed.' 'Test'
        Flush-Outbox
        Flush-DiscordOutbox
        if ($script:synth) {
            while ($script:synth.State -ne 'Ready') { Start-Sleep -Milliseconds 100 }
        }
        return
    }

    if ($Mode -eq 'Student') {
        $processActive = $false
        $pollingActive = $false
        $seenProcesses = @{}
        $msiActive = $false
        try {
            # These names are heuristics, not proof of an installation.
            $query = "SELECT * FROM Win32_ProcessStartTrace WHERE ProcessName LIKE '%setup%' OR ProcessName LIKE '%install%' OR ProcessName = 'msiexec.exe' OR ProcessName = 'winget.exe' OR ProcessName = 'choco.exe'"
            Register-WmiEvent -Namespace root\cimv2 -Query $query -SourceIdentifier $sourceProcess | Out-Null
            $processActive = $true
        } catch { Write-Warning ('Process monitoring unavailable. Try Run as administrator. ' + $_.Exception.Message) }
        try {
            $eventQuery = New-Object System.Diagnostics.Eventing.Reader.EventLogQuery -ArgumentList 'Application', ([System.Diagnostics.Eventing.Reader.PathType]::LogName), "*[System[Provider[@Name='MsiInstaller'] and (EventID=1040 or EventID=11707)]]"
            $watcher = New-Object System.Diagnostics.Eventing.Reader.EventLogWatcher -ArgumentList $eventQuery
            Register-ObjectEvent -InputObject $watcher -EventName EventRecordWritten -SourceIdentifier $sourceMsi | Out-Null
            # Starts at the current end of the log, without replaying old installs.
            $watcher.Enabled = $true
            $msiActive = $true
        } catch { Write-Warning ('MSI event monitoring unavailable: ' + $_.Exception.Message) }
        if (-not $processActive) {
            # Standard accounts may lack WMI rights. Poll names as a best-effort fallback.
            foreach ($process in @(Get-Process -ErrorAction Stop)) { $seenProcesses[$process.Id] = $process.ProcessName }
            $pollingActive = $true
            Write-Warning 'Using process-name polling. Processes lasting less than one second may be missed.'
        }
        Write-Host "Monitoring active: process events=$processActive; process polling=$pollingActive; MSI events=$msiActive"
        Say $SpeechMessages['StudentStart']
    } else {
        if (-not (Test-Path -LiteralPath $AlertFolder -PathType Container)) { throw 'The teacher alert folder does not exist or is not accessible.' }
        Say $SpeechMessages['TeacherStart']
    }

    $nextFlush = [datetime]::MinValue
    $nextPoll = [datetime]::MinValue
    while ($RunSeconds -eq 0 -or ((Get-Date) - $started).TotalSeconds -lt $RunSeconds) {
        if ($Mode -eq 'Teacher') { Read-TeacherAlerts }
        else {
            if ($pollingActive -and (Get-Date) -ge $nextPoll) {
                $currentProcesses = @{}
                foreach ($process in @(Get-Process -ErrorAction Stop)) {
                    $currentProcesses[$process.Id] = $process.ProcessName
                    if ((-not $seenProcesses.ContainsKey($process.Id) -or $seenProcesses[$process.Id] -ne $process.ProcessName) -and
                        $process.ProcessName -match '(?i)setup|install|^(msiexec|winget|choco)$') {
                        Publish-Alert 'Possible' ("Installer-like process detected: $($process.ProcessName). This can also be an update, repair, or removal.") ("Process:$($process.ProcessName)")
                    }
                }
                $seenProcesses = $currentProcesses
                $nextPoll = (Get-Date).AddSeconds(1)
            }
            foreach ($eventItem in @(Get-Event -SourceIdentifier $sourceProcess -ErrorAction SilentlyContinue)) {
                try {
                    $name = [string]$eventItem.SourceEventArgs.NewEvent.ProcessName
                    Publish-Alert 'Possible' ("Installer-like process launched: $name. This can also be an update, repair, or removal.") ("Process:$name")
                } finally { Remove-Event -EventIdentifier $eventItem.EventIdentifier -ErrorAction SilentlyContinue }
            }
            foreach ($eventItem in @(Get-Event -SourceIdentifier $sourceMsi -ErrorAction SilentlyContinue)) {
                $record = $null
                try {
                    $argsMsi = $eventItem.SourceEventArgs
                    if ($argsMsi.EventException) { throw $argsMsi.EventException }
                    $record = $argsMsi.EventRecord
                    if ($null -ne $record) {
                        $detail = 'Windows Installer activity'
                        if ($record.Properties.Count -gt 0) { $detail = [string]$record.Properties[0].Value }
                        if ($record.Id -eq 11707) {
                            Publish-Alert 'Installed' $detail ("Installed:$detail")
                        } else {
                            # 1040 is a transaction; it may be install, repair, update or removal.
                            $detail = [IO.Path]::GetFileName($detail)
                            Publish-Alert 'InstallerActivity' ("Windows Installer transaction: $detail") ("Transaction:$detail")
                        }
                    }
                } catch { Write-Warning ('MSI event could not be processed: ' + $_.Exception.Message) }
                finally {
                    if ($record) { $record.Dispose() }
                    Remove-Event -EventIdentifier $eventItem.EventIdentifier -ErrorAction SilentlyContinue
                }
            }
            if ((Get-Date) -ge $nextFlush) {
                Flush-Outbox
                Flush-DiscordOutbox
                $nextFlush = (Get-Date).AddSeconds(5)
            }
        }
        Start-Sleep -Milliseconds 500
    }
} finally {
    if ($watcher) { $watcher.Enabled = $false; $watcher.Dispose() }
    foreach ($source in @($sourceProcess, $sourceMsi)) {
        Unregister-Event -SourceIdentifier $source -ErrorAction SilentlyContinue
        Get-Event -SourceIdentifier $source -ErrorAction SilentlyContinue | Remove-Event -ErrorAction SilentlyContinue
    }
    if ($script:synth) { $script:synth.SpeakAsyncCancelAll(); $script:synth.Dispose() }
    if ($ownsMutex) { $instanceMutex.ReleaseMutex() }
    if ($instanceMutex) { $instanceMutex.Dispose() }
}
