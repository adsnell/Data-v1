using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

[assembly: AssemblyTitle("Data")]
[assembly: AssemblyDescription("Data - XMP metadata editor")]
[assembly: AssemblyProduct("Data")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

public static class Program
{
    [STAThread]
    public static int Main()
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string app = Path.Combine(Path.Combine(dir, "src"), "App.ps1");
        if (!File.Exists(app))
        {
            MessageBox.Show("Cannot find:\n" + app, "Data", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
        StringBuilder err = new StringBuilder();
        string failure = null;
        try
        {
            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = "powershell.exe";
            psi.Arguments = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + app + "\"";
            psi.WorkingDirectory = dir;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.RedirectStandardError = true;
            using (Process p = Process.Start(psi))
            {
                p.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e)
                {
                    if (e.Data != null) { lock (err) { err.AppendLine(e.Data); } }
                };
                p.BeginErrorReadLine();
                p.WaitForExit();
                if (p.ExitCode != 0) { failure = "Data stopped with an error (exit code " + p.ExitCode + ")"; }
            }
        }
        catch (Exception ex)
        {
            failure = "Could not start PowerShell:\n" + ex.Message;
        }
        if (failure == null) { return 0; }

        string detail;
        lock (err) { detail = err.ToString().Trim(); }
        string note = "";
        try
        {
            string logs = Path.Combine(dir, "logs");
            Directory.CreateDirectory(logs);
            File.AppendAllText(Path.Combine(logs, "launch.log"),
                DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "  " + failure + "\r\n" + detail + "\r\n\r\n");
            note = "\n\n(Also saved to logs\\launch.log)";
        }
        catch { }
        if (detail.Length > 1200) { detail = detail.Substring(0, 1200) + "..."; }
        string msg = failure + (detail.Length > 0 ? ":\n\n" + detail : "") + note;
        MessageBox.Show(msg, "Data", MessageBoxButtons.OK, MessageBoxIcon.Error);
        return 1;
    }
}