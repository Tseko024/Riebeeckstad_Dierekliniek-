using System.Text.Json.Serialization;

namespace RiebeeckstadWeb.Models;

/// <summary>Page numbers under a table ("Showing 1–10 of 42").</summary>
public class Pager
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 10;
    public int Total { get; set; }
    public string Noun { get; set; } = "records";

    /// <summary>Builds the link for a page number (keeps the current filters).</summary>
    public Func<int, string> UrlFor { get; set; } = _ => "#";

    public int PageCount => Math.Max(1, (int)Math.Ceiling(Total / (double)PageSize));
    public int From => Total == 0 ? 0 : (Page - 1) * PageSize + 1;
    public int To => Math.Min(Page * PageSize, Total);
}

/// <summary>A choice in a drop-down list.</summary>
public record Option(string Value, string Text);

/// <summary>Row of the staff_directory view (vets and receptionists).</summary>
public class StaffMember
{
    [JsonPropertyName("id")] public string Id { get; set; } = "";
    [JsonPropertyName("full_name")] public string? FullName { get; set; }
    [JsonPropertyName("role")] public string? Role { get; set; }

    public string Name => string.IsNullOrWhiteSpace(FullName) ? "(no name)" : FullName!;
}

/// <summary>Row of the profiles table.</summary>
public class ProfileRow
{
    [JsonPropertyName("owner_id")] public string Id { get; set; } = "";
    [JsonPropertyName("full_name")] public string? FullName { get; set; }
    [JsonPropertyName("email")] public string? Email { get; set; }
    [JsonPropertyName("phone")] public string? Phone { get; set; }
    [JsonPropertyName("role")] public string? Role { get; set; }
    [JsonPropertyName("created_at")] public DateTimeOffset? CreatedAt { get; set; }

    public string Name => string.IsNullOrWhiteSpace(FullName) ? (Email ?? "(no name)") : FullName!;
    public string RoleKey => (Role ?? "client").Trim().ToLowerInvariant();
    public string RoleText => Clinic.RoleText(Role);
}

/// <summary>Shared lists and rules for the staff pages.</summary>
public static class Clinic
{
    /// <summary>Clinic date in South African time (UTC+2, no daylight saving).</summary>
    public static DateOnly Today => DateOnly.FromDateTime(DateTime.UtcNow.AddHours(2));
    public static TimeOnly Now => TimeOnly.FromDateTime(DateTime.UtcNow.AddHours(2));

    public static readonly Option[] Services =
    {
        new("general_checkup", "Check-up"),
        new("vaccination", "Vaccination"),
        new("surgery", "Surgery"),
        new("dental", "Dental"),
        new("other", "Other"),
    };

    /// <summary>Values allowed by the appointments_status_check constraint.</summary>
    public static readonly Option[] Statuses =
    {
        new("Pending", "Pending"),
        new("Confirmed", "Scheduled"),
        new("Rescheduled", "Rescheduled"),
        new("Completed", "Completed"),
        new("Cancelled", "Cancelled"),
    };

    public static readonly Option[] Species =
    {
        new("dog", "Dog"),
        new("cat", "Cat"),
        new("bird", "Bird"),
        new("rabbit", "Rabbit"),
        new("other", "Other"),
    };

    public static readonly Option[] RecordTypes =
    {
        new("Checkup", "Check-up"),
        new("Treatment", "Treatment"),
        new("Vaccination", "Vaccination"),
        new("Surgery", "Surgery"),
        new("Dental", "Dental"),
        new("Follow-Up", "Follow-up"),
        new("Other", "Other"),
    };

    /// <summary>Opening hours: Mon–Fri 08:00–16:30, Sat 08:00–11:30 (last slot), Sun closed.</summary>
    public static TimeOnly? LastSlot(DateOnly day) => day.DayOfWeek switch
    {
        DayOfWeek.Sunday => null,
        DayOfWeek.Saturday => new TimeOnly(11, 30),
        _ => new TimeOnly(16, 30),
    };

    /// <summary>Every 30-minute slot from 08:00 to 16:30.</summary>
    public static IEnumerable<string> AllSlots()
    {
        for (var t = new TimeOnly(8, 0); t <= new TimeOnly(16, 30); t = t.AddMinutes(30))
            yield return t.ToString("HH:mm");
    }

    public static string RoleText(string? role) => (role ?? "").Trim().ToLowerInvariant() switch
    {
        "vet" => "Veterinarian",
        "receptionist" => "Receptionist",
        _ => "Client",
    };

    /// <summary>"dog" → "Dog"</summary>
    public static string SpeciesText(string? value) =>
        Species.FirstOrDefault(s => s.Value == (value ?? "").Trim().ToLowerInvariant())?.Text
        ?? (string.IsNullOrWhiteSpace(value) ? "" : char.ToUpper(value.Trim()[0]) + value.Trim()[1..]);
}

/// <summary>Top of each staff page (title, subtitle, buttons).</summary>
public class PageHeader
{
    public string Title { get; set; } = "";
    public string? Subtitle { get; set; }
    public string? BackUrl { get; set; }
    public string BackText { get; set; } = "Back";
    public List<HeaderButton> Buttons { get; set; } = new();
}

public record HeaderButton(string Text, string Url, string Icon = "bi-plus-lg", bool Primary = true);