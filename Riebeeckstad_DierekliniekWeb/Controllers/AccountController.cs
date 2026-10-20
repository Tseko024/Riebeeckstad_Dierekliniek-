using System.Security.Claims;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using RiebeeckstadWeb.Models;
using RiebeeckstadWeb.Services;

namespace RiebeeckstadWeb.Controllers;

public class AccountController : Controller
{
    /// <summary>Roles allowed into the staff web app (from public.profiles.role).</summary>
    public static readonly string[] StaffRoles = { "vet", "receptionist" };

    private readonly SupabaseAuthService _auth;
    private readonly SupabaseDataService _data;
    private readonly StaffSession _session;

    public AccountController(SupabaseAuthService auth, SupabaseDataService data, StaffSession session)
    {
        _auth = auth;
        _data = data;
        _session = session;
    }

    // ==================================================================
    // Register
    // ==================================================================

    [HttpGet]
    public IActionResult Register() => View(new RegisterViewModel());

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Register(RegisterViewModel model, CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return View(model);

        // Store phone numbers without spaces/dashes, e.g. 0712345678
        var phone = Regex.Replace(model.Phone, @"[\s\-()]", "");

        var result = await _auth.SignUpAsync(
            model.Email.Trim(), model.Password, model.FullName.Trim(), phone, ct);

        if (result.AlreadyRegistered)
        {
            ModelState.AddModelError(nameof(RegisterViewModel.Email),
                "An account with this email already exists. Please log in instead.");
            return View(model);
        }

        if (!result.Success)
        {
            ModelState.AddModelError(string.Empty, result.Error ?? "Registration failed. Please try again.");
            return View(model);
        }

        TempData["Success"] = result.EmailConfirmationRequired
            ? $"Account created. We sent a confirmation link to {model.Email.Trim()}. " +
              "Once confirmed, a clinic administrator must activate your staff access before you can log in."
            : "Account created. A clinic administrator must activate your staff access before you can log in.";

        return RedirectToAction(nameof(Login));
    }

    // ==================================================================
    // Login
    // ==================================================================

    [HttpGet]
    public IActionResult Login(string? returnUrl = null)
    {
        if (User.Identity?.IsAuthenticated == true)
            return RedirectToAction("Index", "Dashboard");

        return View(new LoginViewModel { ReturnUrl = returnUrl });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Login(LoginViewModel model, CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return View(model);

        // 1. Check email + password with Supabase Auth
        var signIn = await _auth.SignInWithPasswordAsync(model.Email.Trim(), model.Password, ct);
        if (!signIn.Success)
        {
            ModelState.AddModelError(string.Empty, signIn.Error ?? "Login failed. Please try again.");
            return View(model);
        }
        var tokens = signIn.Tokens!;

        // 2. Read their profile (as them — RLS lets everyone read their own profile)
        ProfileRow? profile;
        try
        {
            var rows = await _data.GetListAsync<ProfileRow>(
                $"profiles?select=full_name,role&owner_id=eq.{tokens.UserId}", tokens.AccessToken, ct);
            profile = rows.FirstOrDefault();
        }
        catch (Exception ex) when (ex is SupabaseException or SessionExpiredException or HttpRequestException)
        {
            ModelState.AddModelError(string.Empty, "Logged in, but your profile could not be loaded. Please try again.");
            return View(model);
        }

        // 3. Only vets and receptionists may use the staff web app
        var role = (profile?.Role ?? "client").Trim().ToLowerInvariant();
        if (!StaffRoles.Contains(role))
        {
            await _auth.SignOutAsync(tokens.AccessToken, ct);
            ModelState.AddModelError(string.Empty,
                "Your account does not have staff access yet. Please ask a clinic administrator to activate it. " +
                "Pet owners should use the mobile app.");
            return View(model);
        }

        // 4. Create the login cookie (claims + Supabase tokens)
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, tokens.UserId),
            new(ClaimTypes.Name, string.IsNullOrWhiteSpace(profile?.FullName) ? tokens.Email : profile!.FullName!.Trim()),
            new(ClaimTypes.Email, tokens.Email),
            new(ClaimTypes.Role, role),
        };
        var principal = new ClaimsPrincipal(new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme));

        var properties = new AuthenticationProperties
        {
            IsPersistent = model.RememberMe,                       // keep cookie after the browser closes
            ExpiresUtc = model.RememberMe ? DateTimeOffset.UtcNow.AddDays(7) : null,
        };
        StaffSession.StoreTokens(properties, tokens);

        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal, properties);

        if (!string.IsNullOrEmpty(model.ReturnUrl) && Url.IsLocalUrl(model.ReturnUrl))
            return LocalRedirect(model.ReturnUrl);

        return RedirectToAction("Index", "Dashboard");
    }

    // ==================================================================
    // Logout
    // ==================================================================

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Logout(CancellationToken ct)
    {
        try
        {
            var token = await _session.GetAccessTokenAsync(ct);
            await _auth.SignOutAsync(token, ct);
        }
        catch (SessionExpiredException)
        {
            // Already expired — nothing to revoke.
        }

        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        TempData["Success"] = "You have been logged out.";
        return RedirectToAction(nameof(Login));
    }

    // ==================================================================
    // Forgot password
    // ==================================================================

    [HttpGet]
    public IActionResult ForgotPassword(string? email = null)
        => View(new ForgotPasswordViewModel { Email = email ?? "" });

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordViewModel model, CancellationToken ct)
    {
        if (!ModelState.IsValid)
            return View(model);

        var error = await _auth.SendPasswordResetAsync(model.Email.Trim(), ct);
        if (error is not null)
        {
            ModelState.AddModelError(string.Empty, error);
            return View(model);
        }

        // Same message whether or not the email exists, so accounts can't be guessed.
        TempData["Success"] = $"If an account exists for {model.Email.Trim()}, a password reset link has been sent.";
        return RedirectToAction(nameof(Login));
    }

    private sealed class ProfileRow
    {
        [JsonPropertyName("full_name")] public string? FullName { get; set; }
        [JsonPropertyName("role")] public string? Role { get; set; }
    }
}