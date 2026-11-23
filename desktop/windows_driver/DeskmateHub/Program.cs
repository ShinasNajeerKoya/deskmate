namespace DeskmateHub;

static class Program
{
    [STAThread]
    static void Main()
    {
        // One Hub per user session.
        using var mutex = new Mutex(true, @"Local\DeskmateHub", out var first);
        if (!first) return;

        ApplicationConfiguration.Initialize();
        Application.Run(new TrayApp());
    }
}
