using Microsoft.AspNetCore.Mvc;
using RiebeeckstadWeb.Models;
using RiebeeckstadWeb.Services;

namespace RiebeeckstadWeb.Controllers;

/// <summary>Manage Appointments: list, new booking, edit, cancel.</summary>
public class AppointmentsController : StaffController
{
    private const int PageSize = 10;

    public AppointmentsController(SupabaseDataService data, StaffSession session) : base(data, session) { }

    // GET /Appointments?tab=upcoming&q=max&date=2026-10-15&service=vaccination&vet=...&page=2
    public async Task<IActionResult> Index(string? tab, string? q, DateOnly? date, string? service,
        string? vet, int page = 1, CancellationToken ct = default)
    {
        ViewData["Active"] = "Appointments";
        ViewData["Title"] = "Manage Appointments";

        tab = AppointmentListModel.Tabs.Any(t => t.Value == tab) ? tab! : "all";
        var today = Clinic.Today.ToString("yyyy-MM-dd");

        var filters = new List<string>();
        var order = "appointment_date.desc,appointment_time.desc";
        switch (tab)
        {
            case "upcoming":
                filters.Add($"appointment_date=gte.{today}");
                filters.Add("status=in.(Pending,Confirmed,Rescheduled)");
                order = "appointment_date.asc,appointment_time.asc";
                break;
            case "today":
                filters.Add($"appointment_date=eq.{today}");
                order = "appointment_time.asc";
                break;
            case "pending":
                filters.Add("status=eq.Pending");
                order = "appointment_date.asc,appointment_time.asc";
                break;
            case "past":
                filters.Add($"appointment_date=lt.{today}");
                break;
            case "cancelled":
                filters.Add("status=eq.Cancelled");
                break;
        }

        var term = SupabaseDataService.SearchTerm(q);
        if (term.Length > 0) filters.Add($"or=(client_name.ilike.*{term}*,patient_name.ilike.*{term}*,reason.ilike.*{term}*)");
        if (date is { } d) filters.Add($"appointment_date=eq.{d:yyyy-MM-dd}");
        if (Clinic.Services.Any(s => s.Value == service)) filters.Add($"service=eq.{service}");
        else service = null;
        if (Guid.TryParse(vet, out var vetId)) filters.Add($"vet_id=eq.{vetId}");
        else vet = null;

        var token = await TokenAsync(ct);
        var query = "appointment_overview?select=*&order=" + order + string.Concat(filters.Select(f => "&" + f));
        var pageTask = Data.GetPageAsync<AppointmentRow>(query, page, PageSize, token, ct);
        var vetsTask = VetsAsync(token, ct);
        await Task.WhenAll(pageTask, vetsTask);

        var model = new AppointmentListModel
        {
            Tab = tab,
            Search = q,
            Date = date,
            Service = service,
            VetId = vet,
            Rows = pageTask.Result.Rows,
            Vets = vetsTask.Result,
        };
        model.Pager = new Pager
        {
            Page = page,
            PageSize = PageSize,
            Total = pageTask.Result.Total,
            Noun = "appointments",
            UrlFor = p => Url.Action(nameof(Index), new { tab, q, date = date?.ToString("yyyy-MM-dd"), service, vet, page = p })!,
        };
        return View(model);
    }

    // GET /Appointments/Create?clientId=...&petId=...&date=2026-10-20
    public async Task<IActionResult> Create(string? clientId, string? petId, DateOnly? date, string? returnUrl,
        CancellationToken ct = default)
    {
        ViewData["Active"] = "Appointments";
        var model = new AppointmentFormModel
        {
            ClientId = clientId ?? "",
            PetId = petId ?? "",
            Date = date ?? Clinic.Today,
            Status = "Confirmed",
            VetId = Session.IsVet ? Session.UserId : null,
            ReturnUrl = returnUrl,
        };

        // Coming from a pet: fill in its owner
        if (Guid.TryParse(petId, out _) && string.IsNullOrEmpty(clientId))
        {
            var token = await TokenAsync(ct);
            var pet = await Data.GetOneAsync<PetOption>($"pets?select=pet_id,patient_name,species,owner_id&pet_id=eq.{petId}", token, ct);
            model.ClientId = pet?.OwnerId ?? "";
        }

        await FillListsAsync(model, ct);
        return View("Form", model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(AppointmentFormModel model, CancellationToken ct)
    {
        ViewData["Active"] = "Appointments";
        model.Id = null;
        var token = await TokenAsync(ct);

        if (ModelState.IsValid)
        {
            var problem = await CheckBookingAsync(model, token, ct);
            if (problem is null)
            {
                try
                {
                    await Data.InsertAsync<AppointmentRow>("appointments", Values(model), token, ct);
                    TempData["Success"] = "Booking saved.";
                    return BackTo(model.ReturnUrl, () => RedirectToAction(nameof(Index),
                        new { tab = "all", date = model.Date?.ToString("yyyy-MM-dd") }));
                }
                catch (SupabaseException ex)
                {
                    problem = ex.Message;
                }
            }
            ModelState.AddModelError("", problem);
        }

        await FillListsAsync(model, ct);
        return View("Form", model);
    }

    // GET /Appointments/Edit/{id}
    public async Task<IActionResult> Edit(string id, string? returnUrl, CancellationToken ct)
    {
        ViewData["Active"] = "Appointments";
        if (!Guid.TryParse(id, out _)) return NotFound();

        var token = await TokenAsync(ct);
        var row = await Data.GetOneAsync<AppointmentRow>($"appointment_overview?select=*&appointment_id=eq.{id}", token, ct);
        if (row is null) return NotFound();

        var model = new AppointmentFormModel
        {
            Id = row.Id,
            ClientId = row.ClientId ?? "",
            PetId = row.PetId ?? "",
            Service = Clinic.Services.Any(s => s.Value == row.Service) ? row.Service! : "other",
            VetId = row.VetId,
            Date = DateOnly.TryParse(row.Date, out var d) ? d : null,
            Time = row.TimeShort,
            Status = Clinic.Statuses.FirstOrDefault(s => s.Value.Equals(row.Status, StringComparison.OrdinalIgnoreCase))?.Value ?? "Pending",
            Urgent = row.UrgencyKey == "urgent",
            Notes = row.Reason,
            ReturnUrl = returnUrl,
        };

        await FillListsAsync(model, ct);
        return View("Form", model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(string id, AppointmentFormModel model, CancellationToken ct)
    {
        ViewData["Active"] = "Appointments";
        if (!Guid.TryParse(id, out _)) return NotFound();
        model.Id = id;
        var token = await TokenAsync(ct);

        if (ModelState.IsValid)
        {
            var problem = await CheckBookingAsync(model, token, ct);
            if (problem is null)
            {
                try
                {
                    var changed = await Data.UpdateAsync("appointments", $"appointment_id=eq.{id}", Values(model), token, ct);
                    if (changed == 0) return NotFound();
                    TempData["Success"] = "Appointment updated.";
                    return BackTo(model.ReturnUrl, () => RedirectToAction(nameof(Index)));
                }
                catch (SupabaseException ex)
                {
                    problem = ex.Message;
                }
            }
            ModelState.AddModelError("", problem);
        }

        await FillListsAsync(model, ct);
        return View("Form", model);
    }

    // POST /Appointments/Cancel/{id} — appointments are never deleted, so history is kept
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Cancel(string id, string? returnUrl, CancellationToken ct)
    {
        if (!Guid.TryParse(id, out _)) return BadRequest();
        var token = await TokenAsync(ct);
        try
        {
            await Data.UpdateAsync("appointments", $"appointment_id=eq.{id}", new { status = "Cancelled" }, token, ct);
            TempData["Success"] = "Appointment cancelled.";
        }
        catch (SupabaseException ex)
        {
            TempData["Error"] = ex.Message;
        }
        return BackTo(returnUrl, () => RedirectToAction(nameof(Index)));
    }

    // ------------------------------------------------------------------

    private static object Values(AppointmentFormModel m) => new
    {
        owner_id = m.ClientId,
        pet_id = m.PetId,
        appointment_date = m.Date!.Value.ToString("yyyy-MM-dd"),
        appointment_time = TimeOnly.Parse(m.Time).ToString("HH:mm:ss"),
        service = m.Service,
        vet_id = string.IsNullOrEmpty(m.VetId) ? null : m.VetId,
        status = m.Status,
        urgency = m.Urgent ? "urgent" : "routine",
        reason = string.IsNullOrWhiteSpace(m.Notes) ? null : m.Notes.Trim(),
    };

    /// <summary>Checks the pet belongs to the client and the vet isn't already booked at that time.</summary>
    private async Task<string?> CheckBookingAsync(AppointmentFormModel m, string token, CancellationToken ct)
    {
        if (!Guid.TryParse(m.ClientId, out _) || !Guid.TryParse(m.PetId, out _))
            return "Please choose the client and pet again.";
        if (!string.IsNullOrEmpty(m.VetId) && !Guid.TryParse(m.VetId, out _))
            return "Please choose the veterinarian again.";

        var pet = await Data.GetOneAsync<PetOption>(
            $"pets?select=pet_id,patient_name,species,owner_id&pet_id=eq.{m.PetId}", token, ct);
        if (pet is null || pet.OwnerId != m.ClientId)
            return "That pet does not belong to the selected client.";

        if (!string.IsNullOrEmpty(m.VetId) && m.Status is "Pending" or "Confirmed" or "Rescheduled")
        {
            var time = TimeOnly.Parse(m.Time).ToString("HH:mm:ss");
            var filter = $"vet_id=eq.{m.VetId}&appointment_date=eq.{m.Date:yyyy-MM-dd}&appointment_time=eq.{time}" +
                         "&status=in.(Pending,Confirmed,Rescheduled)";
            if (!m.IsNew) filter += $"&appointment_id=neq.{m.Id}";
            if (await Data.CountAsync("appointments", filter, token, ct) > 0)
                return "This veterinarian already has an appointment at that time. Choose another time or vet.";
        }
        return null;
    }

    private async Task FillListsAsync(AppointmentFormModel model, CancellationToken ct)
    {
        var token = await TokenAsync(ct);
        var clientsTask = Data.GetListAsync<ClientRow>("client_overview?select=owner_id,full_name,email&order=full_name.asc", token, ct);
        var petsTask = Data.GetListAsync<PetOption>("pets?select=pet_id,patient_name,species,owner_id&order=patient_name.asc", token, ct);
        var vetsTask = VetsAsync(token, ct);
        await Task.WhenAll(clientsTask, petsTask, vetsTask);

        model.Clients = clientsTask.Result.Select(c => new Option(c.Id, c.Label)).ToList();
        model.Pets = petsTask.Result;
        model.Vets = vetsTask.Result;

        // Keep the current client in the list even if they aren't a "client" any more (e.g. became staff)
        if (!string.IsNullOrEmpty(model.ClientId) && model.Clients.All(c => c.Value != model.ClientId))
        {
            var p = await Data.GetOneAsync<ProfileRow>($"profiles?select=*&owner_id=eq.{SupabaseDataService.Value(model.ClientId)}", token, ct);
            if (p is not null) model.Clients.Insert(0, new Option(p.Id, p.Name));
        }
    }
}