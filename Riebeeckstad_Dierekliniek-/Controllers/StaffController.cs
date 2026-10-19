using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using RiebeeckstadWeb.Models;
using RiebeeckstadWeb.Services;

namespace RiebeeckstadWeb.Controllers;

/// <summary>
/// Base class for every staff page. Only vets and receptionists can open them.
/// Handles an expired session (back to Login) and connection problems in one place.
/// </summary>
[Authorize(Roles = "vet,receptionist")]
public abstract class StaffController : Controller
{
    protected readonly SupabaseDataService Data;
    protected readonly StaffSession Session;

    protected StaffController(SupabaseDataService data, StaffSession session)
    {
        Data = data;
        Session = session;
    }

    /// <summary>The logged-in staff member's Supabase access token (refreshed when needed).</summary>
    protected Task<string> TokenAsync(CancellationToken ct) => Session.GetAccessTokenAsync(ct);

    /// <summary>Vets and receptionists who can be chosen on forms.</summary>
    protected Task<List<StaffMember>> VetsAsync(string token, CancellationToken ct) =>
        Data.GetListAsync<StaffMember>("staff_directory?select=*&role=eq.vet&order=full_name.asc", token, ct);

    /// <summary>Only redirect to local URLs (stops "open redirect" tricks).</summary>
    protected IActionResult BackTo(string? returnUrl, Func<IActionResult> fallback) =>
        !string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl) ? Redirect(returnUrl) : fallback();

    public override async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var executed = await next();
        if (executed.Exception is null || executed.ExceptionHandled) return;

        switch (executed.Exception)
        {
            case SessionExpiredException:
                await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
                TempData["Error"] = "Your session has expired. Please log in again.";
                executed.Result = RedirectToAction("Login", "Account",
                    new { returnUrl = Request.Method == "GET" ? Request.Path + Request.QueryString : null });
                executed.ExceptionHandled = true;
                break;

            case SupabaseException ex:
                executed.Result = LoadError(ex.Message);
                executed.ExceptionHandled = true;
                break;

            case HttpRequestException or TaskCanceledException:
                executed.Result = LoadError("Could not connect to the server. Check your internet connection and try again.");
                executed.ExceptionHandled = true;
                break;
        }
    }

    private ViewResult LoadError(string message)
    {
        ViewData["Title"] ??= "Something went wrong";
        var view = View("~/Views/Shared/_LoadError.cshtml", message);
        view.ViewData["Active"] = ViewData["Active"];
        return view;
    }
}