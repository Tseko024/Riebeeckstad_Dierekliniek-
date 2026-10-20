using System.ComponentModel.DataAnnotations;

namespace RiebeeckstadWeb.Models;

/// <summary>Manage Appointments page.</summary>
public class AppointmentListModel
{
    public string Tab { get; set; } = "all";          // all | upcoming | today | pending | past | cancelled
    public string? Search { get; set; }
    public DateOnly? Date { get; set; }
    public string? Service { get; set; }
    public string? VetId { get; set; }

    public List<AppointmentRow> Rows { get; set; } = new();
    public Pager Pager { get; set; } = new();
    public List<StaffMember> Vets { get; set; } = new();

    public bool HasFilters => !string.IsNullOrEmpty(Search) || Date is not null
                              || !string.IsNullOrEmpty(Service) || !string.IsNullOrEmpty(VetId);

    public static readonly Option[] Tabs =
    {
        new("all", "All Appointments"),
        new("upcoming", "Upcoming"),
        new("today", "Today"),
        new("pending", "Pending"),
        new("past", "Past"),
        new("cancelled", "Cancelled"),
    };
}

/// <summary>New Booking / Edit Appointment form.</summary>
public class AppointmentFormModel : IValidatableObject
{
    public string? Id { get; set; }                   // null = new booking
    public string? ReturnUrl { get; set; }

    [Required(ErrorMessage = "Please choose the client")]
    [Display(Name = "Client Name")]
    public string ClientId { get; set; } = "";

    [Required(ErrorMessage = "Please choose the pet")]
    [Display(Name = "Pet Name")]
    public string PetId { get; set; } = "";

    [Required(ErrorMessage = "Please choose a service")]
    [Display(Name = "Service Type")]
    public string Service { get; set; } = "general_checkup";

    [Display(Name = "Veterinarian")]
    public string? VetId { get; set; }

    [Required(ErrorMessage = "Please choose a date")]
    [DataType(DataType.Date)]
    public DateOnly? Date { get; set; }

    [Required(ErrorMessage = "Please choose a time")]
    public string Time { get; set; } = "";

    [Required]
    public string Status { get; set; } = "Pending";

    [Display(Name = "Urgent")]
    public bool Urgent { get; set; }

    [StringLength(500, ErrorMessage = "Notes can be at most 500 characters")]
    [Display(Name = "Notes / symptoms")]
    public string? Notes { get; set; }

    // Drop-down data
    public List<Option> Clients { get; set; } = new();
    public List<PetOption> Pets { get; set; } = new();
    public List<StaffMember> Vets { get; set; } = new();

    public bool IsNew => string.IsNullOrEmpty(Id);

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (Date is { } day)
        {
            var last = Clinic.LastSlot(day);
            if (last is null)
                yield return new ValidationResult("The clinic is closed on Sundays.", new[] { nameof(Date) });
            else if (TimeOnly.TryParse(Time, out var t) && (t < new TimeOnly(8, 0) || t > last))
                yield return new ValidationResult(
                    $"Choose a time between 08:00 and {last:HH\\:mm} on {day:dddd}s.", new[] { nameof(Time) });

            // New bookings can't be in the past (editing old ones is allowed, e.g. to mark Completed).
            if (IsNew && Status is "Pending" or "Confirmed" or "Rescheduled"
                && (day < Clinic.Today || (day == Clinic.Today && TimeOnly.TryParse(Time, out var t2) && t2 < Clinic.Now)))
                yield return new ValidationResult("This date and time has already passed.", new[] { nameof(Date) });
        }

        if (!string.IsNullOrEmpty(Time) && !TimeOnly.TryParse(Time, out _))
            yield return new ValidationResult("Please choose a valid time.", new[] { nameof(Time) });

        if (Clinic.Statuses.All(s => s.Value != Status))
            yield return new ValidationResult("Please choose a valid status.", new[] { nameof(Status) });

        if (Clinic.Services.All(s => s.Value != Service))
            yield return new ValidationResult("Please choose a valid service.", new[] { nameof(Service) });
    }
}

/// <summary>Pet in a drop-down (filtered by the chosen client in the browser).</summary>
public class PetOption
{
    [System.Text.Json.Serialization.JsonPropertyName("pet_id")] public string Id { get; set; } = "";
    [System.Text.Json.Serialization.JsonPropertyName("patient_name")] public string? Name { get; set; }
    [System.Text.Json.Serialization.JsonPropertyName("species")] public string? Species { get; set; }
    [System.Text.Json.Serialization.JsonPropertyName("owner_id")] public string? OwnerId { get; set; }

    public string Text => string.IsNullOrEmpty(Species) ? (Name ?? "Pet") : $"{Name} ({Clinic.SpeciesText(Species)})";
}