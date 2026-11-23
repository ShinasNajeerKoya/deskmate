using Microsoft.Win32;

namespace DeskmateHub;

/// <summary>"Open at login" via the current user's Run key (no admin rights needed).</summary>
static class LoginItem
{
    const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    const string Name = "DeskmateHub";
    const string SetupKey = @"Software\Deskmate\Hub";

    public static bool IsEnabled
    {
        get
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKey);
            return key?.GetValue(Name) is string;
        }
    }

    public static void Set(bool on)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKey);
        if (on) key.SetValue(Name, $"\"{Environment.ProcessPath}\"");
        else key.DeleteValue(Name, throwOnMissingValue: false);
    }

    /// <summary>Turn it on once, the first time the app runs.</summary>
    public static void EnableOnFirstLaunch()
    {
        using var key = Registry.CurrentUser.CreateSubKey(SetupKey);
        if (key.GetValue("LoginItemSetUp") is not null) return;
        key.SetValue("LoginItemSetUp", 1);
        Set(true);
    }
}
