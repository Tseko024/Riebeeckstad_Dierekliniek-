using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace RiebeeckstadWeb.Models;

/// <summary>Row of the message_threads view (one per client conversation).</summary>
public class MessageThreadRow
{
    [JsonPropertyName("client_id")] public string ClientId { get; set; } = "";
    [JsonPropertyName("client_name")] public string? ClientName { get; set; }
    [JsonPropertyName("email")] public string? Email { get; set; }
    [JsonPropertyName("phone")] public string? Phone { get; set; }
    [JsonPropertyName("last_body")] public string? LastBody { get; set; }
    [JsonPropertyName("last_at")] public DateTimeOffset LastAt { get; set; }
    [JsonPropertyName("last_from_client")] public bool LastFromClient { get; set; }
    [JsonPropertyName("unread")] public int Unread { get; set; }

    public string Name => string.IsNullOrWhiteSpace(ClientName) ? (Email ?? "Client") : ClientName!;
}

/// <summary>Row of the messages table.</summary>
public class MessageRow
{
    [JsonPropertyName("message_id")] public string Id { get; set; } = "";
    [JsonPropertyName("client_id")] public string ClientId { get; set; } = "";
    [JsonPropertyName("sender_id")] public string? SenderId { get; set; }
    [JsonPropertyName("body")] public string Body { get; set; } = "";
    [JsonPropertyName("created_at")] public DateTimeOffset CreatedAt { get; set; }
    [JsonPropertyName("read_at")] public DateTimeOffset? ReadAt { get; set; }

    public bool FromClient => SenderId == ClientId;
}

/// <summary>Messages page.</summary>
public class MessagesModel
{
    public List<MessageThreadRow> Threads { get; set; } = new();
    public ProfileRow? Client { get; set; }
    public List<MessageRow> Messages { get; set; } = new();
    public Dictionary<string, string> StaffNames { get; set; } = new();
    public List<Option> Clients { get; set; } = new();
    public string? Search { get; set; }

    [Required(ErrorMessage = "Please type a message")]
    [StringLength(2000, ErrorMessage = "Messages can be at most 2000 characters")]
    public string? Reply { get; set; }

    public string SenderName(MessageRow m) =>
        m.FromClient ? Client?.Name ?? "Client"
        : m.SenderId is not null && StaffNames.TryGetValue(m.SenderId, out var n) ? n : "Clinic";
}