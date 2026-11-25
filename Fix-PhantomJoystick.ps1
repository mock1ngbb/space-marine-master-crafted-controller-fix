<#
Fix-PhantomJoystick.ps1

Some keyboards, mice and other gadgets (Keychron, some Logitech/Razer/Corsair
receivers, RGB controllers, etc.) tell Windows they are a joystick or gamepad.
Games that pick "the first controller" can grab that fake one and ignore your
real Xbox / PlayStation / Steam controller.

This script lists every joystick/gamepad device Windows sees, flags the ones
that look fake, lets you choose which to disable, and offers to restart.

  Run:   right-click > Run with PowerShell   (it asks for admin)
  Undo:  run it again and choose "U" to re-enable what you disabled,
         or Device Manager > Human Interface Devices > right-click > Enable.

Nothing is deleted; disabling a device is fully reversible.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host 'Asking for administrator rights (needed to disable devices)...'
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# Vendors that make real game controllers. A joystick from one of these is probably a real pad.
$ControllerVendors = @{
    '045E' = 'Microsoft (Xbox)'; '054C' = 'Sony (PlayStation)'; '28DE' = 'Valve (Steam)'
    '057E' = 'Nintendo';         '2DC8' = '8BitDo';             '0F0D' = 'Hori'
    '0E6F' = 'PDP';              '24C6' = 'PowerA';             '1532' = 'Razer'
    '3537' = 'GameSir';          '2563' = 'ShanWan';            '0079' = 'DragonRise'
    '11C0' = 'Betop';            '1209' = 'pid.codes (open-source / virtual devices)'
}

function Get-Prop($id, $key) {
    try { (Get-PnpDeviceProperty -InstanceId $id -KeyName $key -ErrorAction Stop).Data } catch { $null }
}

function Get-JoystickDevices {
    $all = Get-PnpDevice -ErrorAction Stop | Where-Object { $_.InstanceId -like 'HID\*' }
    # VID&PID pairs that also expose a keyboard or mouse: a joystick on the same gadget is almost always fake.
    $kbMouse = @{}
    foreach ($d in ($all | Where-Object Present)) {
        $hw = (Get-Prop $d.InstanceId 'DEVPKEY_Device_HardwareIds') -join ' '
        if ($hw -match 'HID_DEVICE_SYSTEM_(KEYBOARD|MOUSE)' -and $d.InstanceId -match 'VID_([0-9A-F]{4})&PID_([0-9A-F]{4})') {
            $kbMouse["$($Matches[1])&$($Matches[2])"] = $true
        }
    }
    foreach ($d in $all) {
        $hw = (Get-Prop $d.InstanceId 'DEVPKEY_Device_HardwareIds') -join ' '
        if ($hw -notmatch 'HID_DEVICE_SYSTEM_GAME') { continue }
        $vid = $prod = '????'
        if ($d.InstanceId -match 'VID_([0-9A-F]{4})&PID_([0-9A-F]{4})') { $vid = $Matches[1]; $prod = $Matches[2] }
        $usage = if ($hw -match 'U:0005') { 'gamepad' } elseif ($hw -match 'U:0004') { 'joystick' } else { 'game device' }
        $parent = Get-Prop $d.InstanceId 'DEVPKEY_Device_Parent'
        $name = $null
        while ($parent -and -not $name) {
            $name = Get-Prop $parent 'DEVPKEY_Device_BusReportedDeviceDesc'
            if (-not $name) { $parent = Get-Prop $parent 'DEVPKEY_Device_Parent'; if ($parent -notmatch '^(USB|HID|BTH)') { break } }
        }
        if (-not $name) { $name = $d.FriendlyName }
        $verdict =
            if ($d.Problem -eq 'CM_PROB_DISABLED')     { 'disabled' }
            elseif ($kbMouse["$vid&$prod"])            { 'LIKELY FAKE - same gadget is also a keyboard/mouse' }
            elseif ($ControllerVendors[$vid])         { "real controller? ($($ControllerVendors[$vid])) - keep" }
            else                                      { 'unknown - check the name' }
        [pscustomobject]@{
            Name = $name; Usage = $usage; VidPid = "$vid`:$prod"; Present = $d.Present
            Status = $d.Status; Verdict = $verdict; InstanceId = $d.InstanceId
        }
    }
}

function Show-List($list) {
    Write-Host ''
    for ($i = 0; $i -lt $list.Count; $i++) {
        $x = $list[$i]
        $color = if ($x.Verdict -like 'LIKELY FAKE*') { 'Yellow' } elseif ($x.Verdict -eq 'disabled') { 'DarkGray' } else { 'Gray' }
        $plug = if ($x.Present) { '' } else { ' (not plugged in)' }
        Write-Host ('[{0}] {1} - {2} [{3}]{4}' -f ($i + 1), $x.Name, $x.Usage, $x.VidPid, $plug) -ForegroundColor $color
        Write-Host ('     {0}' -f $x.Verdict) -ForegroundColor $color
    }
    Write-Host ''
}

$list = @(Get-JoystickDevices | Sort-Object { -not $_.Present }, Name)
if ($list.Count -eq 0) { Write-Host 'Windows sees no joystick/gamepad devices at all.'; Read-Host 'Press Enter to exit'; exit 0 }

Write-Host 'Joystick / gamepad devices Windows can see:' -ForegroundColor Cyan
Show-List $list
Write-Host 'Yellow = looks fake. Turn your real controllers ON first so you can tell them apart.'
Write-Host 'Type the numbers to DISABLE (e.g. 1 or 1,3), U to re-enable disabled ones, or Enter to quit.'
$answer = (Read-Host 'Choice').Trim()
if (-not $answer) { exit 0 }

$changed = $false
if ($answer -match '^[Uu]$') {
    foreach ($x in $list | Where-Object Verdict -eq 'disabled') {
        try { Enable-PnpDevice -InstanceId $x.InstanceId -Confirm:$false; Write-Host "Re-enabled: $($x.Name)" -ForegroundColor Green; $changed = $true }
        catch { Write-Host "Could not re-enable $($x.Name): $($_.Exception.Message)" -ForegroundColor Red }
    }
} else {
    $picks = $answer -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
    foreach ($n in $picks) {
        if ($n -lt 1 -or $n -gt $list.Count) { Write-Host "No item $n, skipped." -ForegroundColor Red; continue }
        $x = $list[$n - 1]
        if ($x.Verdict -like 'real controller*') {
            if ((Read-Host "$($x.Name) looks like a REAL controller. Disable anyway? (y/N)") -notmatch '^[Yy]') { continue }
        }
        try {
            Disable-PnpDevice -InstanceId $x.InstanceId -Confirm:$false
            Write-Host "Disabled: $($x.Name)" -ForegroundColor Green
        } catch {
            # Windows often refuses live changes to input devices while a reboot is pending; the change is usually applied at restart.
            Write-Host "Windows queued or refused disabling $($x.Name) ($($_.Exception.Message.Trim()))." -ForegroundColor Yellow
            Write-Host '  Restart, then run this script again to confirm it shows as disabled.' -ForegroundColor Yellow
        }
        $changed = $true
    }
}

if ($changed) {
    Write-Host ''
    if ((Read-Host 'Restart now so the change takes effect? (Y/n)') -notmatch '^[Nn]') {
        shutdown.exe /r /t 0
    } else {
        Write-Host 'OK - restart yourself before launching the game.'
        Read-Host 'Press Enter to exit'
    }
}
