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
    public const int MOD_CONTROL = 0x0002;
    public const int MOD_SHIFT = 0x0004;
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
      if (m.Msg == NativeMethods.WM_HOTKEY) {
        if (HotkeyPressed != null) {
          HotkeyPressed(this, EventArgs.Empty);
        }
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

$script:lastTargetHandle = [IntPtr]::Zero
$script:isPrimed = $false

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
  $script:isPrimed = $true
  Update-Status -Text "Windows voice typing was triggered. Speak into the target app." -State "Listening"
}

$installedInputLanguages = [System.Windows.Forms.InputLanguage]::InstalledInputLanguages
$languageSummary = ($installedInputLanguages | ForEach-Object { $_.Culture.EnglishName }) -join ", "
if (-not $languageSummary) {
  $languageSummary = "Windows input languages"
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "EchoType Desktop MVP"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(760, 540)
$form.MinimumSize = New-Object System.Drawing.Size(760, 540)
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
$hotkeyValueLabel.Text = "Ctrl + Shift + Space"
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

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready. Click into any chat box, browser field, or AI prompt and use the hotkey."
$statusLabel.MaximumSize = New-Object System.Drawing.Size(680, 0)
$statusLabel.AutoSize = $true
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 115)
$statusLabel.Location = New-Object System.Drawing.Point(32, 308)
$form.Controls.Add($statusLabel)

$cardPanel = New-Object System.Windows.Forms.Panel
$cardPanel.Location = New-Object System.Drawing.Point(32, 356)
$cardPanel.Size = New-Object System.Drawing.Size(680, 116)
$cardPanel.BackColor = [System.Drawing.Color]::White
$cardPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$form.Controls.Add($cardPanel)

$cardTitle = New-Object System.Windows.Forms.Label
$cardTitle.Text = "Language behavior"
$cardTitle.AutoSize = $true
$cardTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$cardTitle.Location = New-Object System.Drawing.Point(18, 16)
$cardPanel.Controls.Add($cardTitle)

$cardBody = New-Object System.Windows.Forms.Label
$cardBody.Text = "EchoType follows Windows voice typing. Switch your Windows input language to dictate in Chinese, English, Japanese, and other installed languages. Current installed input languages: $languageSummary."
$cardBody.MaximumSize = New-Object System.Drawing.Size(640, 0)
$cardBody.AutoSize = $true
$cardBody.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 115)
$cardBody.Location = New-Object System.Drawing.Point(18, 42)
$cardPanel.Controls.Add($cardBody)

$footnoteLabel = New-Object System.Windows.Forms.Label
$footnoteLabel.Text = "Tip: this MVP uses Windows' own voice typing layer, which is exactly why it can work outside a browser."
$footnoteLabel.MaximumSize = New-Object System.Drawing.Size(680, 0)
$footnoteLabel.AutoSize = $true
$footnoteLabel.ForeColor = [System.Drawing.Color]::FromArgb(110, 110, 115)
$footnoteLabel.Location = New-Object System.Drawing.Point(32, 484)
$form.Controls.Add($footnoteLabel)

$triggerButton.Add_Click({ Invoke-VoiceTyping })

$settingsButton.Add_Click({
  Start-Process "ms-settings:typing" | Out-Null
  Update-Status -Text "Opened Windows typing settings." -State "Settings"
})

$languageButton.Add_Click({
  Start-Process "ms-settings:regionlanguage" | Out-Null
  Update-Status -Text "Opened Windows language settings." -State "Settings"
})

$hotkeyWindow = New-Object EchoType.HotkeyWindow
$hotkeyId = 9001
$hotkeyRegistered = [EchoType.NativeMethods]::RegisterHotKey(
  $hotkeyWindow.Handle,
  $hotkeyId,
  ([EchoType.NativeMethods]::MOD_CONTROL -bor [EchoType.NativeMethods]::MOD_SHIFT),
  0x20
)

if (-not $hotkeyRegistered) {
  throw "Failed to register Ctrl+Shift+Space. Another app may already be using it."
}

$hotkeyWindow.add_HotkeyPressed({
  Invoke-VoiceTyping
})

$form.Add_FormClosing({
  try {
    [EchoType.NativeMethods]::UnregisterHotKey($hotkeyWindow.Handle, $hotkeyId) | Out-Null
  } catch {}

  try { $hotkeyWindow.Dispose() } catch {}
})

[void]$form.ShowDialog()
