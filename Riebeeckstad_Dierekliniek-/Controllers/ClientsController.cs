using Microsoft.AspNetCore.Mvc;
using RiebeeckstadWeb.Models;
using RiebeeckstadWeb.Services;

namespace RiebeeckstadWeb.Controllers;

/// <summary>Clients/Pets: list, add client, edit client, client details, add/edit/delete pet.</summary>
public class ClientsController : StaffController
{
    private const int PageSize = 10;
    private readonly SupabaseAuthService _auth;

    public ClientsController(SupabaseDataService data, StaffSession session, SupabaseAuthService auth)
        : base(data, session)
    {
        _auth = auth;
    }

    // GET /Clients?tab=pets&q=max&species=dog&page=2
    public async Task<IActionResult> Index(string? tab, string? q, string? species, int page = 1, CancellationToken ct = default)
    {
        ViewData["Active"] = "Clients";
        ViewData["Title"] = "Clients/Pets";
        tab = tab == "pets" ? "pets" : "clients";
        var token = await TokenAsync(ct);
        var term = SupabaseDataService.SearchTerm(q);
        var model = new ClientListModel { Tab = tab, Search = q };

        if (tab == "clients")
        {
            var query = "client_overview?select=*&order=full_name.asc";
            if (term.Length > 0)
                query += $"&or=(full_name.ilike.*{term}*,email.ilike.*{term}*,phone.ilike.*{term}*,pet_names.ilike.*{term}*)";
            var result = await Data.GetPageAsync<ClientRow>(query, page, PageSize, token, ct);
            model.Clients = result.Rows;
            model.Pager = MakePager(page, result.Total, "clients", p => Url.Action(nameof(Index), new { tab, q, page = p })!);
        }
        else
        {
            var query = "pet_overview?select=*&order=patient_name.asc";
            if (term.Length > 0)
                query += $"&or=(patient_name.ilike.*{term}*,breed.ilike.*{term}*,owner_name.ilike.*{term}*,microchip.ilike.*{term}*)";
            if (Clinic.Species.Any(s => s.Value == species)) { query += $"&species=eq.{species}"; model.Species = species; }
            var result = await Data.GetPageAsync<PetRow>(query, page, PageSize, token, ct);
            model.Pets = result.Rows;
            model.Pager = MakePager(page, result.Total, "pets",
                p => Url.Action(nameof(Index), new { tab, q, species = model.Species, page = p })!);
        }
        return View(model);
    }

    // GET /Clients/Details/{id}
    public async Task<IActionResult> Details(string id, CancellationToken ct)
    {
        ViewData["Active"] = "Clients";
        if (!Guid.TryParse(id, out _)) return NotFound();
        var token = await TokenAsync(ct);

        var clientTask = Data.GetOneAsync<ProfileRow>($"profiles?select=*&owner_id=eq.{id}", token, ct);
        var petsTask = Data.GetListAsync<PetRow>($"pet_overview?select=*&owner_id=eq.{id}&order=patient_name.asc", token, ct);
        var apptTask = Data.GetListAsync<AppointmentRow>(
            $"appointment_overview?select=*&client_id=eq.{id}&order=appointment_date.desc,appointment_time.desc&limit=20", token, ct);
        await Task.WhenAll(clientTask, petsTask, apptTask);
        if (clientTask.Result is null) return NotFound();

        ViewData["Title"] = clientTask.Result.Name;
        return View(new ClientDetailsModel
        {
            Client = clientTask.Result,
            Pets = petsTask.Result,
            Appointments = apptTask.Result,
        });
    }

    // GET /Clients/Create
    public IActionResult Create()
    {
        ViewData["Active"] = "Clients";
        return View(new ClientCreateModel { PetSpecies = "dog" });
    }

    // POST /Clients/Create — creates the client's login (same as registering in the mobile app)
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(ClientCreateModel model, CancellationToken ct)
    {
        ViewData["Active"] = "Clients";
        if (!string.IsNullOrWhiteSpace(model.PetName) && Clinic.Species.All(s => s.Value != model.PetSpecies))
            ModelState.AddModelError(nameof(model.PetSpecies), "Please choose the species");
        if (!ModelState.IsValid) return View(model);

        var email = model.Email.Trim().ToLowerInvariant();
        var signUp = await _auth.SignUpAsync(email, model.TempPassword, model.FullName.Trim(), model.Phone.Trim(), ct);
        if (signUp.AlreadyRegistered)
        {
            ModelState.AddModelError(nameof(model.Email), "A client with this email already exists. Search for them on the Clients list.");
            return View(model);
        }
        if (!signUp.Success)
        {
            ModelState.AddModelError("", signUp.Error ?? "Could not create the client.");
            return View(model);
        }

        // The database trigger creates the profile; find it to get the new client's id.
        var token = await TokenAsync(ct);
        var profile = await Data.GetOneAsync<ProfileRow>(
            $"profiles?select=*&email=eq.{SupabaseDataService.Value(email)}", token, ct);
        if (profile is null)
        {
            TempData["Error"] = "The account was created, but its profile wasn't found. Check the rdk_on_auth_user_created trigger in Supabase.";
            return RedirectToAction(nameof(Index));
        }

        var message = signUp.EmailConfirmationRequired
            ? $"Client added. {model.FullName} must confirm their email ({email}) before logging in to the mobile app with the temporary password."
            : $"Client added. {model.FullName} can log in to the mobile app with the temporary password.";

        if (!string.IsNullOrWhiteSpace(model.PetName))
        {
            try
            {
                await Data.InsertAsync<PetRow>("pets", new
                {
                    owner_id = profile.Id,
                    patient_name = model.PetName.Trim(),
                    species = model.PetSpecies,
                    breed = Clean(model.PetBreed),
                    age = model.PetAge,
                }, token, ct);
                message += $" {model.PetName.Trim()} was added as their pet.";
            }
            catch (SupabaseException ex)
            {
                TempData["Error"] = "The client was added, but the pet could not be saved: " + ex.Message;
            }
        }

        TempData["Success"] = message;
        return RedirectToAction(nameof(Details), new { id = profile.Id });
    }

    // GET /Clients/Edit/{id}
    public async Task<IActionResult> Edit(string id, CancellationToken ct)
    {
        ViewData["Active"] = "Clients";
        if (!Guid.TryParse(id, out _)) return NotFound();
        var token = await TokenAsync(ct);
        var p = await Data.GetOneAsync<ProfileRow>($"profiles?select=*&owner_id=eq.{id}", token, ct);
        if (p is null) return NotFound();
        return View(new ClientEditModel { Id = p.Id, Email = p.Email, FullName = p.FullName ?? "", Phone = p.Phone ?? "" });
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(string id, ClientEditModel model, CancellationToken ct)
    {
        ViewData["Active"] = "Clients";
        if (!Guid.TryParse(id, out _)) return NotFound();
        model.Id = id;
        if (!ModelState.IsValid) return View(model);

        var token = await TokenAsync(ct);
        try
        {
            var changed = await Data.UpdateAsync("profiles", $"owner_id=eq.{id}",
                new { full_name = model.FullName.Trim(), phone = model.Phone.Trim() }, token, ct);
            if (changed == 0) return NotFound();
            TempData["Success"] = "Client details saved.";
            return RedirectToAction(nameof(Details), new { id });
        }
        catch (SupabaseException ex)
        {
            ModelState.AddModelError("", ex.Message);
            return View(model);
        }
    }

    // GET /Clients/AddPet?clientId=...
    public async Task<IActionResult> AddPet(string? clientId, string? returnUrl, CancellationToken ct)
    {
        ViewData["Active"] = "Clients";
        var model = new PetFormModel { OwnerId = clientId ?? "", ReturnUrl = returnUrl };
        await FillOwnersAsync(model, ct);
        return View("PetForm", model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AddPet(PetFormModel model, CancellationToken ct)
    {
        ViewData["Active"] = "Clients";
        model.Id = null;
        ValidatePet(model);
        if (ModelState.IsValid)
        {
            var token = await TokenAsync(ct);
            try
            {
                var pet = await Data.InsertAsync<PetRow>("pets", PetValues(model), token, ct);
                TempData["Success"] = $"{model.Name.Trim()} was added.";
                return BackTo(model.ReturnUrl, () => RedirectToAction("Index", "History", new { petId = pet.Id }));
            }
            catch (SupabaseException ex)
            {
                ModelState.AddModelError("", ex.Message);
            }
        }
        await FillOwnersAsync(model, ct);
        return View("PetForm", model);
    }

    // GET /Clients/EditPet/{id}
    public async Task<IActionResult> EditPet(string id, string? returnUrl, CancellationToken ct)
    {
        ViewData["Active"] = "Clients";
        if (!Guid.TryParse(id, out _)) return NotFound();
        var token = await TokenAsync(ct);
        var pet = await Data.GetOneAsync<PetRow>($"pet_overview?select=*&pet_id=eq.{id}", token, ct);
        if (pet is null) return NotFound();

        var model = new PetFormModel
        {
            Id = pet.Id,
            OwnerId = pet.OwnerId ?? "",
            Name = pet.Name ?? "",
            Species = Clinic.Species.Any(s => s.Value == pet.Species) ? pet.Species! : "other",
            Breed = pet.Breed,
            Age = pet.Age,
            Microchip = pet.Microchip,
            BloodType = pet.BloodType,
            Allergies = pet.Allergies,
            ChronicConditions = pet.ChronicConditions,
            ReturnUrl = returnUrl,
        };
        await FillOwnersAsync(model, ct);
        return View("PetForm", model);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> EditPet(string id, PetFormModel model, CancellationToken ct)
    {
        ViewData["Active"] = "Clients";
        if (!Guid.TryParse(id, out _)) return NotFound();
        model.Id = id;
        ValidatePet(model);
        if (ModelState.IsValid)
        {
            var token = await TokenAsync(ct);
            try
            {
                var changed = await Data.UpdateAsync("pets", $"pet_id=eq.{id}", PetValues(model), token, ct);
                if (changed == 0) return NotFound();
                TempData["Success"] = $"{model.Name.Trim()}'s details were saved.";
                return BackTo(model.ReturnUrl, () => RedirectToAction("Index", "History", new { petId = id }));
            }
            catch (SupabaseException ex)
            {
                ModelState.AddModelError("", ex.Message);
            }
        }
        await FillOwnersAsync(model, ct);
        return View("PetForm", model);
    }

    // POST /Clients/DeletePet/{id} — only pets without appointments or medical records
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeletePet(string id, string? returnUrl, CancellationToken ct)
    {
        if (!Guid.TryParse(id, out _)) return BadRequest();
        var token = await TokenAsync(ct);

        var apptTask = Data.CountAsync("appointments", $"pet_id=eq.{id}", token, ct);
        var historyTask = Data.CountAsync("medical_history", $"pet_id=eq.{id}", token, ct);
        await Task.WhenAll(apptTask, historyTask);

        if (apptTask.Result + historyTask.Result > 0)
        {
            TempData["Error"] = "This pet has appointments or medical records, so it can't be deleted. Its history must be kept.";
        }
        else
        {
            try
            {
                var removed = await Data.DeleteAsync("pets", $"pet_id=eq.{id}", token, ct);
                TempData[removed > 0 ? "Success" : "Error"] = removed > 0 ? "Pet deleted." : "The pet was not found.";
            }
            catch (SupabaseException ex)
            {
                TempData["Error"] = ex.Message;
            }
        }
        return BackTo(returnUrl, () => RedirectToAction(nameof(Index), new { tab = "pets" }));
    }

    // ------------------------------------------------------------------

    private static string? Clean(string? s) => string.IsNullOrWhiteSpace(s) ? null : s.Trim();

    private static object PetValues(PetFormModel m) => new
    {
        owner_id = m.OwnerId,
        patient_name = m.Name.Trim(),
        species = m.Species,
        breed = Clean(m.Breed),
        age = m.Age,
        microchip = Clean(m.Microchip),
        blood_type = Clean(m.BloodType),
        allergies = Clean(m.Allergies),
        chronic_conditions = Clean(m.ChronicConditions),
    };

    private void ValidatePet(PetFormModel model)
    {
        if (Clinic.Species.All(s => s.Value != model.Species))
            ModelState.AddModelError(nameof(model.Species), "Please choose the species");
        if (!Guid.TryParse(model.OwnerId, out _))
            ModelState.AddModelError(nameof(model.OwnerId), "Please choose the owner");
    }

    private async Task FillOwnersAsync(PetFormModel model, CancellationToken ct)
    {
        var token = await TokenAsync(ct);
        var clients = await Data.GetListAsync<ClientRow>("client_overview?select=owner_id,full_name,email&order=full_name.asc", token, ct);
        model.Owners = clients.Select(c => new Option(c.Id, c.Label)).ToList();
    }

    private static Pager MakePager(int page, int total, string noun, Func<int, string> url) =>
        new() { Page = page, PageSize = PageSize, Total = total, Noun = noun, UrlFor = url };
}