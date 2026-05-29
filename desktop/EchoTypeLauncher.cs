using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Text;
using System.Windows.Forms;

namespace EchoTypeLauncher
{
    [DataContract]
    internal sealed class AppConfig
    {
        public AppConfig()
        {
            Modifiers = new List<string> { "Control", "Shift" };
            Key = "Space";
        }

        [DataMember]
        public List<string> Modifiers { get; set; }

        [DataMember]
        public string Key { get; set; }
    }

    internal static class NativeMethods
    {
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

    internal sealed class EchoTypeForm : Form
    {
        private readonly string configPath;
        private readonly int hotkeyId = 9001;
        private readonly string[] keyChoices =
        {
            "Space","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
            "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12"
        };

        private AppConfig appConfig;
        private bool hotkeyRegistered;
        private bool allowExit;
        private IntPtr lastTargetHandle = IntPtr.Zero;

        private Label hotkeyValueLabel;
        private Label stateValueLabel;
        private Label statusLabel;
        private Label hotkeyHelp;
        private CheckBox ctrlCheckbox;
        private CheckBox shiftCheckbox;
        private CheckBox altCheckbox;
        private CheckBox winCheckbox;
        private ComboBox keyCombo;
        private NotifyIcon notifyIcon;
        private ContextMenuStrip trayMenu;

        internal EchoTypeForm()
        {
            configPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "config.json");
            appConfig = LoadConfig();

            Text = "EchoType Desktop";
            StartPosition = FormStartPosition.CenterScreen;
            Size = new Size(760, 560);
            MinimumSize = new Size(760, 560);
            BackColor = Color.FromArgb(245, 245, 247);
            Font = new Font("Segoe UI", 10);

            BuildUi();
            BuildTray();
            ApplyConfigToControls();
            RegisterAppHotkey(appConfig.Modifiers, appConfig.Key);
        }

        private void BuildUi()
        {
            var titleLabel = new Label
            {
                Text = "EchoType Desktop",
                Font = new Font("Segoe UI", 24, FontStyle.Bold),
                AutoSize = true,
                Location = new Point(28, 24)
            };
            Controls.Add(titleLabel);

            var subtitleLabel = new Label
            {
                Text = "A system-wide voice input launcher for chat apps, browsers, and AI tools. Put your cursor where you want text, then use the hotkey.",
                MaximumSize = new Size(680, 0),
                AutoSize = true,
                ForeColor = Color.FromArgb(110, 110, 115),
                Location = new Point(32, 78)
            };
            Controls.Add(subtitleLabel);

            var hotkeyLabel = new Label
            {
                Text = "Global hotkey",
                AutoSize = true,
                Location = new Point(32, 150)
            };
            Controls.Add(hotkeyLabel);

            hotkeyValueLabel = new Label
            {
                Text = GetHotkeyDisplay(appConfig.Modifiers, appConfig.Key),
                AutoSize = true,
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                Location = new Point(32, 174)
            };
            Controls.Add(hotkeyValueLabel);

            var scopeLabel = new Label
            {
                Text = "Where it works",
                AutoSize = true,
                Location = new Point(250, 150)
            };
            Controls.Add(scopeLabel);

            var scopeValueLabel = new Label
            {
                Text = "Any active text field that supports Windows voice typing",
                MaximumSize = new Size(320, 0),
                AutoSize = true,
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                Location = new Point(250, 174)
            };
            Controls.Add(scopeValueLabel);

            var stateLabel = new Label
            {
                Text = "State",
                AutoSize = true,
                Location = new Point(590, 150)
            };
            Controls.Add(stateLabel);

            stateValueLabel = new Label
            {
                Text = "Ready",
                AutoSize = true,
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                Location = new Point(590, 174)
            };
            Controls.Add(stateValueLabel);

            var triggerButton = new Button
            {
                Text = "Trigger voice typing",
                Location = new Point(32, 242),
                Size = new Size(170, 42)
            };
            triggerButton.Click += delegate { InvokeVoiceTyping(); };
            Controls.Add(triggerButton);

            var settingsButton = new Button
            {
                Text = "Open typing settings",
                Location = new Point(218, 242),
                Size = new Size(170, 42)
            };
            settingsButton.Click += delegate
            {
                System.Diagnostics.Process.Start("ms-settings:typing");
                UpdateStatus("Opened Windows typing settings.", "Settings");
            };
            Controls.Add(settingsButton);

            var languageButton = new Button
            {
                Text = "Open language settings",
                Location = new Point(404, 242),
                Size = new Size(180, 42)
            };
            languageButton.Click += delegate
            {
                System.Diagnostics.Process.Start("ms-settings:regionlanguage");
                UpdateStatus("Opened Windows language settings.", "Settings");
            };
            Controls.Add(languageButton);

            var trayButton = new Button
            {
                Text = "Hide to tray",
                Location = new Point(600, 242),
                Size = new Size(112, 42)
            };
            trayButton.Click += delegate { HideToTray(); };
            Controls.Add(trayButton);

            statusLabel = new Label
            {
                Text = "Ready. Click into any chat box, browser field, or AI prompt and use the hotkey.",
                MaximumSize = new Size(680, 0),
                AutoSize = true,
                ForeColor = Color.FromArgb(110, 110, 115),
                Location = new Point(32, 308)
            };
            Controls.Add(statusLabel);

            var hotkeyPanel = new Panel
            {
                Location = new Point(32, 356),
                Size = new Size(680, 124),
                BackColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle
            };
            Controls.Add(hotkeyPanel);

            var panelTitle = new Label
            {
                Text = "Hotkey and tray",
                AutoSize = true,
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                Location = new Point(18, 16)
            };
            hotkeyPanel.Controls.Add(panelTitle);

            ctrlCheckbox = new CheckBox { Text = "Ctrl", AutoSize = true, Location = new Point(18, 48) };
            shiftCheckbox = new CheckBox { Text = "Shift", AutoSize = true, Location = new Point(84, 48) };
            altCheckbox = new CheckBox { Text = "Alt", AutoSize = true, Location = new Point(160, 48) };
            winCheckbox = new CheckBox { Text = "Win", AutoSize = true, Location = new Point(218, 48) };
            hotkeyPanel.Controls.Add(ctrlCheckbox);
            hotkeyPanel.Controls.Add(shiftCheckbox);
            hotkeyPanel.Controls.Add(altCheckbox);
            hotkeyPanel.Controls.Add(winCheckbox);

            var keyLabel = new Label
            {
                Text = "Key",
                AutoSize = true,
                Location = new Point(302, 50)
            };
            hotkeyPanel.Controls.Add(keyLabel);

            keyCombo = new ComboBox
            {
                DropDownStyle = ComboBoxStyle.DropDownList,
                Location = new Point(340, 46),
                Size = new Size(120, 28)
            };
            keyCombo.Items.AddRange(keyChoices);
            hotkeyPanel.Controls.Add(keyCombo);

            var applyHotkeyButton = new Button
            {
                Text = "Save hotkey",
                Location = new Point(480, 43),
                Size = new Size(112, 34)
            };
            applyHotkeyButton.Click += delegate { TryApplyHotkey(); };
            hotkeyPanel.Controls.Add(applyHotkeyButton);

            hotkeyHelp = new Label
            {
                Text = "EchoType can stay in the tray and keep the global hotkey active while you work. Installed Windows input languages: " + GetLanguageSummary() + ".",
                MaximumSize = new Size(632, 0),
                AutoSize = true,
                ForeColor = Color.FromArgb(110, 110, 115),
                Location = new Point(18, 84)
            };
            hotkeyPanel.Controls.Add(hotkeyHelp);

            var footnoteLabel = new Label
            {
                Text = "Tip: this app uses Windows' own voice typing layer, which is exactly why it can work outside a browser.",
                MaximumSize = new Size(680, 0),
                AutoSize = true,
                ForeColor = Color.FromArgb(110, 110, 115),
                Location = new Point(32, 496)
            };
            Controls.Add(footnoteLabel);

            Resize += delegate
            {
                if (WindowState == FormWindowState.Minimized)
                {
                    HideToTray();
                }
            };
        }

        private void BuildTray()
        {
            trayMenu = new ContextMenuStrip();
            trayMenu.Items.Add("Open EchoType", null, delegate { ShowMainWindow(); });
            trayMenu.Items.Add("Trigger voice typing", null, delegate { InvokeVoiceTyping(); });
            trayMenu.Items.Add("Exit", null, delegate
            {
                allowExit = true;
                Close();
            });

            notifyIcon = new NotifyIcon
            {
                Icon = SystemIcons.Information,
                Text = "EchoType",
                Visible = true,
                ContextMenuStrip = trayMenu
            };
            notifyIcon.DoubleClick += delegate { ShowMainWindow(); };
        }

        private void ApplyConfigToControls()
        {
            ctrlCheckbox.Checked = appConfig.Modifiers.Contains("Control");
            shiftCheckbox.Checked = appConfig.Modifiers.Contains("Shift");
            altCheckbox.Checked = appConfig.Modifiers.Contains("Alt");
            winCheckbox.Checked = appConfig.Modifiers.Contains("Win");
            keyCombo.SelectedItem = appConfig.Key;
            hotkeyValueLabel.Text = GetHotkeyDisplay(appConfig.Modifiers, appConfig.Key);
        }

        private void TryApplyHotkey()
        {
            try
            {
                var modifiers = GetSelectedModifiers();
                var key = keyCombo.SelectedItem != null ? keyCombo.SelectedItem.ToString() : string.Empty;
                if (modifiers.Count == 0)
                {
                    throw new InvalidOperationException("Choose at least one modifier key.");
                }
                if (string.IsNullOrWhiteSpace(key))
                {
                    throw new InvalidOperationException("Choose a hotkey key.");
                }

                RegisterAppHotkey(modifiers, key);
                appConfig = new AppConfig { Modifiers = modifiers, Key = key };
                SaveConfig(appConfig);
                hotkeyValueLabel.Text = GetHotkeyDisplay(modifiers, key);
                UpdateStatus("Saved hotkey: " + hotkeyValueLabel.Text, "Ready");
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "EchoType", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }

        private List<string> GetSelectedModifiers()
        {
            var modifiers = new List<string>();
            if (ctrlCheckbox.Checked) modifiers.Add("Control");
            if (shiftCheckbox.Checked) modifiers.Add("Shift");
            if (altCheckbox.Checked) modifiers.Add("Alt");
            if (winCheckbox.Checked) modifiers.Add("Win");
            return modifiers;
        }

        private void RegisterAppHotkey(List<string> modifiers, string keyName)
        {
            UnregisterAppHotkey();

            var modifierMask = GetHotkeyModifierMask(modifiers);
            var keyValue = GetHotkeyKeyValue(keyName);
            hotkeyRegistered = NativeMethods.RegisterHotKey(Handle, hotkeyId, modifierMask, keyValue);

            if (!hotkeyRegistered)
            {
                throw new InvalidOperationException("Failed to register " + GetHotkeyDisplay(modifiers, keyName) + ". Another app may already be using it.");
            }
        }

        private void UnregisterAppHotkey()
        {
            if (hotkeyRegistered)
            {
                try
                {
                    NativeMethods.UnregisterHotKey(Handle, hotkeyId);
                }
                catch
                {
                }

                hotkeyRegistered = false;
            }
        }

        private static int GetHotkeyModifierMask(IEnumerable<string> modifiers)
        {
            var mask = 0;
            foreach (var modifier in modifiers)
            {
                switch (modifier)
                {
                    case "Control":
                        mask |= NativeMethods.MOD_CONTROL;
                        break;
                    case "Shift":
                        mask |= NativeMethods.MOD_SHIFT;
                        break;
                    case "Alt":
                        mask |= NativeMethods.MOD_ALT;
                        break;
                    case "Win":
                        mask |= NativeMethods.MOD_WIN;
                        break;
                }
            }

            return mask;
        }

        private static int GetHotkeyKeyValue(string keyName)
        {
            return keyName == "Space" ? (int)Keys.Space : (int)Enum.Parse(typeof(Keys), keyName, true);
        }

        private static string GetHotkeyDisplay(IEnumerable<string> modifiers, string keyName)
        {
            return string.Join(" + ", modifiers.Concat(new[] { keyName }));
        }

        private static string GetLanguageSummary()
        {
            var names = InputLanguage.InstalledInputLanguages
                .Cast<InputLanguage>()
                .Select(language => language.Culture.EnglishName)
                .Distinct()
                .ToArray();

            return names.Length > 0 ? string.Join(", ", names) : "Windows input languages";
        }

        private void InvokeVoiceTyping()
        {
            lastTargetHandle = NativeMethods.GetForegroundWindow();
            if (lastTargetHandle == Handle)
            {
                lastTargetHandle = IntPtr.Zero;
            }

            if (lastTargetHandle != IntPtr.Zero)
            {
                NativeMethods.ShowWindowAsync(lastTargetHandle, NativeMethods.SW_RESTORE);
                NativeMethods.SetForegroundWindow(lastTargetHandle);
                System.Threading.Thread.Sleep(120);
            }

            NativeMethods.keybd_event(NativeMethods.VK_LWIN, 0, 0, UIntPtr.Zero);
            NativeMethods.keybd_event(NativeMethods.VK_H, 0, 0, UIntPtr.Zero);
            NativeMethods.keybd_event(NativeMethods.VK_H, 0, NativeMethods.KEYEVENTF_KEYUP, UIntPtr.Zero);
            NativeMethods.keybd_event(NativeMethods.VK_LWIN, 0, NativeMethods.KEYEVENTF_KEYUP, UIntPtr.Zero);

            UpdateStatus("Windows voice typing was triggered. Speak into the target app.", "Listening");
        }

        private void UpdateStatus(string text, string state)
        {
            statusLabel.Text = text;
            if (!string.IsNullOrWhiteSpace(state))
            {
                stateValueLabel.Text = state;
            }
        }

        private void ShowMainWindow()
        {
            NativeMethods.ShowWindowAsync(Handle, NativeMethods.SW_RESTORE);
            Show();
            WindowState = FormWindowState.Normal;
            Activate();
        }

        private void HideToTray()
        {
            Hide();
            notifyIcon.Visible = true;
            UpdateStatus("Hidden to tray. EchoType is still running in the background.", "Tray");
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == NativeMethods.WM_HOTKEY)
            {
                InvokeVoiceTyping();
            }

            base.WndProc(ref m);
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (!allowExit)
            {
                e.Cancel = true;
                HideToTray();
                return;
            }

            UnregisterAppHotkey();
            if (notifyIcon != null)
            {
                notifyIcon.Visible = false;
                notifyIcon.Dispose();
            }
            if (trayMenu != null)
            {
                trayMenu.Dispose();
            }

            base.OnFormClosing(e);
        }

        private AppConfig LoadConfig()
        {
            try
            {
                if (!File.Exists(configPath))
                {
                    return new AppConfig();
                }

                using (var stream = File.OpenRead(configPath))
                {
                    var serializer = new DataContractJsonSerializer(typeof(AppConfig));
                    return (AppConfig)serializer.ReadObject(stream);
                }
            }
            catch
            {
                return new AppConfig();
            }
        }

        private void SaveConfig(AppConfig config)
        {
            using (var stream = File.Create(configPath))
            {
                var serializer = new DataContractJsonSerializer(typeof(AppConfig));
                serializer.WriteObject(stream, config);
            }
        }
    }

    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new EchoTypeForm());
        }
    }
}
