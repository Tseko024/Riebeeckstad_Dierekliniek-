using Microsoft.AspNetCore.Mvc;
using RiebeeckstadWeb.Models;
using RiebeeckstadWeb.Services;

namespace RiebeeckstadWeb.Controllers;

/// <summary>Pet History: everything that happened to one pet (appointments + treatment records).</summary>
public class HistoryController : StaffController
{
    private const int PageSize = 12;

    public HistoryController(SupabaseDataService data, StaffSession session) : base(data, session) { }

    // GET /History                → choose a pet
    // GET /History?petId=...&tab=vaccinations
    public async Task<IActionResult> Index(string? petId, string? tab, string? q, int page = 1, CancellationToken ct = default)
    {
        ViewData["Active"] = "History";
        ViewData["Title"] = "Pet History";
        var token = await TokenAsync(ct);

        if (!Guid.TryParse(petId, out _))
        {
            var query = "pet_overview?select=*&order=patient_name.asc";
            var term = SupabaseDataService.SearchTerm(q);
            if (term.Length > 0)
                query += $"&or=(patient_name.ilike.*{term}*,owner_name.ilike.*{term}*,breed.ilike.*{term}*,microchip.ilike.*{term}*)";
            var result = await Data.GetPageAsync<PetRow>(query, page, PageSize, token, ct);
            return View("Picker", new PetPickerModel
            {
                Search = q,
                Pets = result.Rows,
                Pager = new Pager
                {
                    Page = page,
                    PageSize = PageSize,
                    Total = result.Total,
                    Noun = "pets",
                    UrlFor = p => Url.Action(nameof(Index), new { q, page = p })!,
                },
            });
        }

        var petTask = Data.GetOneAsync<PetRow>($"pet_overview?select=*&pet_id=eq.{petId}", token, ct);
        var apptTask = Data.GetListAsync<AppointmentRow>(
            $"appointment_overview?select=*&pet_id=eq.{petId}&order=appointment_date.desc,appointment_time.desc", token, ct);
        var recordTask = Data.GetListAsync<TreatmentRow>(
            $"treatment_overview?select=*&pet_id=eq.{petId}&order=visit_date.desc,history_id.desc", token, ct);
        await Task.WhenAll(petTask, apptTask, recordTask);
        if (petTask.Result is null) return NotFound();

        tab = PetHistoryModel.Tabs.Any(t => t.Value == tab) ? tab! : "overview";
        var here = Url.Action(nameof(Index), new { petId, tab });

        var appointments = apptTask.Result.Select(a => new HistoryEntry
        {
            Date = DateOnly.TryParse(a.Date, out var d) ? d : default,
            Type = "Appointment",
            Details = a.ServiceText + (string.IsNullOrWhiteSpace(a.Reason) ? "" : $" — {a.Reason}"),
            Vet = a.VetName,
            Status = a.StatusText,
            StatusKey = a.StatusKey,
            Notes = a.Reason,
            IsAppointment = true,
            EditUrl = Url.Action("Edit", "Appointments", new { id = a.Id, returnUrl = here }),
        }).ToList();

        var records = recordTask.Result.Select(r => new HistoryEntry
        {
            Date = DateOnly.TryParse(r.VisitDate, out var d) ? d : default,
            Type = r.TypeText,
            Details = r.Treatment ?? r.Diagnosis ?? "—",
            Diagnosis = r.Diagnosis,
            Medications = r.Medications,
            Notes = r.Notes,
            Vet = r.VetName,
            EditUrl = Session.IsVet ? Url.Action("Edit", "Treatments", new { id = r.Id, returnUrl = here }) : null,
        }).ToList();

        var entries = tab switch
        {
            "appointments" => appointments,
            "treatments" => records.Where(r => r.Type != "Vaccination").ToList(),
            "vaccinations" => records.Where(r => r.Type == "Vaccination").ToList(),
            "medications" => records.Where(r => !string.IsNullOrWhiteSpace(r.Medications)).ToList(),
            "notes" => appointments.Concat(records).Where(e => !string.IsNullOrWhiteSpace(e.Notes)).ToList(),
            _ => appointments.Concat(records).ToList(),
        };

        // Current medication = medications on the newest record from the last 90 days
        var current = recordTask.Result
            .Where(r => !string.IsNullOrWhiteSpace(r.Medications)
                        && DateOnly.TryParse(r.VisitDate, out var d) && d >= Clinic.Today.AddDays(-90))
            .Select(r => r.Medications!)
            .FirstOrDefault();

        ViewData["Title"] = $"{petTask.Result.Name} — Pet History";
        return View("Pet", new PetHistoryModel
        {
            Pet = petTask.Result,
            Tab = tab,
            Entries = entries.OrderByDescending(e => e.Date).ToList(),
            CurrentMedication = current ?? "None",
            AppointmentCount = appointments.Count,
            RecordCount = records.Count,
            CanWrite = Session.IsVet,
        });
    }
}