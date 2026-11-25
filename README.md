# School Install Alert - Windows 10 / 11

Speaks on each student PC when a likely installer starts. Optionally sends a small
alert file over your school LAN so your teacher PC can display and speak it too.
No online service, email account or internet connection is needed.

## Automatic background startup (new)

1. Extract all files together to a permanent folder, such as `C:\SchoolInstallAlert`.
2. Sign in using the Windows account that students actually use.
3. Double-click **Enable-Autostart.cmd** once. Do not use another administrator
   account for this step. It registers a clearly named Task Scheduler task for
   the current account and starts it immediately, without an open console.
4. Use **Test-Voice.cmd** to check the current audio output.

It starts again at each login, including after a reboot followed by login.
It stops at sign-out/shutdown and does not monitor while Windows is off.
Run setup separately for each Windows account that needs it. Keep the package
in its permanent folder: moving or deleting it breaks the startup task.
The task has no runtime limit, avoids duplicate instances, and requests restart
after an error (one-minute delay). It runs with ordinary user permissions and
uses process-name polling if Windows denies access to process-start events.
Polling can miss processes lasting less than one second. It is not a service.

Double-click **Disable-Autostart.cmd** to stop the scheduled monitor and remove
its startup task for the current account. Existing manually launched monitors
must be stopped separately. View the task in **Task Scheduler**; the task name
starts with `SchoolInstallAlert-Student-`. Background logs are in
`%LOCALAPPDATA%\SchoolInstallAlert\Background-Student-yyyy-MM-dd.log`.
If school policy denies task registration, setup reports an error and IT must
deploy the task. Sound needs an interactive login and an audible output device.

For automatic student startup with delivery to your teacher PC:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\SchoolInstallAlert\Enable-Autostart.ps1" -AlertFolder "\\TEACHER-PC\InstallAlerts"
```

For automatic startup of the receiver on your teacher account:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\SchoolInstallAlert\Enable-Autostart.ps1" -Mode Teacher -AlertFolder "C:\InstallAlerts"
```

To stop/remove the teacher task, run `Disable-Autostart.ps1 -Mode Teacher`.
Automatic startup does not make the monitor tamper-resistant: administrators
and users who can stop their processes can disable it.

## Cancel direct EXE downloads in Edge and Chrome

The **Block-EXE-Downloads** folder contains an optional local browser extension.
It cancels downloads with a final `.exe` filename (case-insensitive), including
files a browser considers safe. PDF, DOCX and Packet Tracer downloads are not
blocked by this extension. It has no server and sends nothing to your teacher PC.

Install it separately in EACH browser profile used by students:

1. Edge: open `edge://extensions`. Chrome: open `chrome://extensions`.
2. Enable **Developer mode**.
3. Click **Load unpacked** and select the **Block-EXE-Downloads** folder containing
   `manifest.json`. Keep this folder in its permanent location.
4. Confirm **School - block EXE downloads** is enabled.
5. Test a direct harmless EXE download and a PDF download. The EXE should be
   cancelled; the PDF should work. Test on the actual school browser versions.

It runs with the browser automatically after being loaded, independently of the
PowerShell startup task. For InPrivate/Incognito, explicitly allow the extension
in that mode or disallow that mode through school-managed browser settings.
It does not apply to guest or other profiles where the extension is not enabled.
To remove it, use **Remove** on that browser's extensions page.

**Limits:** this is a removable classroom helper, not an enforced security
boundary. Students with your current admin rights can disable/remove it or use
another profile/program. Renamed files, EXEs inside ZIP archives, MSI installers,
USB copies and existing files are not blocked. Network bytes or temporary files
can arrive before cancellation; this does not prevent every byte from reaching
the PC. Other download extensions or browser changes can affect it. No local
account rights are changed. For dependable enforcement, use managed standard
student accounts and an IT-managed application/download policy.

## Optional additional browser risk restrictions

This is separate from monitoring. No browser policy is changed by starting
the monitor or enabling automatic startup. Your students currently have admin
rights, so local restrictions are reversible by them. For enforceable classroom
rules, IT should give students standard accounts and manage application control
with appropriate exceptions for your lessons.

The included policy script can restrict downloads classified as dangerous,
uncommon or unwanted by Edge/Chrome. **This does not block every EXE file.**
It may also block legitimate files. Open Windows PowerShell **as administrator**:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\SchoolInstallAlert\Configure-BrowserDownloads.ps1"
```

It sets machine-wide `DownloadRestrictions=2` in Edge and Chrome, preserving
the original values for restoration. It does not disable browser protections,
alter student accounts, or change other browser policies. Restart both browsers
and check `DownloadRestrictions` on `edge://policy` and `chrome://policy`.
School/domain-managed policies may take precedence. Test with the student
browser profile; do not assume a registry write proves browser enforcement.

Restore the saved values with the same script and `-Restore`. It refuses to
overwrite a policy that IT has changed since the original application.
Use `-WhatIf` to preview without changing registry values.

An explicit `-Restriction All` option blocks all normal browser downloads,
including PDF/DOCX/Packet Tracer files. **Do not use that option if students need
to download teaching materials.** Saving the displayed webpage or printing to
PDF is not covered. The restriction does not control PowerShell, other browsers,
USB drives or existing files, and it does not block application execution.
Neither browser policy claims to provide a universal EXE-only download ban.
Microsoft's `DownloadBlockedForFileTypes` policy is currently unsupported on
Windows; do not copy its mobile-only configuration to these PCs.

## 1. Start on a student PC

Extract this ZIP to `C:\SchoolInstallAlert`. Open **Windows PowerShell** as
administrator and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\SchoolInstallAlert\InstallAlert.ps1"
```

Leave the window open or minimized. It monitors until you close the window,
press Ctrl+C, sign out, or restart. Speech uses the current Windows audio output:
if headphones are selected, the voice goes to the headphones. Check the volume.
The script uses the installed Windows voice; the spoken messages are in English.
ExecutionPolicy Bypass applies to this process; it does not change a saved
execution policy or override school policies such as AppLocker/WDAC.

Test the voice without installing anything:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\SchoolInstallAlert\InstallAlert.ps1" -TestAlert
```

Only one monitoring instance per mode runs in a Windows session.
An administrator account may be needed for process monitoring. If that source is
unavailable, the script warns and uses process-name polling, plus MSI events if accessible.

## 2. Optional: receive alerts on your teacher PC

Have the school IT administrator prepare an authenticated Windows shared folder,
for example `C:\InstallAlerts` on teacher PC `TEACHER-PC`, shared as `InstallAlerts`.
Student monitoring accounts need permission to create and publish files there;
the teacher needs read access. Both SMB share and NTFS permissions must allow it.
Use existing school accounts and firewall rules for the school network; do not
enable anonymous access, expose SMB to the internet, or embed passwords here.

On the teacher PC, run (ordinary Windows PowerShell is sufficient):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\SchoolInstallAlert\InstallAlert.ps1" -Mode Teacher -AlertFolder "C:\InstallAlerts"
```

On each student PC, use this command instead of the local-only command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\SchoolInstallAlert\InstallAlert.ps1" -AlertFolder "\\TEACHER-PC\InstallAlerts"
```

Replace `TEACHER-PC` with your teacher PC's real Windows computer name. The UNC
path is a folder share, not a website. Elevated sessions may use a different
account from the student's desktop; confirm that the account running the script
can access the share. Use UNC paths, not mapped drive letters.

Test the whole path from a student PC:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\SchoolInstallAlert\InstallAlert.ps1" -AlertFolder "\\TEACHER-PC\InstallAlerts" -TestAlert
```

You should hear a test on the student PC and see/hear that PC's name on the
teacher PC. Nothing is installed by this test. When the share is unavailable,
the student script keeps alerts in its local Outbox and retries while running.
Queued alerts also retry when you next run with an AlertFolder. No delivery is
guaranteed if someone closes the monitor before it detects an event.

Teacher mode scans every half second. LAN failures can take longer to time out.
Each alert includes its original UTC timestamp. Old queued alerts may arrive
after reconnection. The teacher records local receipts to avoid rereading alerts
after a restart. Keep the same teacher account and DataFolder for this to work.
The share is authenticated through Windows; computer names inside alert files
are self-reported, and this is not tamper-resistant monitoring.

## What it detects

| Alert | Meaning |
| --- | --- |
| Possible | A process name contains setup/install, or is msiexec.exe, winget.exe or choco.exe. A clue, not proof. |
| InstallerActivity | Windows Installer transaction event 1040. Could also be update, repair or removal. |
| Installed | Windows Installer event 11707 reports a successful installation operation. |
| Test | A deliberately simulated alert. |

Different stages can generate several alerts for the same installation. Repeated
identical alerts are suppressed for 30 seconds. Speech is limited to one message
per five seconds, so some alerts appear only in the console/log during bursts.

This does **not** detect every installation: renamed/custom EXE installers,
Microsoft Store installs, script-based deployments and portable apps may be
missed. Merely starting winget can produce an alert even for a search. Automatic
updates and legitimate maintenance can trigger alerts too. It identifies the
PC, not who initiated the action. It does not block installations.
No screenshots, keystrokes, browser history or full process command lines are
collected. Saved data is computer name, time, alert type, and installer/program
name. Use it visibly on school-managed PCs with school IT approval.

## Logs, startup and stopping

Local daily JSONL logs, pending Outbox alerts, and teacher receipts are stored in
`%LOCALAPPDATA%\SchoolInstallAlert` for the account running the script. Shared
JSON alerts remain in the teacher folder for review. Archive old shared alerts
and then corresponding receipts periodically; none are automatically deleted.

The provided Enable-Autostart setup creates a task for the current account.
For a customized deployment, have IT create a Task Scheduler task pointing
to `powershell.exe` with the same arguments shown above, a logon trigger, and
**Run only when user is logged on**. Speech needs an interactive desktop session.
The account must have any needed monitoring and share permissions. A task using
SYSTEM or **Run whether user is logged on or not** will not provide normal audible
desktop alerts. Configure **Do not start a new instance** and disable the default
three-day runtime limit. Elevation is only available if the task account has it;
do not give students administrator privileges just to run this script.

To stop a foreground instance, press Ctrl+C or close the script window. For the
background task use Disable-Autostart.cmd. There is no Windows service installed.
Automatic startup is added only by explicitly running Enable-Autostart.
Student users who can stop the process can stop monitoring.

Useful options: `-NoSpeech` keeps file/console alerts; `-DataFolder "C:\SomeFolder"`
changes local storage; `-RunSeconds 30` stops after 30 seconds for diagnostics.
The script is for Windows PowerShell 5.1, not PowerShell 7.

References:
- https://learn.microsoft.com/en-us/windows/win32/msi/event-logging
- https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/register-wmievent?view=powershell-5.1
- https://learn.microsoft.com/en-us/dotnet/api/system.speech.synthesis.speechsynthesizer.speakasync?view=netframework-4.8.1
- https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/DownloadRestrictions
- https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/downloadblockedforfiletypes
- https://support.google.com/chrome/a/answer/7579271?hl=en
