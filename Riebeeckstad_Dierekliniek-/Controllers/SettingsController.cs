using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using RiebeeckstadWeb.Models;
using RiebeeckstadWeb.Services;

namespace RiebeeckstadWeb.Controllers;

/// <summary>Settings: my profile, change password, staff access (vets only).</summary>
public class SettingsController : StaffController
{
    private readonly SupabaseAuthService _auth;

    public SettingsController(SupabaseDataService data, StaffSession session, SupabaseAuthService auth)
        : base(data, session)
    {
        _auth = auth;
    }

    // GET /Settings
    public async Task<IActionResult> Index(CancellationToken ct)
    {
        var model = await LoadAsync(ct);
        return Page(model);
    }

    // POST /Settings/Profile
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Profile([Bind(Prefix = "Profile")] ProfileFormModel form, CancellationToken ct)
    {
        var model = await LoadAsync(ct);
        model.Section = "profile";
        form.Email = model.Profile.Email;
        model.Profile = form;
        if (!ModelState.IsValid) return Page(model);

        var token = await TokenAsync(ct);
        try
        {
            await Data.UpdateAsync("profiles", $"owner_id=eq.{Session.UserId}",
                new { full_name = form.FullName.Trim(), phone = string.IsNullOrWhiteSpace(form.Phone) ? null : form.Phone.Trim() },
                token, ct);
            await UpdateNameClaimAsync(form.FullName.Trim());
            TempData["Success"] = "Your profile was saved.";
            return RedirectToAction(nameof(Index));
        }
        catch (SupabaseException ex)
        {
            ModelState.AddModelError("", ex.Message);
            return Page(model);
        }
    }

    // POST /Settings/Password
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Password([Bind(Prefix = "Password")] PasswordFormModel form, CancellationToken ct)
    {
        var model = await LoadAsync(ct);
        model.Section = "password";
        if (!ModelState.IsValid) return Page(model);

        // Check the current password first
        var email = User.FindFirstValue(ClaimTypes.Email) ?? "";
        var check = await _auth.SignInWithPasswordAsync(email, form.CurrentPassword, ct);
        if (!check.Success)
        {
            ModelState.AddModelError("Password.CurrentPassword",
                check.Error == "Incorrect email or password." ? "Your current password is incorrect." : check.Error!);
            return Page(model);
        }

        var error = await _auth.UpdatePasswordAsync(await TokenAsync(ct), form.NewPassword, ct);
        if (error is not null)
        {
            ModelState.AddModelError("Password.NewPassword", error);
            return Page(model);
        }

        TempData["Success"] = "Your password was changed. Use the new password next time you log in (web and mobile app).";
        return RedirectToAction(nameof(Index));
    }

    // POST /Settings/Access — vets give or remove staff access
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Access([Bind(Prefix = "Access")] StaffAccessFormModel form, CancellationToken ct)
    {
        if (!Session.IsVet)
        {
            TempData["Error"] = "Only veterinarians can change staff access.";
            return RedirectToAction(nameof(Index));
        }

        var model = await LoadAsync(ct);
        model.Section = "access";
        model.Access = form;
        if (StaffAccessFormModel.Roles.All(r => r.Value != form.Role))
            ModelState.AddModelError("Access.Role", "Please choose a role");
        if (!ModelState.IsValid) return Page(model);

        var token = await TokenAsync(ct);
        var email = form.Email.Trim().ToLowerInvariant();
        var person = await Data.GetOneAsync<ProfileRow>($"profiles?select=*&email=eq.{SupabaseDataService.Value(email)}", token, ct);

        if (person is null)
            ModelState.AddModelError("Access.Email", "No account uses this email. The person must register first (web or mobile app).");
        else if (person.Id == Session.UserId)
            ModelState.AddModelError("Access.Email", "You can't change your own access.");
        if (!ModelState.IsValid) return Page(model);

        try
        {
            await Data.UpdateAsync("profiles", $"owner_id=eq.{person!.Id}", new { role = form.Role }, token, ct);
            TempData["Success"] = $"{person.Name} is now: {StaffAccessFormModel.Roles.First(r => r.Value == form.Role).Text}.";
            return RedirectToAction(nameof(Index), null, "access");
        }
        catch (SupabaseException ex)
        {
            ModelState.AddModelError("", ex.Message);
            return Page(model);
        }
    }

    // ------------------------------------------------------------------

    private ViewResult Page(SettingsModel model)
    {
        ViewData["Active"] = "Settings";
        ViewData["Title"] = "Settings";
        return View("Index", model);
    }

    private async Task<SettingsModel> LoadAsync(CancellationToken ct)
    {
        var token = await TokenAsync(ct);
        var meTask = Data.GetOneAsync<ProfileRow>($"profiles?select=*&owner_id=eq.{Session.UserId}", token, ct);
        var staffTask = Data.GetListAsync<ProfileRow>("profiles?select=*&role=in.(vet,receptionist,Vet,Receptionist)&order=full_name.asc", token, ct);
        await Task.WhenAll(meTask, staffTask);

        var me = meTask.Result;
        return new SettingsModel
        {
            Profile = new ProfileFormModel { Email = me?.Email, FullName = me?.FullName ?? "", Phone = me?.Phone },
            Staff = staffTask.Result,
            IsVet = Session.IsVet,
            CurrentUserId = Session.UserId,
        };
    }

    /// <summary>Updates the name shown in the header without logging out.</summary>
    private async Task UpdateNameClaimAsync(string name)
    {
        var result = await HttpContext.AuthenticateAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        if (!result.Succeeded || result.Principal?.Identity is not ClaimsIdentity identity) return;

        var old = identity.FindFirst(ClaimTypes.Name);
        if (old is not null) identity.RemoveClaim(old);
        identity.AddClaim(new Claim(ClaimTypes.Name, name));
        await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, result.Principal, result.Properties);
    }
}