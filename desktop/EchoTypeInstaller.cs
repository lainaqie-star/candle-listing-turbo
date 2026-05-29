using System;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

[assembly: AssemblyTitle("EchoType Setup")]
[assembly: AssemblyDescription("Installer for EchoType Desktop")]
[assembly: AssemblyCompany("EchoType")]
[assembly: AssemblyProduct("EchoType Setup")]
[assembly: AssemblyCopyright("Copyright © 2026 EchoType")]
[assembly: AssemblyVersion("0.1.0.0")]
[assembly: AssemblyFileVersion("0.1.0.0")]

namespace EchoTypeSetup
{
    internal sealed class InstallerForm : Form
    {
        private readonly string installDirectory;
        private Label statusLabel;
        private TextBox pathBox;
        private Button installButton;
        private Button launchButton;

        internal InstallerForm()
        {
            installDirectory = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs",
                "EchoType"
            );

            Text = "EchoType Setup";
            StartPosition = FormStartPosition.CenterScreen;
            Size = new Size(640, 420);
            MinimumSize = new Size(640, 420);
            BackColor = Color.FromArgb(245, 245, 247);
            Font = new Font("Segoe UI", 10);
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);

            BuildUi();
        }

        private void BuildUi()
        {
            var titleLabel = new Label
            {
                Text = "Install EchoType",
                Font = new Font("Segoe UI", 24, FontStyle.Bold),
                AutoSize = true,
                Location = new Point(28, 24)
            };
            Controls.Add(titleLabel);

            var subtitleLabel = new Label
            {
                Text = "A system-wide voice input launcher for browsers, chat apps, and AI tools.",
                AutoSize = true,
                ForeColor = Color.FromArgb(110, 110, 115),
                Location = new Point(32, 76)
            };
            Controls.Add(subtitleLabel);

            var pathLabel = new Label
            {
                Text = "Install location",
                AutoSize = true,
                Location = new Point(32, 132)
            };
            Controls.Add(pathLabel);

            pathBox = new TextBox
            {
                Location = new Point(32, 156),
                Size = new Size(560, 30),
                ReadOnly = true,
                Text = installDirectory
            };
            Controls.Add(pathBox);

            var featuresPanel = new Panel
            {
                Location = new Point(32, 214),
                Size = new Size(560, 88),
                BackColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle
            };
            Controls.Add(featuresPanel);

            var featuresTitle = new Label
            {
                Text = "This installer will",
                AutoSize = true,
                Font = new Font("Segoe UI", 10, FontStyle.Bold),
                Location = new Point(16, 14)
            };
            featuresPanel.Controls.Add(featuresTitle);

            var featuresBody = new Label
            {
                Text = "• install EchoType.exe into your user profile\r\n• create a desktop shortcut\r\n• create a Start menu shortcut",
                AutoSize = true,
                ForeColor = Color.FromArgb(110, 110, 115),
                Location = new Point(16, 40)
            };
            featuresPanel.Controls.Add(featuresBody);

            installButton = new Button
            {
                Text = "Install",
                Location = new Point(32, 326),
                Size = new Size(140, 42)
            };
            installButton.Click += delegate { RunInstall(); };
            Controls.Add(installButton);

            launchButton = new Button
            {
                Text = "Launch EchoType",
                Location = new Point(188, 326),
                Size = new Size(170, 42),
                Enabled = false
            };
            launchButton.Click += delegate { LaunchInstalledApp(); };
            Controls.Add(launchButton);

            statusLabel = new Label
            {
                Text = "Ready to install.",
                AutoSize = true,
                ForeColor = Color.FromArgb(110, 110, 115),
                Location = new Point(32, 382)
            };
            Controls.Add(statusLabel);
        }

        private void RunInstall()
        {
            try
            {
                installButton.Enabled = false;
                statusLabel.Text = "Installing EchoType...";
                Directory.CreateDirectory(installDirectory);

                WriteResourceToFile("EchoTypeSetup.EchoType.exe", Path.Combine(installDirectory, "EchoType.exe"));
                WriteResourceToFile("EchoTypeSetup.EchoType.ico", Path.Combine(installDirectory, "EchoType.ico"));
                WriteResourceToFile("EchoTypeSetup.README.md", Path.Combine(installDirectory, "README.md"));
                WriteResourceToFile("EchoTypeSetup.Run-EchoType.bat", Path.Combine(installDirectory, "Run-EchoType.bat"));

                CreateShortcut(
                    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "EchoType.lnk"),
                    Path.Combine(installDirectory, "EchoType.exe"),
                    installDirectory,
                    Path.Combine(installDirectory, "EchoType.ico"),
                    "EchoType Desktop"
                );

                var startMenuDir = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.StartMenu),
                    "Programs",
                    "EchoType"
                );
                Directory.CreateDirectory(startMenuDir);
                CreateShortcut(
                    Path.Combine(startMenuDir, "EchoType.lnk"),
                    Path.Combine(installDirectory, "EchoType.exe"),
                    installDirectory,
                    Path.Combine(installDirectory, "EchoType.ico"),
                    "EchoType Desktop"
                );

                launchButton.Enabled = true;
                statusLabel.Text = "Install complete. You can launch EchoType now.";
            }
            catch (Exception ex)
            {
                installButton.Enabled = true;
                MessageBox.Show(ex.Message, "EchoType Setup", MessageBoxButtons.OK, MessageBoxIcon.Error);
                statusLabel.Text = "Install failed.";
            }
        }

        private void LaunchInstalledApp()
        {
            var exePath = Path.Combine(installDirectory, "EchoType.exe");
            if (File.Exists(exePath))
            {
                System.Diagnostics.Process.Start(exePath);
                statusLabel.Text = "EchoType launched.";
            }
        }

        private static void WriteResourceToFile(string resourceName, string outputPath)
        {
            using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(resourceName))
            {
                if (stream == null)
                {
                    throw new InvalidOperationException("Missing resource: " + resourceName);
                }

                using (var file = File.Create(outputPath))
                {
                    stream.CopyTo(file);
                }
            }
        }

        private static void CreateShortcut(string shortcutPath, string targetPath, string workingDirectory, string iconPath, string description)
        {
            var shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
            try
            {
                dynamic shortcut = shell.GetType().InvokeMember(
                    "CreateShortcut",
                    BindingFlags.InvokeMethod,
                    null,
                    shell,
                    new object[] { shortcutPath }
                );

                shortcut.TargetPath = targetPath;
                shortcut.WorkingDirectory = workingDirectory;
                shortcut.IconLocation = iconPath;
                shortcut.Description = description;
                shortcut.Save();
            }
            finally
            {
                if (shell != null)
                {
                    Marshal.FinalReleaseComObject(shell);
                }
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
            Application.Run(new InstallerForm());
        }
    }
}
