using System.ComponentModel.DataAnnotations;

namespace RiebeeckstadWeb.Models;

/// <summary>My profile (name + phone).</summary>
public class ProfileFormModel
{
    public string? Email { get; set; }

    [Required(ErrorMessage = "Please enter your full name")]
    [StringLength(100, MinimumLength = 2, ErrorMessage = "Please enter your full name")]
    [Display(Name = "Full Name")]
    public string FullName { get; set; } = "";

    [RegularExpression(@"^\s*(\+27|0)(\s*-?\s*\d){9}\s*$", ErrorMessage = "Enter a valid SA number, e.g. 071 234 5678")]
    [Display(Name = "Phone number")]
    public string? Phone { get; set; }
}

/// <summary>Change password.</summary>
public class PasswordFormModel
{
    [Required(ErrorMessage = "Please enter your current password")]
    [DataType(DataType.Password)]
    [Display(Name = "Current password")]
    public string CurrentPassword { get; set; } = "";

    [Required(ErrorMessage = "Please enter a new password")]
    [StringLength(72, MinimumLength = 8, ErrorMessage = "Password must be at least 8 characters")]
    [DataType(DataType.Password)]
    [Display(Name = "New password")]
    public string NewPassword { get; set; } = "";

    [Required(ErrorMessage = "Please confirm the new password")]
    [Compare(nameof(NewPassword), ErrorMessage = "Passwords do not match")]
    [DataType(DataType.Password)]
    [Display(Name = "Confirm new password")]
    public string ConfirmPassword { get; set; } = "";
}

/// <summary>Give a person vet / receptionist access (vets only).</summary>
public class StaffAccessFormModel
{
    [Required(ErrorMessage = "Please enter the person's email address")]
    [EmailAddress(ErrorMessage = "Please enter a valid email address")]
    [Display(Name = "Email address")]
    public string Email { get; set; } = "";

    [Required]
    public string Role { get; set; } = "receptionist";

    public static readonly Option[] Roles =
    {
        new("vet", "Veterinarian"),
        new("receptionist", "Receptionist"),
        new("client", "Client (no staff access)"),
    };
}

/// <summary>Settings page.</summary>
public class SettingsModel
{
    public ProfileFormModel Profile { get; set; } = new();
    public PasswordFormModel Password { get; set; } = new();
    public StaffAccessFormModel Access { get; set; } = new();
    public List<ProfileRow> Staff { get; set; } = new();
    public bool IsVet { get; set; }
    public string CurrentUserId { get; set; } = "";
    public string Section { get; set; } = "profile";   // which card shows errors / is opened
}