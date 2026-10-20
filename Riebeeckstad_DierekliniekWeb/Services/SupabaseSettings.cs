namespace RiebeeckstadWeb.Services;

/// <summary>Values from the "Supabase" section of appsettings.json / user-secrets.</summary>
public class SupabaseSettings
{
    /// <summary>e.g. https://qgzrolkkggcmfxoycadj.supabase.co (no /rest/v1 on the end)</summary>
    public string Url { get; set; } = "";

    /// <summary>The publishable (anon) key — never the secret/service_role key.</summary>
    public string PublishableKey { get; set; } = "";
}