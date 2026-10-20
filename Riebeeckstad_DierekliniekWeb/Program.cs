using Microsoft.AspNetCore.Authentication.Cookies;
using RiebeeckstadWeb.Services;

var builder = WebApplication.CreateBuilder(args);

// MVC (controllers + Razor views)
builder.Services.AddControllersWithViews();

// Supabase settings come from appsettings.json + user-secrets (the key is never committed).
builder.Services.Configure<SupabaseSettings>(builder.Configuration.GetSection("Supabase"));

// Supabase Auth (register / login) and database (REST) clients.
builder.Services.AddHttpClient<SupabaseAuthService>();
builder.Services.AddHttpClient<SupabaseDataService>();
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<StaffSession>();

// Staff stay logged in with an encrypted cookie that also holds their Supabase tokens.
builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.LogoutPath = "/Account/Logout";
        options.AccessDeniedPath = "/Account/Login";
        options.Cookie.Name = "rdk.staff";
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.ExpireTimeSpan = TimeSpan.FromHours(8);
        options.SlidingExpiration = true;
    });
builder.Services.AddAuthorization();

var app = builder.Build();

var supabase = builder.Configuration.GetSection("Supabase").Get<SupabaseSettings>();
if (string.IsNullOrWhiteSpace(supabase?.Url) || string.IsNullOrWhiteSpace(supabase?.PublishableKey))
{
    app.Logger.LogWarning(
        "Supabase is not configured. Run: dotnet user-secrets set \"Supabase:PublishableKey\" \"<your publishable key>\"");
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
}

app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();