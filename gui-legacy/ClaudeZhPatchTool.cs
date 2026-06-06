using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Win32;

public sealed class MainForm : Form
{
    private readonly TextBox pathBox = new TextBox();
    private readonly Button browseButton = new Button();
    private readonly Button autoButton = new Button();
    private readonly Button runButton = new Button();
    private readonly ProgressBar progress = new ProgressBar();
    private readonly TextBox logBox = new TextBox();
    private readonly Label statusLabel = new Label();

    public MainForm()
    {
        Text = "Claude 桌面版汉化修复工具";
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(760, 520);
        Size = new Size(860, 600);
        Font = new Font("Microsoft YaHei UI", 9F);

        var title = new Label { Text = "Claude 桌面版汉化修复工具", Font = new Font(Font.FontFamily, 16F, FontStyle.Bold), AutoSize = true, Location = new Point(24, 22) };
        var subtitle = new Label { Text = "自动定位 Claude 安装目录，部署汉化文件，修补常见英文/生硬表述，并清理缓存。", AutoSize = true, ForeColor = Color.DimGray, Location = new Point(27, 60) };
        var pathLabel = new Label { Text = "Claude resources 路径（可留空自动定位）", AutoSize = true, Location = new Point(28, 102) };

        pathBox.Location = new Point(28, 126);
        pathBox.Width = 610;
        pathBox.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;

        browseButton.Text = "浏览…";
        browseButton.Location = new Point(650, 124);
        browseButton.Width = 82;
        browseButton.Anchor = AnchorStyles.Top | AnchorStyles.Right;
        browseButton.Click += delegate { BrowsePath(); };

        autoButton.Text = "自动定位";
        autoButton.Location = new Point(740, 124);
        autoButton.Width = 82;
        autoButton.Anchor = AnchorStyles.Top | AnchorStyles.Right;
        autoButton.Click += delegate { AutoLocate(false); };

        runButton.Text = "开始修复";
        runButton.Location = new Point(28, 170);
        runButton.Size = new Size(120, 36);
        runButton.Click += async delegate { await RunPatchAsync(); };

        progress.Location = new Point(160, 178);
        progress.Width = 470;
        progress.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        progress.Style = ProgressBarStyle.Continuous;

        statusLabel.Text = "就绪";
        statusLabel.AutoSize = true;
        statusLabel.Location = new Point(650, 183);
        statusLabel.Anchor = AnchorStyles.Top | AnchorStyles.Right;

        logBox.Location = new Point(28, 226);
        logBox.Size = new Size(794, 300);
        logBox.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
        logBox.Multiline = true;
        logBox.ScrollBars = ScrollBars.Vertical;
        logBox.ReadOnly = true;
        logBox.Font = new Font("Consolas", 9F);

        Controls.AddRange(new Control[] { title, subtitle, pathLabel, pathBox, browseButton, autoButton, runButton, progress, statusLabel, logBox });
        Shown += delegate { AutoLocate(true); };
    }

    private void BrowsePath()
    {
        using (var dialog = new FolderBrowserDialog())
        {
            dialog.Description = "请选择 Claude 的 app\\resources 目录，或 Claude 安装目录";
            dialog.ShowNewFolderButton = false;
            if (dialog.ShowDialog(this) == DialogResult.OK) pathBox.Text = dialog.SelectedPath;
        }
    }

    private void AutoLocate(bool silent)
    {
        var found = FindClaudeResources();
        if (!string.IsNullOrWhiteSpace(found))
        {
            pathBox.Text = found;
            Log("已自动定位：" + found);
        }
        else if (!silent)
        {
            MessageBox.Show(this, "没有自动找到 Claude。你可以点击“浏览…”手动选择 Claude 的 app\\resources 目录。", "未找到 Claude", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }

    private async Task RunPatchAsync()
    {
        string baseDir;
        string script;
        try
        {
            baseDir = PrepareEmbeddedPatchPackage();
            script = Path.Combine(baseDir, "Fix-Claude-Desktop-ZhCN.ps1");
        }
        catch (Exception ex)
        {
            MessageBox.Show(this, ex.Message, "资源释放失败", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        runButton.Enabled = false;
        browseButton.Enabled = false;
        autoButton.Enabled = false;
        progress.Value = 5;
        statusLabel.Text = "正在修复…";
        logBox.Clear();
        Log("启动修复流程…");

        var args = new StringBuilder();
        args.Append("-NoProfile -ExecutionPolicy Bypass -File ");
        args.Append(Quote(script));
        if (!string.IsNullOrWhiteSpace(pathBox.Text))
        {
            args.Append(" -ClaudePath ");
            args.Append(Quote(pathBox.Text.Trim()));
        }

        var result = await Task.Run(delegate { return RunProcess(baseDir, args.ToString()); });
        if (result == 0)
        {
            SetProgress(100, "完成");
            Log("修复完成。请重新打开 Claude Desktop。");
            MessageBox.Show(this, "修复完成。请重新打开 Claude Desktop。", "完成", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
        else
        {
            SetProgress(100, "失败");
            Log("修复失败，退出码：" + result);
            MessageBox.Show(this, "修复失败，请查看日志。", "失败", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }

        runButton.Enabled = true;
        browseButton.Enabled = true;
        autoButton.Enabled = true;
    }

    private int RunProcess(string workingDirectory, string arguments)
    {
        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = arguments,
            WorkingDirectory = workingDirectory,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        using (var process = Process.Start(psi))
        {
            if (process == null) return 1;
            while (!process.StandardOutput.EndOfStream) OnLine(process.StandardOutput.ReadLine() ?? "");
            string err = process.StandardError.ReadToEnd();
            if (!string.IsNullOrWhiteSpace(err)) OnLine(err);
            process.WaitForExit();
            return process.ExitCode;
        }
    }

    private void OnLine(string line)
    {
        if (IsDisposed) return;
        BeginInvoke((Action)delegate
        {
            Log(line);
            if (line.Contains("Locating")) SetProgress(12, "定位中");
            else if (line.Contains("Creating backup")) SetProgress(25, "备份中");
            else if (line.Contains("Ensuring bundled")) SetProgress(40, "部署语言包");
            else if (line.Contains("Patching zh-CN")) SetProgress(55, "修补文案");
            else if (line.Contains("Patching frontend")) SetProgress(72, "修补界面逻辑");
            else if (line.Contains("Clearing Claude cache")) SetProgress(88, "清理缓存");
            else if (line.Contains("Done")) SetProgress(100, "完成");
        });
    }

    private void SetProgress(int value, string status)
    {
        progress.Value = Math.Max(0, Math.Min(100, value));
        statusLabel.Text = status;
    }

    private void Log(string text)
    {
        logBox.AppendText("[" + DateTime.Now.ToString("HH:mm:ss") + "] " + text + Environment.NewLine);
    }

    private static string PrepareEmbeddedPatchPackage()
    {
        var dir = Path.Combine(Path.GetTempPath(), "claude-zh-cn-gui-package");
        Directory.CreateDirectory(dir);
        ExtractResource("Fix-Claude-Desktop-ZhCN.ps1", Path.Combine(dir, "Fix-Claude-Desktop-ZhCN.ps1"));
        ExtractResource("zh-CN.json", Path.Combine(dir, "zh-CN.json"));
        ExtractResource("frontend-zh-CN.json", Path.Combine(dir, "frontend-zh-CN.json"));
        return dir;
    }

    private static void ExtractResource(string logicalName, string targetPath)
    {
        var assembly = Assembly.GetExecutingAssembly();
        var resourceName = assembly.GetManifestResourceNames().FirstOrDefault(name => name.EndsWith(logicalName, StringComparison.OrdinalIgnoreCase));
        if (resourceName == null) throw new FileNotFoundException("内置资源缺失：" + logicalName);
        using (var source = assembly.GetManifestResourceStream(resourceName))
        {
            if (source == null) throw new FileNotFoundException("无法读取内置资源：" + logicalName);
            using (var target = File.Create(targetPath)) source.CopyTo(target);
        }
    }

    private static string Quote(string value) { return "\"" + value.Replace("\"", "\\\"") + "\""; }

    private static string FindClaudeResources()
    {
        var candidates = new List<string>();
        using (var key = Registry.CurrentUser.OpenSubKey(@"Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages"))
        {
            if (key != null)
            {
                foreach (var name in key.GetSubKeyNames())
                {
                    if (name.StartsWith("Claude_", StringComparison.OrdinalIgnoreCase) && name.IndexOf("pzs8sxrjxfjjc", StringComparison.OrdinalIgnoreCase) >= 0)
                        candidates.Add(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "WindowsApps", name, "app", "resources"));
                }
            }
        }

        var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        candidates.Add(Path.Combine(local, "Programs", "Claude", "resources"));
        candidates.Add(Path.Combine(local, "Programs", "Claude", "app", "resources"));
        candidates.Add(Path.Combine(local, "Claude", "resources"));
        candidates.Add(Path.Combine(programFiles, "Claude", "resources"));
        candidates.Add(Path.Combine(programFiles, "Claude", "app", "resources"));

        return candidates.Distinct().FirstOrDefault(IsResourcesPath);
    }

    private static bool IsResourcesPath(string path)
    {
        return Directory.Exists(path) && Directory.Exists(Path.Combine(path, "ion-dist")) && Directory.Exists(Path.Combine(path, "ion-dist", "assets"));
    }
}

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        if (!IsAdministrator())
        {
            try
            {
                var exePath = Assembly.GetExecutingAssembly().Location;
                var psi = new ProcessStartInfo
                {
                    FileName = exePath,
                    UseShellExecute = true,
                    Verb = "runas"
                };
                Process.Start(psi);
            }
            catch (Exception ex)
            {
                MessageBox.Show("需要管理员权限才能写入 Claude 安装目录。\r\n\r\n" + ex.Message, "需要管理员权限", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
            return;
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new MainForm());
    }

    private static bool IsAdministrator()
    {
        using (var identity = WindowsIdentity.GetCurrent())
        {
            var principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }
    }
}
