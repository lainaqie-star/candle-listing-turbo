param(
  [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne "STA") {
  $argumentList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-STA",
    "-File", "`"$PSCommandPath`""
  )

  if ($SelfTest) {
    $argumentList += "-SelfTest"
  }

  Start-Process -FilePath "powershell.exe" -ArgumentList $argumentList | Out-Null
  exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:configPath = Join-Path $PSScriptRoot "config.json"
$script:lastTargetHandle = [IntPtr]::Zero
$script:allowExit = $false
$script:notifyIcon = $null
$script:trayMenu = $null
$script:hotkeyWindow = $null
$script:hotkeyId = 9001
$script:hotkeyRegistered = $false
$script:keyChoices = @(
  "Space","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
  "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12"
)
$script:appConfig = [pscustomobject]@{
  Modifiers = @("Control", "Shift")
  Key = "Space"
}

if ($SelfTest) {
  [System.Windows.Forms.InputLanguage]::InstalledInputLanguages |
    ForEach-Object { "{0} | {1}" -f $_.Culture.Name, $_.Culture.EnglishName } |
    Write-Output
  exit
}

Add-Type -TypeDefinition @"
using System;
using System.Windows.Forms;
using System.Runtime.InteropServices;

namespace EchoType {
  public static class NativeMethods {
    public const int WM_HOTKEY = 0x0312;
    public const int MOD_ALT = 0x0001;
    public const int MOD_CONTROL = 0x0002;
    public const int MOD_SHIFT = 0x0004;
    public const int MOD_WIN = 0x0008;
    public const int SW_RESTORE = 9;
    public const byte VK_LWIN = 0x5B;
    public const byte VK_H = 0x48;
    public const uint KEYEVENTF_KEYUP = 0x0002;

    [DllImport("user32.dll")]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, int fsModifiers, int vk);

    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  }

  public class HotkeyWindow : NativeWindow, IDisposable {
    public event EventHandler HotkeyPressed;

    public HotkeyWindow() {
      CreateHandle(new CreateParams());
    }

    protected override void WndProc(ref Message m) {
      if (m.Msg == NativeMethods.WM_HOTKEY && HotkeyPressed != null) {
        HotkeyPressed(this, EventArgs.Empty);
      }
      base.WndProc(ref m);
    }

    public void Dispose() {
      DestroyHandle();
    }
  }

  public static class VoiceTypingBridge {
    public static void Trigger() {
      NativeMethods.keybd_event(NativeMethods.VK_LWIN, 0, 0, UIntPtr.Zero);
      NativeMethods.keybd_event(NativeMethods.VK_H, 0, 0, UIntPtr.Zero);
      NativeMethods.keybd_event(NativeMethods.VK_H, 0, NativeMethods.KEYEVENTF_KEYUP, UIntPtr.Zero);
      NativeMethods.keybd_event(NativeMethods.VK_LWIN, 0, NativeMethods.KEYEVENTF_KEYUP, UIntPtr.Zero);
    }
  }
}
"@ -ReferencedAssemblies @("System.dll", "System.Windows.Forms.dll")

function Load-Config {
  if (-not (Test-Path $script:configPath)) {
    return
  }

  try {
    $raw = Get-Content -Raw $script:configPath | ConvertFrom-Json
    if ($raw.Modifiers -and $raw.Key) {
      $script:appConfig = [pscustomobject]@{
        Modifiers = @($raw.Modifiers)
        Key = [string]$raw.Key
      }
    }
  } catch {}
}

function Save-Config {
  $script:appConfig | ConvertTo-Json | Set-Content -Path $script:configPath
}

function Get-HotkeyModifierMask {
  param(
    [string[]]$Modifiers
  )

  $mask = 0
  foreach ($modifier in $Modifiers) {
    switch ($modifier) {
      "Control" { $mask = $mask -bor [EchoType.NativeMethods]::MOD_CONTROL }
      "Shift" { $mask = $mask -bor [EchoType.NativeMethods]::MOD_SHIFT }
      "Alt" { $mask = $mask -bor [EchoType.NativeMethods]::MOD_ALT }
      "Win" { $mask = $mask -bor [EchoType.NativeMethods]::MOD_WIN }
    }
  }
  return $mask
}

function Get-HotkeyKeysValue {
  param(
    [string]$KeyName
  )

  switch ($KeyName) {
    "Space" { return [int][System.Windows.Forms.Keys]::Space }
    default { return [int][System.Windows.Forms.Keys]::$KeyName }
  }
}

function Get-HotkeyDisplay {
  param(
    [string[]]$Modifiers,
    [string]$KeyName
  )

  return ((@($Modifiers) + @($KeyName)) -join " + ")
}

function Get-SelectedModifiers {
  $mods = @()
  if ($ctrlCheckbox.Checked) { $mods += "Control" }
  if ($shiftCheckbox.Checked) { $mods += "Shift" }
  if ($altCheckbox.Checked) { $mods += "Alt" }
  if ($winCheckbox.Checked) { $mods += "Win" }
  return $mods
}

function Update-Status {
  param(
    [string]$Text,
    [string]$State = ""
  )

  $statusLabel.Text = $Text
  if ($State) {
    $stateValueLabel.Text = $State
  }
}

function Unregister-AppHotkey {
  if ($script:hotkeyRegistered -and $script:hotkeyWindow) {
    try {
      [EchoType.NativeMethods]::UnregisterHotKey($script:hotkeyWindow.Handle, $script:hotkeyId) | Out-Null
    } catch {}
    $script:hotkeyRegistered = $false
  }
}

function Register-AppHotkey {
  param(
    [string[]]$Modifiers,
    [string]$KeyName
  )

  Unregister-AppHotkey

  $modifierMask = Get-HotkeyModifierMask -Modifiers $Modifiers
  $virtualKey = Get-HotkeyKeysValue -KeyName $KeyName

  $ok = [EchoType.NativeMethods]::RegisterHotKey(
    $script:hotkeyWindow.Handle,
    $script:hotkeyId,
    $modifierMask,
    $virtualKey
  )

  if (-not $ok) {
    throw "Failed to register $(Get-HotkeyDisplay -Modifiers $Modifiers -KeyName $KeyName). Another app may already be using it."
  }

  $script:hotkeyRegistered = $true
}

function Apply-HotkeyFromControls {
  $selectedModifiers = @(Get-SelectedModifiers)
  $selectedKey = [string]$keyCombo.SelectedItem

  if ($selectedModifiers.Count -eq 0) {
    throw "Choose at least one modifier key."
  }

  if (-not $selectedKey) {
    throw "Choose a hotkey key."
  }

  Register-AppHotkey -Modifiers $selectedModifiers -KeyName $selectedKey
  $script:appConfig = [pscustomobject]@{
    Modifiers = $selectedModifiers
    Key = $selectedKey
  }
  Save-Config
  $hotkeyValueLabel.Text = Get-HotkeyDisplay -Modifiers $selectedModifiers -KeyName $selectedKey
  Update-Status -Text ("Saved hotkey: " + $hotkeyValueLabel.Text) -State "Ready"
}

function Show-MainWindow {
  [EchoType.NativeMethods]::ShowWindowAsync($form.Handle, [EchoType.NativeMethods]::SW_RESTORE) | Out-Null
  $form.Show()
  $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
  $form.Activate()
}

function Hide-ToTray {
  $form.Hide()
  if ($script:notifyIcon) {
    $script:notifyIcon.Visible = $true
  }
  Update-Status -Text "Hidden to tray. EchoType is still running in the background." -State "Tray"
}

function Invoke-VoiceTyping {
  $script:lastTargetHandle = [EchoType.NativeMethods]::GetForegroundWindow()
  if ($script:lastTargetHandle -eq $form.Handle) {
    $script:lastTargetHandle = [IntPtr]::Zero
  }

  if ($script:lastTargetHandle -ne [IntPtr]::Zero) {
    [EchoType.NativeMethods]::ShowWindowAsync($script:lastTargetHandle, [EchoType.NativeMethods]::SW_RESTORE) | Out-Null
    [EchoType.NativeMethods]::SetForegroundWindow($script:lastTargetHandle) | Out-Null
    Start-Sleep -Milliseconds 120
  }

  [EchoType.VoiceTypingBridge]::Trigger()
  Update-Status -Text "Windows voice typing was triggered. Speak into the target app." -State "Listening"
}

Load-Config

$installedInputLanguages = [System.Windows.Forms.InputLanguage]::InstalledInputLanguages
$languageSummary = ($installedInputLanguages | ForEach-Object { $_.Culture.EnglishName }) -join ", "
if (-not $languageSummary) {
  $languageSummary = "Windows input languages"
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "EchoType Desktop MVP"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(760, 560)
$form.MinimumSize = New-Object System.Drawing.Size(760, 560)
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 247)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "EchoType Desktop MVP"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(28, 24)
$form.Controls.Add($titleLabel)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "A system-wide voice input launcher for chat apps, browsers, and AI tools. Put your cursor where you want text, then use the hotkey."
$subtitleLabel.MaximumSize = New-Object System.Drawing.Size(680, 0)
$subtitleLabel.AutoSize = $true
$subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 115)
$subtitleLabel.Location = New-Object System.Drawing.Point(32, 78)
$form.Controls.Add($subtitleLabel)

$hotkeyLabel = New-Object System.Windows.Forms.Label
$hotkeyLabel.Text = "Global hotkey"
$hotkeyLabel.AutoSize = $true
$hotkeyLabel.Location = New-Object System.Drawing.Point(32, 150)
$form.Controls.Add($hotkeyLabel)

$hotkeyValueLabel = New-Object System.Windows.Forms.Label
$hotkeyValueLabel.Text = Get-HotkeyDisplay -Modifiers $script:appConfig.Modifiers -KeyName $script:appConfig.Key
$hotkeyValueLabel.AutoSize = $true
$hotkeyValueLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$hotkeyValueLabel.Location = New-Object System.Drawing.Point(32, 174)
$form.Controls.Add($hotkeyValueLabel)

$scopeLabel = New-Object System.Windows.Forms.Label
$scopeLabel.Text = "Where it works"
$scopeLabel.AutoSize = $true
$scopeLabel.Location = New-Object System.Drawing.Point(250, 150)
$form.Controls.Add($scopeLabel)

$scopeValueLabel = New-Object System.Windows.Forms.Label
$scopeValueLabel.Text = "Any active text field that supports Windows voice typing"
$scopeValueLabel.MaximumSize = New-Object System.Drawing.Size(320, 0)
$scopeValueLabel.AutoSize = $true
$scopeValueLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$scopeValueLabel.Location = New-Object System.Drawing.Point(250, 174)
$form.Controls.Add($scopeValueLabel)

$stateLabel = New-Object System.Windows.Forms.Label
$stateLabel.Text = "State"
$stateLabel.AutoSize = $true
$stateLabel.Location = New-Object System.Drawing.Point(590, 150)
$form.Controls.Add($stateLabel)

$stateValueLabel = New-Object System.Windows.Forms.Label
$stateValueLabel.Text = "Ready"
$stateValueLabel.AutoSize = $true
$stateValueLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$stateValueLabel.Location = New-Object System.Drawing.Point(590, 174)
$form.Controls.Add($stateValueLabel)

$triggerButton = New-Object System.Windows.Forms.Button
$triggerButton.Text = "Trigger voice typing"
$triggerButton.Location = New-Object System.Drawing.Point(32, 242)
$triggerButton.Size = New-Object System.Drawing.Size(170, 42)
$form.Controls.Add($triggerButton)

$settingsButton = New-Object System.Windows.Forms.Button
$settingsButton.Text = "Open typing settings"
$settingsButton.Location = New-Object System.Drawing.Point(218, 242)
$settingsButton.Size = New-Object System.Drawing.Size(170, 42)
$form.Controls.Add($settingsButton)

$languageButton = New-Object System.Windows.Forms.Button
$languageButton.Text = "Open language settings"
$languageButton.Location = New-Object System.Drawing.Point(404, 242)
$languageButton.Size = New-Object System.Drawing.Size(180, 42)
$form.Controls.Add($languageButton)

$trayButton = New-Object System.Windows.Forms.Button
$trayButton.Text = "Hide to tray"
$trayButton.Location = New-Object System.Drawing.Point(600, 242)
$trayButton.Size = New-Object System.Drawing.Size(112, 42)
$form.Controls.Add($trayButton)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready. Click into any chat box, browser field, or AI prompt and use the hotkey."
$statusLabel.MaximumSize = New-Object System.Drawing.Size(680, 0)
$statusLabel.AutoSize = $true
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 115)
$statusLabel.Location = New-Object System.Drawing.Point(32, 308)
$form.Controls.Add($statusLabel)

$hotkeyPanel = New-Object System.Windows.Forms.Panel
$hotkeyPanel.Location = New-Object System.Drawing.Point(32, 356)
$hotkeyPanel.Size = New-Object System.Drawing.Size(680, 124)
$hotkeyPanel.BackColor = [System.Drawing.Color]::White
$hotkeyPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$form.Controls.Add($hotkeyPanel)

$panelTitle = New-Object System.Windows.Forms.Label
$panelTitle.Text = "Hotkey and tray"
$panelTitle.AutoSize = $true
$panelTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$panelTitle.Location = New-Object System.Drawing.Point(18, 16)
$hotkeyPanel.Controls.Add($panelTitle)

$ctrlCheckbox = New-Object System.Windows.Forms.CheckBox
$ctrlCheckbox.Text = "Ctrl"
$ctrlCheckbox.AutoSize = $true
$ctrlCheckbox.Location = New-Object System.Drawing.Point(18, 48)
$hotkeyPanel.Controls.Add($ctrlCheckbox)

$shiftCheckbox = New-Object System.Windows.Forms.CheckBox
$shiftCheckbox.Text = "Shift"
$shiftCheckbox.AutoSize = $true
$shiftCheckbox.Location = New-Object System.Drawing.Point(84, 48)
$hotkeyPanel.Controls.Add($shiftCheckbox)

$altCheckbox = New-Object System.Windows.Forms.CheckBox
$altCheckbox.Text = "Alt"
$altCheckbox.AutoSize = $true
$altCheckbox.Location = New-Object System.Drawing.Point(160, 48)
$hotkeyPanel.Controls.Add($altCheckbox)

$winCheckbox = New-Object System.Windows.Forms.CheckBox
$winCheckbox.Text = "Win"
$winCheckbox.AutoSize = $true
$winCheckbox.Location = New-Object System.Drawing.Point(218, 48)
$hotkeyPanel.Controls.Add($winCheckbox)

$keyLabel = New-Object System.Windows.Forms.Label
$keyLabel.Text = "Key"
$keyLabel.AutoSize = $true
$keyLabel.Location = New-Object System.Drawing.Point(302, 50)
$hotkeyPanel.Controls.Add($keyLabel)

$keyCombo = New-Object System.Windows.Forms.ComboBox
$keyCombo.DropDownStyle = "DropDownList"
$keyCombo.Location = New-Object System.Drawing.Point(340, 46)
$keyCombo.Size = New-Object System.Drawing.Size(120, 28)
[void]$keyCombo.Items.AddRange($script:keyChoices)
$hotkeyPanel.Controls.Add($keyCombo)

$applyHotkeyButton = New-Object System.Windows.Forms.Button
$applyHotkeyButton.Text = "Save hotkey"
$applyHotkeyButton.Location = New-Object System.Drawing.Point(480, 43)
$applyHotkeyButton.Size = New-Object System.Drawing.Size(112, 34)
$hotkeyPanel.Controls.Add($applyHotkeyButton)

$hotkeyHelp = New-Object System.Windows.Forms.Label
$hotkeyHelp.Text = "EchoType can stay in the tray and keep the global hotkey active while you work. Installed Windows input languages: $languageSummary."
$hotkeyHelp.MaximumSize = New-Object System.Drawing.Size(632, 0)
$hotkeyHelp.AutoSize = $true
$hotkeyHelp.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 115)
$hotkeyHelp.Location = New-Object System.Drawing.Point(18, 84)
$hotkeyPanel.Controls.Add($hotkeyHelp)

$footnoteLabel = New-Object System.Windows.Forms.Label
$footnoteLabel.Text = "Tip: this MVP uses Windows' own voice typing layer, which is exactly why it can work outside a browser."
$footnoteLabel.MaximumSize = New-Object System.Drawing.Size(680, 0)
$footnoteLabel.AutoSize = $true
$footnoteLabel.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 115)
$footnoteLabel.Location = New-Object System.Drawing.Point(32, 496)
$form.Controls.Add($footnoteLabel)

$ctrlCheckbox.Checked = $script:appConfig.Modifiers -contains "Control"
$shiftCheckbox.Checked = $script:appConfig.Modifiers -contains "Shift"
$altCheckbox.Checked = $script:appConfig.Modifiers -contains "Alt"
$winCheckbox.Checked = $script:appConfig.Modifiers -contains "Win"
$keyCombo.SelectedItem = $script:appConfig.Key

$triggerButton.Add_Click({ Invoke-VoiceTyping })

$settingsButton.Add_Click({
  Start-Process "ms-settings:typing" | Out-Null
  Update-Status -Text "Opened Windows typing settings." -State "Settings"
})

$languageButton.Add_Click({
  Start-Process "ms-settings:regionlanguage" | Out-Null
  Update-Status -Text "Opened Windows language settings." -State "Settings"
})

$trayButton.Add_Click({
  Hide-ToTray
})

$applyHotkeyButton.Add_Click({
  try {
    Apply-HotkeyFromControls
  } catch {
    [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "EchoType", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
  }
})

$script:hotkeyWindow = New-Object EchoType.HotkeyWindow
$script:notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
$script:notifyIcon.Text = "EchoType"
$script:notifyIcon.Visible = $true

$script:trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
[void]$script:trayMenu.Items.Add("Open EchoType", $null, { Show-MainWindow })
[void]$script:trayMenu.Items.Add("Trigger voice typing", $null, { Invoke-VoiceTyping })
[void]$script:trayMenu.Items.Add("Exit", $null, {
  $script:allowExit = $true
  $form.Close()
})
$script:notifyIcon.ContextMenuStrip = $script:trayMenu
$script:notifyIcon.add_DoubleClick({ Show-MainWindow })

Register-AppHotkey -Modifiers $script:appConfig.Modifiers -KeyName $script:appConfig.Key

$script:hotkeyWindow.add_HotkeyPressed({
  Invoke-VoiceTyping
})

$form.Add_Resize({
  if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
    Hide-ToTray
  }
})

$form.Add_FormClosing({
  if (-not $script:allowExit) {
    $_.Cancel = $true
    Hide-ToTray
    return
  }

  try { Unregister-AppHotkey } catch {}
  try { $script:hotkeyWindow.Dispose() } catch {}
  try {
    $script:notifyIcon.Visible = $false
    $script:notifyIcon.Dispose()
  } catch {}
  try { $script:trayMenu.Dispose() } catch {}
})

[void]$form.ShowDialog()
