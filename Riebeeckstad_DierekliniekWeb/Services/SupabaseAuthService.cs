using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace RiebeeckstadWeb.Services;

/// <summary>Result of a sign-up attempt.</summary>
public record SignUpResult(bool Success, bool AlreadyRegistered, bool EmailConfirmationRequired, string? Error)
{
    public static SignUpResult Ok(bool confirmationRequired) => new(true, false, confirmationRequired, null);
    public static SignUpResult Exists() => new(false, true, false, "An account with this email already exists.");
    public static SignUpResult Fail(string error) => new(false, false, false, error);
}

/// <summary>Tokens returned by Supabase after logging in or refreshing.</summary>
public record AuthTokens(string AccessToken, string RefreshToken, DateTimeOffset ExpiresAt, string UserId, string Email);

/// <summary>Result of a login or refresh attempt.</summary>
public record SignInResult(AuthTokens? Tokens, string? Error)
{
    public bool Success => Tokens is not null;
}

/// <summary>
/// Calls Supabase Auth's REST API (https://&lt;project&gt;.supabase.co/auth/v1/...).
/// This is the same Supabase project the Flutter app uses, so accounts are shared.
/// </summary>
public class SupabaseAuthService
{
    private readonly HttpClient _http;
    private readonly ILogger<SupabaseAuthService> _logger;

    public SupabaseAuthService(HttpClient http, IOptions<SupabaseSettings> options, ILogger<SupabaseAuthService> logger)
    {
        _http = http;
        _logger = logger;

        var settings = options.Value;
        if (!string.IsNullOrWhiteSpace(settings.Url))
        {
            _http.BaseAddress = new Uri(settings.Url.TrimEnd('/') + "/");
        }
        // Supabase identifies the project from the apikey header.
        _http.DefaultRequestHeaders.Add("apikey", settings.PublishableKey);
        _http.Timeout = TimeSpan.FromSeconds(20);
    }

    // ------------------------------------------------------------------
    // Register
    // ------------------------------------------------------------------

    /// <summary>
    /// Creates a new account. full_name and phone are stored as user metadata; the database
    /// trigger copies them into public.profiles with role = 'client'. Staff roles
    /// (vet / receptionist) are granted afterwards by an administrator.
    /// </summary>
    public async Task<SignUpResult> SignUpAsync(
        string email, string password, string fullName, string phone, CancellationToken ct = default)
    {
        if (_http.BaseAddress is null)
            return SignUpResult.Fail("The server is not connected to Supabase. Please contact the administrator.");

        var body = new
        {
            email,
            password,
            data = new { full_name = fullName, phone }
        };

        try
        {
            var (ok, status, json) = await PostAsync("auth/v1/signup", body, null, ct);

            if (!ok)
            {
                var message = ReadErrorMessage(json) ?? $"Registration failed ({status}).";
                _logger.LogWarning("Supabase sign-up failed: {Status} {Message}", status, message);

                if (message.Contains("already registered", StringComparison.OrdinalIgnoreCase))
                    return SignUpResult.Exists();

                return SignUpResult.Fail(Friendly(message));
            }

            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            // With email confirmation ON, Supabase returns the user object directly.
            // With it OFF, it returns { access_token, ..., user: { ... } }.
            var user = root.TryGetProperty("user", out var u) && u.ValueKind == JsonValueKind.Object ? u : root;

            // Supabase hides "email already used" by returning a user with no identities.
            if (user.TryGetProperty("identities", out var identities)
                && identities.ValueKind == JsonValueKind.Array
                && identities.GetArrayLength() == 0)
            {
                return SignUpResult.Exists();
            }

            var confirmationRequired = !root.TryGetProperty("access_token", out _);
            return SignUpResult.Ok(confirmationRequired);
        }
        catch (TaskCanceledException)
        {
            return SignUpResult.Fail("Supabase took too long to respond. Please try again.");
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Could not reach Supabase");
            return SignUpResult.Fail("Could not connect to the server. Check your internet connection and try again.");
        }
    }

    // ------------------------------------------------------------------
    // Login / refresh / logout / password reset
    // ------------------------------------------------------------------

    /// <summary>Email + password login.</summary>
    public Task<SignInResult> SignInWithPasswordAsync(string email, string password, CancellationToken ct = default)
        => TokenRequestAsync("auth/v1/token?grant_type=password", new { email, password }, ct);

    /// <summary>Gets a new access token using the refresh token (access tokens last about 1 hour).</summary>
    public Task<SignInResult> RefreshAsync(string refreshToken, CancellationToken ct = default)
        => TokenRequestAsync("auth/v1/token?grant_type=refresh_token", new { refresh_token = refreshToken }, ct);

    /// <summary>Ends the session on Supabase's side. Failures are ignored.</summary>
    public async Task SignOutAsync(string accessToken, CancellationToken ct = default)
    {
        if (_http.BaseAddress is null || string.IsNullOrEmpty(accessToken)) return;
        try
        {
            await PostAsync("auth/v1/logout", new { }, accessToken, ct);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
        {
            _logger.LogInformation(ex, "Supabase logout call failed (ignored)");
        }
    }

    /// <summary>Sends a password-reset email. Returns an error message, or null on success.</summary>
    public async Task<string?> SendPasswordResetAsync(string email, CancellationToken ct = default)
    {
        if (_http.BaseAddress is null)
            return "The server is not connected to Supabase. Please contact the administrator.";
        try
        {
            var (ok, status, json) = await PostAsync("auth/v1/recover", new { email }, null, ct);
            return ok ? null : Friendly(ReadErrorMessage(json) ?? $"Could not send the email ({status}).");
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
        {
            _logger.LogError(ex, "Could not reach Supabase");
            return "Could not connect to the server. Check your internet connection and try again.";
        }
    }

    /// <summary>Changes the logged-in user's password. Returns an error message, or null on success.</summary>
    public async Task<string?> UpdatePasswordAsync(string accessToken, string newPassword, CancellationToken ct = default)
    {
        if (_http.BaseAddress is null)
            return "The server is not connected to Supabase. Please contact the administrator.";
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Put, "auth/v1/user")
            {
                Content = new StringContent(JsonSerializer.Serialize(new { password = newPassword }),
                    Encoding.UTF8, "application/json")
            };
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
            using var response = await _http.SendAsync(request, ct);
            var json = await response.Content.ReadAsStringAsync(ct);
            if (response.IsSuccessStatusCode) return null;

            var message = ReadErrorMessage(json) ?? $"Could not change the password ({(int)response.StatusCode}).";
            _logger.LogWarning("Supabase password change failed: {Message}", message);
            if (message.Contains("different from the old", StringComparison.OrdinalIgnoreCase))
                return "The new password must be different from your current password.";
            return Friendly(message);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
        {
            _logger.LogError(ex, "Could not reach Supabase");
            return "Could not connect to the server. Check your internet connection and try again.";
        }
    }

    private async Task<SignInResult> TokenRequestAsync(string path, object body, CancellationToken ct)
    {
        if (_http.BaseAddress is null)
            return new SignInResult(null, "The server is not connected to Supabase. Please contact the administrator.");

        try
        {
            var (ok, status, json) = await PostAsync(path, body, null, ct);
            if (!ok)
            {
                var message = ReadErrorMessage(json) ?? $"Login failed ({status}).";
                _logger.LogWarning("Supabase token request failed: {Status} {Message}", status, message);
                return new SignInResult(null, Friendly(message));
            }

            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            var user = root.GetProperty("user");

            var expiresAt = root.TryGetProperty("expires_at", out var ea) && ea.ValueKind == JsonValueKind.Number
                ? DateTimeOffset.FromUnixTimeSeconds(ea.GetInt64())
                : DateTimeOffset.UtcNow.AddSeconds(root.TryGetProperty("expires_in", out var ei) ? ei.GetInt32() : 3600);

            var tokens = new AuthTokens(
                root.GetProperty("access_token").GetString()!,
                root.GetProperty("refresh_token").GetString()!,
                expiresAt,
                user.GetProperty("id").GetString()!,
                user.TryGetProperty("email", out var em) ? em.GetString() ?? "" : "");

            return new SignInResult(tokens, null);
        }
        catch (TaskCanceledException)
        {
            return new SignInResult(null, "Supabase took too long to respond. Please try again.");
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Could not reach Supabase");
            return new SignInResult(null, "Could not connect to the server. Check your internet connection and try again.");
        }
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    private async Task<(bool ok, int status, string json)> PostAsync(
        string path, object body, string? bearer, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, path)
        {
            Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json")
        };
        if (bearer is not null)
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearer);

        using var response = await _http.SendAsync(request, ct);
        var json = await response.Content.ReadAsStringAsync(ct);
        return (response.IsSuccessStatusCode, (int)response.StatusCode, json);
    }

    private static string? ReadErrorMessage(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            foreach (var key in new[] { "msg", "error_description", "message", "error" })
            {
                if (doc.RootElement.TryGetProperty(key, out var value) && value.ValueKind == JsonValueKind.String)
                    return value.GetString();
            }
        }
        catch (JsonException)
        {
            // Not JSON — fall through.
        }
        return null;
    }

    private static string Friendly(string message)
    {
        if (message.Contains("Invalid API key", StringComparison.OrdinalIgnoreCase) ||
            message.Contains("No API key", StringComparison.OrdinalIgnoreCase))
            return "The server's Supabase key is missing or wrong. Please contact the administrator.";
        if (message.Contains("Invalid login credentials", StringComparison.OrdinalIgnoreCase))
            return "Incorrect email or password.";
        if (message.Contains("Email not confirmed", StringComparison.OrdinalIgnoreCase))
            return "Please confirm your email first. Check your inbox for the link.";
        if (message.Contains("rate limit", StringComparison.OrdinalIgnoreCase))
            return "Too many attempts. Please wait a minute and try again.";
        return message;
    }
}