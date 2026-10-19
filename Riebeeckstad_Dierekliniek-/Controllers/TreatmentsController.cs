using Microsoft.AspNetCore.Mvc;
using RiebeeckstadWeb.Models;
using RiebeeckstadWeb.Services;

namespace RiebeeckstadWeb.Controllers;

/// <summary>Treatment Records (medical_history). Everyone on staff can read; only vets add or edit.</summary>
public class TreatmentsController : StaffController
{
    private const int PageSize = 10;

    public TreatmentsController(SupabaseDataService data, StaffSession session) : base(data, session) { }

    // GET /Treatments?q=vaccine&date=2026-09-18&type=Vaccination&page=2
    public async Task<IActionResult> Index(string? q, DateOnly? date, string? type, int page = 1, CancellationToken ct = default)
    {
        ViewData["Active"] = "Treatments";
        ViewData["Title"] = "Treatment Records";

        var query = "treatment_overview?select=*&order=visit_date.desc,history_id.desc";
        var term = SupabaseDataService.SearchTerm(q);
        if (term.Length > 0)
            query += $"&or=(patient_name.ilike.*{term}*,owner_name.ilike.*{term}*,treatment.ilike.*{term}*," +
                     $"diagnosis.ilike.*{term}*,medications.ilike.*{term}*,vet_name.ilike.*{term}*)";
        if (date is { } d) query += $"&visit_date=eq.{d:yyyy-MM-dd}";
        if (Clinic.RecordTypes.Any(t => t.Value == type)) query += $"&record_type=eq.{SupabaseDataService.Value(type)}";
        else type = null;

        var token = await TokenAsync(ct);
        var result = await Data.GetPageAsync<TreatmentRow>(query, page, PageSize, token, ct);

        return View(new TreatmentListModel
        {
            Search = q,
            Date = date,
            Type = type,
            CanWrite = Session.IsVet,
            Rows = result.Rows,
            Pager = new Pager
            {
                Page = page,
                PageSize = PageSize,
                Total = result.Total,
                Noun = "records",
                UrlFor = p => Url.Action(nameof(Index), new { q, date = date?.ToString("yyyy-MM-dd"), type, page = p })!,
            },
        });
    }

    // GET /Treatments/Create?petId=...
    public async Task<IActionResult> Create(string? petId, string? returnUrl, CancellationToken ct)
    {
        ViewData["Active"] = "Treatments";
        if (!Session.IsVet) return VetsOnly();

        var model = new TreatmentFormModel { PetId = petId ?? "", VisitDate = Clinic.Today, ReturnUrl = returnUrl };
        await FillPetsAsync(model, ct);
        return View("Form", model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(TreatmentFormModel model, CancellationToken ct)
    {
        ViewData["Active"] = "Treatments";
        if (!Session.IsVet) return VetsOnly();
        model.Id = null;
        Validate(model);

        if (ModelState.IsValid)
        {
            var token = await TokenAsync(ct);
            try
            {
                await Data.InsertAsync<TreatmentRow>("medical_history", Values(model, newRecord: true), token, ct);
                TempData["Success"] = "Treatment record saved.";
                return BackTo(model.ReturnUrl, () => RedirectToAction(nameof(Index)));
            }
            catch (SupabaseException ex)
            {
                ModelState.AddModelError("", ex.Message);
            }
        }
        await FillPetsAsync(model, ct);
        return View("Form", model);
    }

    // GET /Treatments/Edit/5
    public async Task<IActionResult> Edit(long id, string? returnUrl, CancellationToken ct)
    {
        ViewData["Active"] = "Treatments";
        if (!Session.IsVet) return VetsOnly();

        var token = await TokenAsync(ct);
        var row = await Data.GetOneAsync<TreatmentRow>($"treatment_overview?select=*&history_id=eq.{id}", token, ct);
        if (row is null) return NotFound();

        var model = new TreatmentFormModel
        {
            Id = row.Id,
            PetId = row.PetId ?? "",
            VisitDate = DateOnly.TryParse(row.VisitDate, out var d) ? d : null,
            RecordType = Clinic.RecordTypes.Any(t => t.Value == row.RecordType) ? row.RecordType! : "Other",
            Diagnosis = row.Diagnosis,
            Treatment = row.Treatment ?? "",
            Medications = row.Medications,
            Notes = row.Notes,
            ReturnUrl = returnUrl,
        };
        await FillPetsAsync(model, ct);
        return View("Form", model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(long id, TreatmentFormModel model, CancellationToken ct)
    {
        ViewData["Active"] = "Treatments";
        if (!Session.IsVet) return VetsOnly();
        model.Id = id;
        Validate(model);

        if (ModelState.IsValid)
        {
            var token = await TokenAsync(ct);
            try
            {
                var changed = await Data.UpdateAsync("medical_history", $"history_id=eq.{id}", Values(model, newRecord: false), token, ct);
                if (changed == 0) return NotFound();
                TempData["Success"] = "Treatment record updated.";
                return BackTo(model.ReturnUrl, () => RedirectToAction(nameof(Index)));
            }
            catch (SupabaseException ex)
            {
                ModelState.AddModelError("", ex.Message);
            }
        }
        await FillPetsAsync(model, ct);
        return View("Form", model);
    }

    // ------------------------------------------------------------------

    private IActionResult VetsOnly()
    {
        TempData["Error"] = "Only veterinarians can add or edit treatment records.";
        return RedirectToAction(nameof(Index));
    }

    private void Validate(TreatmentFormModel model)
    {
        if (Clinic.RecordTypes.All(t => t.Value != model.RecordType))
            ModelState.AddModelError(nameof(model.RecordType), "Please choose a record type");
        if (!Guid.TryParse(model.PetId, out _))
            ModelState.AddModelError(nameof(model.PetId), "Please choose the pet");
        if (model.VisitDate > Clinic.Today)
            ModelState.AddModelError(nameof(model.VisitDate), "The visit date can't be in the future");
    }

    private static string? Clean(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();

    /// <summary>Columns to save. A new record is signed by the logged-in vet; edits keep the original vet.</summary>
    private Dictionary<string, object?> Values(TreatmentFormModel m, bool newRecord)
    {
        var values = new Dictionary<string, object?>
        {
            ["pet_id"] = m.PetId,
            ["visit_date"] = m.VisitDate!.Value.ToString("yyyy-MM-dd"),
            ["record_type"] = m.RecordType,
            ["diagnosis"] = Clean(m.Diagnosis),
            ["treatment"] = m.Treatment.Trim(),
            ["medications"] = Clean(m.Medications),
            ["notes"] = Clean(m.Notes),
        };
        if (newRecord) values["veterinarian_id"] = Session.UserId;
        return values;
    }

    private async Task FillPetsAsync(TreatmentFormModel model, CancellationToken ct)
    {
        var token = await TokenAsync(ct);
        var pets = await Data.GetListAsync<PetRow>(
            "pet_overview?select=pet_id,patient_name,species,owner_name&order=patient_name.asc", token, ct);
        model.Pets = pets.Select(p => new Option(p.Id,
            $"{p.Name} ({p.SpeciesText}) — {p.OwnerName ?? "no owner"}")).ToList();
    }
}