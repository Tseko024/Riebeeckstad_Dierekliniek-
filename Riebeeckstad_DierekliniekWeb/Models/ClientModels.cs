using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace RiebeeckstadWeb.Models;

/// <summary>Row of the client_overview view.</summary>
public class ClientRow
{
    [JsonPropertyName("owner_id")] public string Id { get; set; } = "";
    [JsonPropertyName("full_name")] public string? FullName { get; set; }
    [JsonPropertyName("email")] public string? Email { get; set; }
    [JsonPropertyName("phone")] public string? Phone { get; set; }
    [JsonPropertyName("created_at")] public DateTimeOffset? CreatedAt { get; set; }
    [JsonPropertyName("pet_count")] public int PetCount { get; set; }
    [JsonPropertyName("pet_names")] public string? PetNames { get; set; }

    public string Name => string.IsNullOrWhiteSpace(FullName) ? (Email ?? "(no name)") : FullName!;
    public string Label => string.IsNullOrEmpty(Email) ? Name : $"{Name} ({Email})";
}

/// <summary>Row of the pet_overview view.</summary>
public class PetRow
{
    [JsonPropertyName("pet_id")] public string Id { get; set; } = "";
    [JsonPropertyName("patient_name")] public string? Name { get; set; }
    [JsonPropertyName("species")] public string? Species { get; set; }
    [JsonPropertyName("breed")] public string? Breed { get; set; }
    [JsonPropertyName("age")] public int? Age { get; set; }
    [JsonPropertyName("microchip")] public string? Microchip { get; set; }
    [JsonPropertyName("blood_type")] public string? BloodType { get; set; }
    [JsonPropertyName("allergies")] public string? Allergies { get; set; }
    [JsonPropertyName("chronic_conditions")] public string? ChronicConditions { get; set; }
    [JsonPropertyName("created_at")] public DateTimeOffset? CreatedAt { get; set; }
    [JsonPropertyName("owner_id")] public string? OwnerId { get; set; }
    [JsonPropertyName("owner_name")] public string? OwnerName { get; set; }
    [JsonPropertyName("owner_email")] public string? OwnerEmail { get; set; }
    [JsonPropertyName("owner_phone")] public string? OwnerPhone { get; set; }

    public string SpeciesText => Clinic.SpeciesText(Species);
    public string AgeText => Age is null ? "—" : Age == 1 ? "1 year" : $"{Age} years";
}

/// <summary>Clients/Pets page.</summary>
public class ClientListModel
{
    public string Tab { get; set; } = "clients";      // clients | pets
    public string? Search { get; set; }
    public string? Species { get; set; }
    public List<ClientRow> Clients { get; set; } = new();
    public List<PetRow> Pets { get; set; } = new();
    public Pager Pager { get; set; } = new();
}

/// <summary>Client profile with their pets and appointments.</summary>
public class ClientDetailsModel
{
    public ProfileRow Client { get; set; } = new();
    public List<PetRow> Pets { get; set; } = new();
    public List<AppointmentRow> Appointments { get; set; } = new();
}

/// <summary>Add Client form (creates their login account + optional first pet).</summary>
public class ClientCreateModel
{
    [Required(ErrorMessage = "Please enter the client's full name")]
    [StringLength(100, MinimumLength = 2, ErrorMessage = "Please enter the client's full name")]
    [Display(Name = "Full Name")]
    public string FullName { get; set; } = "";

    [Required(ErrorMessage = "Please enter the client's email address")]
    [EmailAddress(ErrorMessage = "Please enter a valid email address")]
    [Display(Name = "Email Address")]
    public string Email { get; set; } = "";

    [Required(ErrorMessage = "Please enter the client's phone number")]
    [RegularExpression(@"^\s*(\+27|0)(\s*-?\s*\d){9}\s*$", ErrorMessage = "Enter a valid SA number, e.g. 071 234 5678")]
    [Display(Name = "Phone number")]
    public string Phone { get; set; } = "";

    [Required(ErrorMessage = "Please enter a temporary password")]
    [StringLength(72, MinimumLength = 8, ErrorMessage = "Password must be at least 8 characters")]
    [Display(Name = "Temporary password")]
    public string TempPassword { get; set; } = "";

    // Optional first pet
    [StringLength(60)][Display(Name = "Pet name")] public string? PetName { get; set; }
    [Display(Name = "Species")] public string? PetSpecies { get; set; }
    [StringLength(60)][Display(Name = "Breed")] public string? PetBreed { get; set; }
    [Range(0, 60, ErrorMessage = "Age must be between 0 and 60")][Display(Name = "Age (years)")] public int? PetAge { get; set; }
}

/// <summary>Edit Client form.</summary>
public class ClientEditModel
{
    public string Id { get; set; } = "";
    public string? Email { get; set; }                // shown, not editable (it is their login)

    [Required(ErrorMessage = "Please enter the client's full name")]
    [StringLength(100, MinimumLength = 2, ErrorMessage = "Please enter the client's full name")]
    [Display(Name = "Full Name")]
    public string FullName { get; set; } = "";

    [Required(ErrorMessage = "Please enter the client's phone number")]
    [RegularExpression(@"^\s*(\+27|0)(\s*-?\s*\d){9}\s*$", ErrorMessage = "Enter a valid SA number, e.g. 071 234 5678")]
    [Display(Name = "Phone number")]
    public string Phone { get; set; } = "";
}

/// <summary>Add / Edit Pet form.</summary>
public class PetFormModel
{
    public string? Id { get; set; }                   // null = new pet
    public string? ReturnUrl { get; set; }

    [Required(ErrorMessage = "Please choose the owner")]
    [Display(Name = "Owner")]
    public string OwnerId { get; set; } = "";

    [Required(ErrorMessage = "Please enter the pet's name")]
    [StringLength(60)]
    [Display(Name = "Pet name")]
    public string Name { get; set; } = "";

    [Required(ErrorMessage = "Please choose the species")]
    public string Species { get; set; } = "dog";

    [StringLength(60)] public string? Breed { get; set; }

    [Range(0, 60, ErrorMessage = "Age must be between 0 and 60")]
    [Display(Name = "Age (years)")]
    public int? Age { get; set; }

    [StringLength(30)][Display(Name = "Microchip number")] public string? Microchip { get; set; }
    [StringLength(30)][Display(Name = "Blood type")] public string? BloodType { get; set; }
    [StringLength(200)] public string? Allergies { get; set; }
    [StringLength(200)][Display(Name = "Chronic conditions")] public string? ChronicConditions { get; set; }

    public List<Option> Owners { get; set; } = new();
    public bool IsNew => string.IsNullOrEmpty(Id);
}