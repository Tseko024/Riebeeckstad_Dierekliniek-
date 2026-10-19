using Microsoft.AspNetCore.Mvc;
using RiebeeckstadWeb.Models;
using RiebeeckstadWeb.Services;

namespace RiebeeckstadWeb.Controllers;

/// <summary>Messages between the clinic and clients (stored in public.messages).</summary>
public class MessagesController : StaffController
{
    public MessagesController(SupabaseDataService data, StaffSession session) : base(data, session) { }

    // GET /Messages?clientId=...&q=peter
    public async Task<IActionResult> Index(string? clientId, string? q, CancellationToken ct)
    {
        ViewData["Active"] = "Messages";
        ViewData["Title"] = "Messages";
        var token = await TokenAsync(ct);
        var model = await LoadAsync(clientId, q, token, ct);
        if (clientId is not null && model.Client is null) return NotFound();

        // Opening a conversation marks the client's messages as read
        if (model.Client is not null && model.Messages.Any(m => m.FromClient && m.ReadAt is null))
        {
            await Data.UpdateAsync("messages",
                $"client_id=eq.{model.Client.Id}&sender_id=eq.{model.Client.Id}&read_at=is.null",
                new { read_at = DateTimeOffset.UtcNow }, token, ct);
            var thread = model.Threads.FirstOrDefault(t => t.ClientId == model.Client.Id);
            if (thread is not null) thread.Unread = 0;
        }
        return View(model);
    }

    // POST /Messages/Send
    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Send(string clientId, string? reply, CancellationToken ct)
    {
        ViewData["Active"] = "Messages";
        ViewData["Title"] = "Messages";
        if (!Guid.TryParse(clientId, out _)) return BadRequest();
        var token = await TokenAsync(ct);

        var text = reply?.Trim() ?? "";
        string? error = text.Length == 0 ? "Please type a message."
                      : text.Length > 2000 ? "Messages can be at most 2000 characters."
                      : null;

        if (error is null)
        {
            try
            {
                await Data.InsertAsync<MessageRow>("messages",
                    new { client_id = clientId, sender_id = Session.UserId, body = text }, token, ct);
                return RedirectToAction(nameof(Index), new { clientId });
            }
            catch (SupabaseException ex)
            {
                error = ex.Message;
            }
        }

        var model = await LoadAsync(clientId, null, token, ct);
        model.Reply = reply;
        ModelState.AddModelError(nameof(model.Reply), error);
        return View("Index", model);
    }

    // ------------------------------------------------------------------

    private async Task<MessagesModel> LoadAsync(string? clientId, string? q, string token, CancellationToken ct)
    {
        var threadQuery = "message_threads?select=*&order=last_at.desc";
        var term = SupabaseDataService.SearchTerm(q);
        if (term.Length > 0) threadQuery += $"&or=(client_name.ilike.*{term}*,email.ilike.*{term}*)";

        var threadsTask = Data.GetListAsync<MessageThreadRow>(threadQuery, token, ct);
        var clientsTask = Data.GetListAsync<ClientRow>("client_overview?select=owner_id,full_name,email&order=full_name.asc", token, ct);
        var staffTask = Data.GetListAsync<StaffMember>("staff_directory?select=*", token, ct);
        await Task.WhenAll(threadsTask, clientsTask, staffTask);

        var model = new MessagesModel
        {
            Search = q,
            Threads = threadsTask.Result,
            Clients = clientsTask.Result.Select(c => new Option(c.Id, c.Label)).ToList(),
            StaffNames = staffTask.Result.ToDictionary(s => s.Id, s => s.Name),
        };

        if (Guid.TryParse(clientId, out _))
        {
            var clientTask = Data.GetOneAsync<ProfileRow>($"profiles?select=*&owner_id=eq.{clientId}", token, ct);
            var messagesTask = Data.GetListAsync<MessageRow>(
                $"messages?select=*&client_id=eq.{clientId}&order=created_at.desc&limit=200", token, ct);
            await Task.WhenAll(clientTask, messagesTask);
            model.Client = clientTask.Result;
            model.Messages = messagesTask.Result.OrderBy(m => m.CreatedAt).ToList();   // newest 200, oldest first
        }
        return model;
    }
}