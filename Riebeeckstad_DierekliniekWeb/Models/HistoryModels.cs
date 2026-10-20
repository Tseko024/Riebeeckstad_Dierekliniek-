namespace RiebeeckstadWeb.Models;

/// <summary>One line in a pet's history (an appointment or a treatment record).</summary>
public class HistoryEntry
{
    public DateOnly Date { get; set; }
    public string Type { get; set; } = "";           // Appointment, Treatment, Vaccination, …
    public string Details { get; set; } = "";
    public string? Vet { get; set; }
    public string? Status { get; set; }              // appointments only
    public string? StatusKey { get; set; }
    public string? Medications { get; set; }
    public string? Diagnosis { get; set; }
    public string? Notes { get; set; }
    public string? EditUrl { get; set; }
    public bool IsAppointment { get; set; }

    public string DateDisplay => Date.ToString("d MMM yyyy");
}

/// <summary>Pet History page for one pet.</summary>
public class PetHistoryModel
{
    public PetRow Pet { get; set; } = new();
    public string Tab { get; set; } = "overview";
    public List<HistoryEntry> Entries { get; set; } = new();
    public string CurrentMedication { get; set; } = "None";
    public int AppointmentCount { get; set; }
    public int RecordCount { get; set; }
    public bool CanWrite { get; set; }

    public static readonly Option[] Tabs =
    {
        new("overview", "Overview"),
        new("appointments", "Appointments"),
        new("treatments", "Treatment History"),
        new("vaccinations", "Vaccination"),
        new("medications", "Medications"),
        new("notes", "Notes"),
    };
}

/// <summary>"Choose a pet" list shown when no pet is selected.</summary>
public class PetPickerModel
{
    public string? Search { get; set; }
    public List<PetRow> Pets { get; set; } = new();
    public Pager Pager { get; set; } = new();
}