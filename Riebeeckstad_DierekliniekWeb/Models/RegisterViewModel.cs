using System.ComponentModel.DataAnnotations;
using RiebeeckstadWeb.Validation;
namespace RiebeeckstadWeb.Models;

/// <summary>Form fields on the Registration screen.</summary>
public class RegisterViewModel
{
    [Required(ErrorMessage = "Please enter your full name")]
    [StringLength(100, MinimumLength = 2, ErrorMessage = "Please enter your full name")]
    [Display(Name = "Full Name")]
    public string FullName { get; set; } = "";

    [Required(ErrorMessage = "Please enter your email address")]
    [EmailAddress(ErrorMessage = "Please enter a valid email address")]
    [Display(Name = "Email Address")]
    public string Email { get; set; } = "";

    [Required(ErrorMessage = "Please enter a password")]
    [StringLength(72, MinimumLength = 8, ErrorMessage = "Password must be at least 8 characters")]
    [DataType(DataType.Password)]
    public string Password { get; set; } = "";

    [Required(ErrorMessage = "Please confirm your password")]
    [Compare(nameof(Password), ErrorMessage = "Passwords do not match")]
    [DataType(DataType.Password)]
    [Display(Name = "Confirm Password")]
    public string ConfirmPassword { get; set; } = "";

    [Required(ErrorMessage = "Please enter your phone number")]
    [RegularExpression(@"^\s*(\+27|0)(\s*-?\s*\d){9}\s*$",
        ErrorMessage = "Enter a valid SA number, e.g. 071 234 5678")]
    [Display(Name = "Phone number")]
    public string Phone { get; set; } = "";
    [MustBeTrue(ErrorMessage = "Please accept the Terms and Conditions and Privacy Policy")]
    public bool AgreeToTerms { get; set; }
}