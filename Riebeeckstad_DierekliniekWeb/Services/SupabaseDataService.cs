using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;

namespace RiebeeckstadWeb.Services;

/// <summary>The logged-in user's Supabase session has expired and could not be refreshed.</summary>
public class SessionExpiredException : Exception
{
    public SessionExpiredException() : base("Your session has expired. Please log in again.") { }
}

/// <summary>A database request was rejected (e.g. by a rule or trigger).</summary>
public class SupabaseException : Exception
{
    public SupabaseException(string message) : base(message) { }
}

/// <summary>One page of rows plus the total number of matching rows.</summary>
public record PageResult<T>(List<T> Rows, int Total);

/// <summary>
/// Reads and writes the Supabase database through its REST API (PostgREST).
/// Every call is made AS the logged-in staff member (their access token),
/// so the Row Level Security rules in the database decide what they can see.
/// </summary>
public class SupabaseDataService
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    private readonly HttpClient _http;
    private readonly ILogger<SupabaseDataService> _logger;

    public SupabaseDataService(HttpClient http, IOptions<SupabaseSettings> options, ILogger<SupabaseDataService> logger)
    {
        _http = http;
        _logger = logger;

        var settings = options.Value;
        if (!string.IsNullOrWhiteSpace(settings.Url))
        {
            _http.BaseAddress = new Uri(settings.Url.TrimEnd('/') + "/rest/v1/");
        }
        _http.DefaultRequestHeaders.Add("apikey", settings.PublishableKey);
        _http.Timeout = TimeSpan.FromSeconds(20);
    }

    /// <summary>GET a list of rows, e.g. "appointment_overview?appointment_date=eq.2026-10-13".</summary>
    public async Task<List<T>> GetListAsync<T>(string pathAndQuery, string accessToken, CancellationToken ct = default)
    {
        using var request = NewRequest(HttpMethod.Get, pathAndQuery, accessToken);
        using var response = await _http.SendAsync(request, ct);
        var json = await response.Content.ReadAsStringAsync(ct);
        EnsureSuccess(response, json);
        return JsonSerializer.Deserialize<List<T>>(json, JsonOptions) ?? new List<T>();
    }

    /// <summary>GET the first matching row, or null.</summary>
    public async Task<T?> GetOneAsync<T>(string pathAndQuery, string accessToken, CancellationToken ct = default)
    {
        var separator = pathAndQuery.Contains('?') ? "&" : "?";
        var rows = await GetListAsync<T>(pathAndQuery + separator + "limit=1", accessToken, ct);
        return rows.FirstOrDefault();
    }

    /// <summary>GET one page of rows (page starts at 1) and the total count.</summary>
    public async Task<PageResult<T>> GetPageAsync<T>(
        string pathAndQuery, int page, int pageSize, string accessToken, CancellationToken ct = default)
    {
        page = Math.Max(1, page);
        var separator = pathAndQuery.Contains('?') ? "&" : "?";
        var query = $"{pathAndQuery}{separator}limit={pageSize}&offset={(page - 1) * pageSize}";

        using var request = NewRequest(HttpMethod.Get, query, accessToken);
        request.Headers.Add("Prefer", "count=exact");
        using var response = await _http.SendAsync(request, ct);
        var json = await response.Content.ReadAsStringAsync(ct);
        EnsureSuccess(response, json);

        var rows = JsonSerializer.Deserialize<List<T>>(json, JsonOptions) ?? new List<T>();
        return new PageResult<T>(rows, ReadTotal(response) ?? rows.Count);
    }

    /// <summary>Counts rows without downloading them, e.g. CountAsync("pets", "").</summary>
    public async Task<int> CountAsync(string table, string filter, string accessToken, CancellationToken ct = default)
    {
        var query = string.IsNullOrEmpty(filter) ? $"{table}?select=*" : $"{table}?select=*&{filter}";
        using var request = NewRequest(HttpMethod.Head, query, accessToken);
        request.Headers.Add("Prefer", "count=exact");
        using var response = await _http.SendAsync(request, ct);
        EnsureSuccess(response, "");
        return ReadTotal(response) ?? 0;
    }

    /// <summary>INSERT one row and return the saved row (with its new id).</summary>
    public async Task<T> InsertAsync<T>(string table, object values, string accessToken, CancellationToken ct = default)
    {
        using var request = NewRequest(HttpMethod.Post, table, accessToken);
        request.Headers.Add("Prefer", "return=representation");
        request.Content = new StringContent(JsonSerializer.Serialize(values), Encoding.UTF8, "application/json");
        using var response = await _http.SendAsync(request, ct);
        var json = await response.Content.ReadAsStringAsync(ct);
        EnsureSuccess(response, json);

        var rows = JsonSerializer.Deserialize<List<T>>(json, JsonOptions);
        return rows is { Count: > 0 }
            ? rows[0]
            : throw new SupabaseException("The record was not saved. You may not have permission to do this.");
    }

    /// <summary>
    /// PATCH (update) rows matching the filter, e.g. "appointment_id=eq.{id}".
    /// Returns how many rows were changed (0 usually means no permission or not found).
    /// </summary>
    public async Task<int> UpdateAsync(string table, string filter, object values, string accessToken, CancellationToken ct = default)
    {
        using var request = NewRequest(HttpMethod.Patch, $"{table}?{filter}", accessToken);
        request.Headers.Add("Prefer", "return=minimal, count=exact");
        request.Content = new StringContent(JsonSerializer.Serialize(values), Encoding.UTF8, "application/json");
        using var response = await _http.SendAsync(request, ct);
        var json = await response.Content.ReadAsStringAsync(ct);
        EnsureSuccess(response, json);
        return ReadTotal(response) ?? 1;
    }

    /// <summary>DELETE rows matching the filter. Returns how many rows were removed.</summary>
    public async Task<int> DeleteAsync(string table, string filter, string accessToken, CancellationToken ct = default)
    {
        using var request = NewRequest(HttpMethod.Delete, $"{table}?{filter}", accessToken);
        request.Headers.Add("Prefer", "return=minimal, count=exact");
        using var response = await _http.SendAsync(request, ct);
        var json = await response.Content.ReadAsStringAsync(ct);
        EnsureSuccess(response, json);
        return ReadTotal(response) ?? 1;
    }

    // ------------------------------------------------------------------
    // Helpers for building safe filters from user input
    // ------------------------------------------------------------------

    /// <summary>
    /// Makes search text safe to put inside a PostgREST filter, e.g. or=(name.ilike.*TEXT*).
    /// Removes characters that have a meaning in filters and URL-encodes the rest.
    /// </summary>
    public static string SearchTerm(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return "";
        var cleaned = new string(text.Trim().Where(c => !",()*:\"\\%".Contains(c)).ToArray());
        return Uri.EscapeDataString(cleaned);
    }

    /// <summary>URL-encodes a value for an eq./ilike. filter.</summary>
    public static string Value(string? text) => Uri.EscapeDataString(text ?? "");

    // ------------------------------------------------------------------

    private HttpRequestMessage NewRequest(HttpMethod method, string pathAndQuery, string accessToken)
    {
        if (_http.BaseAddress is null)
            throw new SupabaseException("The server is not connected to Supabase. Please contact the administrator.");

        var request = new HttpRequestMessage(method, pathAndQuery);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        return request;
    }

    /// <summary>PostgREST answers with "Content-Range: 0-9/42" or "*/42".</summary>
    private static int? ReadTotal(HttpResponseMessage response)
    {
        var range = response.Content.Headers.TryGetValues("Content-Range", out var c) ? c.FirstOrDefault()
                  : response.Headers.TryGetValues("Content-Range", out var h) ? h.FirstOrDefault()
                  : null;
        var total = range?.Split('/').LastOrDefault();
        return int.TryParse(total, out var n) ? n : null;
    }

    private void EnsureSuccess(HttpResponseMessage response, string json)
    {
        if (response.IsSuccessStatusCode) return;

        if (response.StatusCode == HttpStatusCode.Unauthorized)
            throw new SessionExpiredException();

        var message = $"Database request failed ({(int)response.StatusCode}).";
        string? code = null;
        try
        {
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.TryGetProperty("message", out var m) && m.ValueKind == JsonValueKind.String)
                message = m.GetString()!;
            if (doc.RootElement.TryGetProperty("code", out var c) && c.ValueKind == JsonValueKind.String)
                code = c.GetString();
        }
        catch (JsonException)
        {
            // keep generic message
        }

        _logger.LogWarning("Supabase REST error {Status} {Code}: {Message}", (int)response.StatusCode, code, message);
        throw new SupabaseException(Friendly(code, message));
    }

    private static string Friendly(string? code, string message) => code switch
    {
        "42501" => "You don't have permission to do this.",                         // RLS / grants
        "23503" => "This record is linked to other records and can't be changed that way.",
        "23505" => "This record already exists.",
        "23514" => "One of the values isn't allowed. Please check the form.",       // CHECK constraint
        "PGRST205" or "42P01" => "A database table or view is missing. Run staff_pages.sql in Supabase.",
        "42703" => "A database column is missing. Run staff_pages.sql in Supabase.",
        _ => message,
    };
}