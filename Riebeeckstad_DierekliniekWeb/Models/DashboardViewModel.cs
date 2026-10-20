using System.Text.Json.Serialization;

namespace RiebeeckstadWeb.Models;

/// <summary>One row of the appointment_overview view (appointment + client + pet + vet).</summary>
public class AppointmentRow
{
    [JsonPropertyName("appointment_id")] public string Id { get; set; } = "";
    [JsonPropertyName("appointment_date")] public string Date { get; set; } = "";
    [JsonPropertyName("appointment_time")] public string? Time { get; set; }
    [JsonPropertyName("status")] public string? Status { get; set; }
    [JsonPropertyName("reason")] public string? Reason { get; set; }
    [JsonPropertyName("service")] public string? Service { get; set; }
    [JsonPropertyName("urgency")] public string? Urgency { get; set; }
    [JsonPropertyName("client_id")] public string? ClientId { get; set; }
    [JsonPropertyName("client_name")] public string? ClientName { get; set; }
    [JsonPropertyName("client_phone")] public string? ClientPhone { get; set; }
    [JsonPropertyName("pet_id")] public string? PetId { get; set; }
    [JsonPropertyName("patient_name")] public string? PetName { get; set; }
    [JsonPropertyName("species")] public string? Species { get; set; }
    [JsonPropertyName("breed")] public string? Breed { get; set; }
    [JsonPropertyName("age")] public int? Age { get; set; }
    [JsonPropertyName("vet_id")] public string? VetId { get; set; }
    [JsonPropertyName("vet_name")] public string? VetName { get; set; }

    /// <summary>"09:00"</summary>
    public string TimeShort => string.IsNullOrEmpty(Time) ? "" : Time.Length >= 5 ? Time[..5] : Time;

    /// <summary>"13 Oct 2026"</summary>
    public string DateDisplay => DateOnly.TryParse(Date, out var d) ? d.ToString("d MMM yyyy") : Date;

    public string StatusText => Labels.Status(Status);
    public string StatusKey => (Status ?? "pending").Trim().ToLowerInvariant();
    public string ServiceText => Labels.Service(Service);
    public string UrgencyKey => (Urgency ?? "routine").Trim().ToLowerInvariant();

    public bool CanConfirm => StatusKey is "pending" or "rescheduled";
    public bool CanComplete => StatusKey is "confirmed" or "rescheduled";
    public bool CanCancel => StatusKey is "pending" or "confirmed" or "rescheduled";
}

/// <summary>Row from appointments used for "Recent Activity".</summary>
public class RecentRow
{
    [JsonPropertyName("appointment_id")] public string Id { get; set; } = "";
    [JsonPropertyName("created_at")] public DateTimeOffset CreatedAt { get; set; }
    [JsonPropertyName("status")] public string? Status { get; set; }
}

public class ActivityItem
{
    public DateTimeOffset When { get; set; }
    public string Text { get; set; } = "";
    public string StatusKey { get; set; } = "";
    public string StatusText { get; set; } = "";
}

public class DashboardViewModel
{
    public string Greeting { get; set; } = "";
    public DateOnly SelectedDate { get; set; }
    public DateOnly Today { get; set; }
    public bool IsToday => SelectedDate == Today;

    public int AppointmentsToday { get; set; }
    public int TotalClients { get; set; }
    public int TotalPets { get; set; }
    public int PendingBookings { get; set; }

    public List<AppointmentRow> DayAppointments { get; set; } = new();
    public List<AppointmentRow> UrgentUpcoming { get; set; } = new();
    public List<ActivityItem> RecentActivity { get; set; } = new();

    public string? Error { get; set; }
}

/// <summary>Display text for database values.</summary>
public static class Labels
{
    public static string Service(string? value) => (value ?? "").Trim().ToLowerInvariant() switch
    {
        "general_checkup" => "Check-up",
        "vaccination" => "Vaccination",
        "surgery" => "Surgery",
        "dental" => "Dental",
        "other" => "Other",
        "" => "—",
        var v => System.Globalization.CultureInfo.InvariantCulture.TextInfo.ToTitleCase(v.Replace('_', ' ')),
    };

    public static string Status(string? value) => (value ?? "").Trim().ToLowerInvariant() switch
    {
        "pending" => "Pending",
        "confirmed" => "Scheduled",
        "completed" => "Completed",
        "cancelled" => "Cancelled",
        "rescheduled" => "Rescheduled",
        "" => "Pending",
        var v => v,
    };

    public static string TimeAgo(DateTimeOffset when)
    {
        var span = DateTimeOffset.UtcNow - when;
        if (span.TotalMinutes < 1) return "just now";
        if (span.TotalMinutes < 60) return $"{(int)span.TotalMinutes} min ago";
        if (span.TotalHours < 24) return $"{(int)span.TotalHours} h ago";
        if (span.TotalDays < 7) return $"{(int)span.TotalDays} d ago";
        return when.ToOffset(TimeSpan.FromHours(2)).ToString("d MMM");
    }
}