using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace RiebeeckstadWeb.Models;

/// <summary>Row of the treatment_overview view (medical_history + pet + owner + vet).</summary>
public class TreatmentRow
{
    [JsonPropertyName("history_id")] public long Id { get; set; }
    [JsonPropertyName("pet_id")] public string? PetId { get; set; }
    [JsonPropertyName("visit_date")] public string? VisitDate { get; set; }
    [JsonPropertyName("record_type")] public string? RecordType { get; set; }
    [JsonPropertyName("diagnosis")] public string? Diagnosis { get; set; }
    [JsonPropertyName("treatment")] public string? Treatment { get; set; }
    [JsonPropertyName("medications")] public string? Medications { get; set; }
    [JsonPropertyName("notes")] public string? Notes { get; set; }
    [JsonPropertyName("veterinarian_id")] public string? VetId { get; set; }
    [JsonPropertyName("vet_name")] public string? VetName { get; set; }
    [JsonPropertyName("patient_name")] public string? PetName { get; set; }
    [JsonPropertyName("species")] public string? Species { get; set; }
    [JsonPropertyName("owner_id")] public string? OwnerId { get; set; }
    [JsonPropertyName("owner_name")] public string? OwnerName { get; set; }

    public string DateDisplay => DateOnly.TryParse(VisitDate, out var d) ? d.ToString("d MMM yyyy") : VisitDate ?? "";
    public string TypeText => Clinic.RecordTypes.FirstOrDefault(t => t.Value == RecordType)?.Text ?? RecordType ?? "Treatment";
    public string PetLabel => string.IsNullOrEmpty(Species) ? PetName ?? "—" : $"{PetName} ({Clinic.SpeciesText(Species)})";
}

/// <summary>Treatment Records page.</summary>
public class TreatmentListModel
{
    public string? Search { get; set; }
    public DateOnly? Date { get; set; }
    public string? Type { get; set; }
    public bool CanWrite { get; set; }
    public List<TreatmentRow> Rows { get; set; } = new();
    public Pager Pager { get; set; } = new();
}

/// <summary>Add / Edit Treatment form (vets only).</summary>
public class TreatmentFormModel
{
    public long? Id { get; set; }                     // null = new record
    public string? ReturnUrl { get; set; }

    [Required(ErrorMessage = "Please choose the pet")]
    [Display(Name = "Pet")]
    public string PetId { get; set; } = "";

    [Required(ErrorMessage = "Please choose the visit date")]
    [DataType(DataType.Date)]
    [Display(Name = "Visit date")]
    public DateOnly? VisitDate { get; set; }

    [Required]
    [Display(Name = "Record type")]
    public string RecordType { get; set; } = "Treatment";

    [StringLength(300)]
    public string? Diagnosis { get; set; }

    [Required(ErrorMessage = "Please describe the treatment")]
    [StringLength(300)]
    public string Treatment { get; set; } = "";

    [StringLength(300)]
    [Display(Name = "Medications")]
    public string? Medications { get; set; }

    [StringLength(1000)]
    public string? Notes { get; set; }

    public List<Option> Pets { get; set; } = new();
    public bool IsNew => Id is null;
}