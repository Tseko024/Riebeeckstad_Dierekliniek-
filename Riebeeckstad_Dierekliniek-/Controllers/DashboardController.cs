using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using RiebeeckstadWeb.Models;
using RiebeeckstadWeb.Services;

namespace RiebeeckstadWeb.Controllers;

/// <summary>Admin / Vet dashboard. Only vets and receptionists can open it (see StaffController).</summary>
public class DashboardController : StaffController
{
    private readonly SupabaseDataService _data;
    private readonly StaffSession _session;

    public DashboardController(SupabaseDataService data, StaffSession session) : base(data, session)
    {
        _data = data;
        _session = session;
    }

    private static DateOnly ClinicToday => Clinic.Today;

    // GET /Dashboard?date=2026-10-13
    public async Task<IActionResult> Index(DateOnly? date, CancellationToken ct)
    {
        ViewData["Active"] = "Dashboard";
        var today = ClinicToday;
        var day = date ?? today;

        var model = new DashboardViewModel
        {
            Greeting = Greeting(),
            SelectedDate = day,
            Today = today,
        };

        try
        {
            var token = await _session.GetAccessTokenAsync(ct);
            var dayText = day.ToString("yyyy-MM-dd");
            var todayText = today.ToString("yyyy-MM-dd");

            // Run all queries at the same time
            var dayTask = _data.GetListAsync<AppointmentRow>(
                $"appointment_overview?select=*&appointment_date=eq.{dayText}&order=appointment_time.asc", token, ct);
            var todayCountTask = _data.CountAsync(
                "appointments", $"appointment_date=eq.{todayText}&status=not.ilike.cancelled", token, ct);
            var clientsTask = _data.CountAsync("profiles", "role=ilike.client", token, ct);
            var petsTask = _data.CountAsync("pets", "", token, ct);
            var pendingTask = _data.CountAsync("appointments", "status=ilike.pending", token, ct);
            var urgentTask = _data.GetListAsync<AppointmentRow>(
                "appointment_overview?select=*&urgency=eq.urgent&status=in.(Pending,Confirmed,Rescheduled)" +
                $"&appointment_date=gte.{todayText}&order=appointment_date.asc,appointment_time.asc&limit=5", token, ct);
            var recentTask = _data.GetListAsync<RecentRow>(
                "appointments?select=appointment_id,created_at,status&order=created_at.desc&limit=6", token, ct);

            await Task.WhenAll(dayTask, todayCountTask, clientsTask, petsTask, pendingTask, urgentTask, recentTask);

            model.DayAppointments = dayTask.Result;
            model.AppointmentsToday = todayCountTask.Result;
            model.TotalClients = clientsTask.Result;
            model.TotalPets = petsTask.Result;
            model.PendingBookings = pendingTask.Result;
            model.UrgentUpcoming = urgentTask.Result;
            model.RecentActivity = await BuildActivityAsync(recentTask.Result, token, ct);
        }
        catch (SessionExpiredException)
        {
            return await ExpiredAsync();
        }
        catch (SupabaseException ex)
        {
            model.Error = ex.Message;
        }
        catch (HttpRequestException)
        {
            model.Error = "Could not connect to the server. Check your internet connection and refresh.";
        }

        return View(model);
    }

    // POST /Dashboard/UpdateStatus — Confirm / Complete / Cancel buttons
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> UpdateStatus(string id, string status, DateOnly? date, CancellationToken ct)
    {
        // Values must match the group's appointments_status_check constraint.
        var allowed = new[] { "Confirmed", "Completed", "Cancelled" };
        if (!Guid.TryParse(id, out _) || !allowed.Contains(status))
            return BadRequest();

        try
        {
            var token = await _session.GetAccessTokenAsync(ct);
            await _data.UpdateAsync("appointments", $"appointment_id=eq.{id}", new { status }, token, ct);

            // A vet who confirms an unassigned booking becomes its vet.
            if (status == "Confirmed" && _session.IsVet)
            {
                await _data.UpdateAsync("appointments", $"appointment_id=eq.{id}&vet_id=is.null",
                    new { vet_id = _session.UserId }, token, ct);
            }

            TempData["Success"] = status switch
            {
                "Confirmed" => "Appointment confirmed.",
                "Completed" => "Appointment marked as completed.",
                _ => "Appointment cancelled.",
            };
        }
        catch (SessionExpiredException)
        {
            return await ExpiredAsync();
        }
        catch (SupabaseException ex)
        {
            TempData["Error"] = ex.Message;
        }

        return RedirectToAction(nameof(Index), new { date = date?.ToString("yyyy-MM-dd") });
    }

    // Old links (/Dashboard/Appointments etc.) now go to the real pages
    public IActionResult Appointments() => RedirectToAction("Index", "Appointments");
    public IActionResult Clients() => RedirectToAction("Index", "Clients");
    public IActionResult Treatments() => RedirectToAction("Index", "Treatments");
    public IActionResult History() => RedirectToAction("Index", "History");
    public IActionResult Messages() => RedirectToAction("Index", "Messages");
    public IActionResult Settings() => RedirectToAction("Index", "Settings");

    // ------------------------------------------------------------------

    private string Greeting()
    {
        var name = _session.FullName.Trim();
        if (_session.IsVet)
        {
            if (name.StartsWith("Dr", StringComparison.OrdinalIgnoreCase)) return name;
            var parts = name.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            return "Dr. " + (parts.Length > 1 ? string.Join(' ', parts.Skip(1)) : name);
        }
        return name.Split(' ', StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? name;
    }

    private async Task<List<ActivityItem>> BuildActivityAsync(List<RecentRow> recent, string token, CancellationToken ct)
    {
        if (recent.Count == 0) return new();

        var ids = string.Join(',', recent.Select(r => r.Id));
        var details = await _data.GetListAsync<AppointmentRow>(
            $"appointment_overview?select=*&appointment_id=in.({ids})", token, ct);
        var byId = details.ToDictionary(d => d.Id);

        return recent.Select(r =>
        {
            byId.TryGetValue(r.Id, out var a);
            var who = a?.ClientName is { Length: > 0 } c ? c : "A client";
            var pet = a?.PetName ?? "their pet";
            var what = a is null ? "an appointment" : $"{a.ServiceText.ToLowerInvariant()} for {pet} on {a.DateDisplay} at {a.TimeShort}";
            return new ActivityItem
            {
                When = r.CreatedAt,
                Text = $"{who} booked {what}",
                StatusKey = (r.Status ?? "pending").ToLowerInvariant(),
                StatusText = Labels.Status(r.Status),
            };
        }).ToList();
    }

    private async Task<IActionResult> ExpiredAsync()
    {
        await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        TempData["Error"] = "Your session has expired. Please log in again.";
        return RedirectToAction("Login", "Account");
    }
}