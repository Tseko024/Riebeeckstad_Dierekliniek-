using System.Globalization;
using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;

namespace RiebeeckstadWeb.Services;

/// <summary>
/// Gives controllers the logged-in staff member's Supabase access token,
/// refreshing it automatically when it is about to expire.
/// The tokens are stored inside the encrypted login cookie.
/// </summary>
public class StaffSession
{
    public const string AccessTokenName = "access_token";
    public const string RefreshTokenName = "refresh_token";
    public const string ExpiresAtName = "expires_at";

    private readonly IHttpContextAccessor _accessor;
    private readonly SupabaseAuthService _auth;

    public StaffSession(IHttpContextAccessor accessor, SupabaseAuthService auth)
    {
        _accessor = accessor;
        _auth = auth;
    }

    private HttpContext Context => _accessor.HttpContext
        ?? throw new InvalidOperationException("No HTTP request in progress.");

    public string UserId => Context.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "";
    public string FullName => Context.User.FindFirstValue(ClaimTypes.Name) ?? "";
    public string Role => Context.User.FindFirstValue(ClaimTypes.Role) ?? "";
    public bool IsVet => Role == "vet";

    /// <summary>Saves Supabase tokens into the authentication properties (used at login and refresh).</summary>
    public static void StoreTokens(AuthenticationProperties properties, AuthTokens tokens)
    {
        properties.StoreTokens(new[]
        {
            new AuthenticationToken { Name = AccessTokenName, Value = tokens.AccessToken },
            new AuthenticationToken { Name = RefreshTokenName, Value = tokens.RefreshToken },
            new AuthenticationToken { Name = ExpiresAtName, Value = tokens.ExpiresAt.ToString("o", CultureInfo.InvariantCulture) },
        });
    }

    /// <summary>Returns a valid access token, refreshing it first if it expires within a minute.</summary>
    public async Task<string> GetAccessTokenAsync(CancellationToken ct = default)
    {
        var result = await Context.AuthenticateAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        if (!result.Succeeded || result.Properties is null)
            throw new SessionExpiredException();

        var props = result.Properties;
        var accessToken = props.GetTokenValue(AccessTokenName);
        var refreshToken = props.GetTokenValue(RefreshTokenName);
        var expiresAtText = props.GetTokenValue(ExpiresAtName);

        if (string.IsNullOrEmpty(accessToken) || string.IsNullOrEmpty(refreshToken))
            throw new SessionExpiredException();

        var expiresAt = DateTimeOffset.TryParse(expiresAtText, CultureInfo.InvariantCulture,
            DateTimeStyles.RoundtripKind, out var parsed) ? parsed : DateTimeOffset.MinValue;

        if (expiresAt > DateTimeOffset.UtcNow.AddMinutes(1))
            return accessToken;

        // Expired or about to expire → refresh and save the new tokens in the cookie.
        var refreshed = await _auth.RefreshAsync(refreshToken, ct);
        if (!refreshed.Success)
            throw new SessionExpiredException();

        StoreTokens(props, refreshed.Tokens!);
        await Context.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, result.Principal!, props);
        return refreshed.Tokens!.AccessToken;
    }
}