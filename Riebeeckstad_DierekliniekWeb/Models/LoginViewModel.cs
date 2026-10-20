using System.ComponentModel.DataAnnotations;

namespace RiebeeckstadWeb.Models;

/// <summary>Form fields on the Login screen.</summary>
public class LoginViewModel
{
    [Required(ErrorMessage = "Please enter your email address")]
    [EmailAddress(ErrorMessage = "Please enter a valid email address")]
    [Display(Name = "Email Address")]
    public string Email { get; set; } = "";

    [Required(ErrorMessage = "Please enter your password")]
    [DataType(DataType.Password)]
    public string Password { get; set; } = "";

    [Display(Name = "Remember me")]
    public bool RememberMe { get; set; }

    /// <summary>Page to return to after logging in (e.g. a link they opened while logged out).</summary>
    public string? ReturnUrl { get; set; }
}

/// <summary>Form on the Forgot Password screen.</summary>
public class ForgotPasswordViewModel
{
    [Required(ErrorMessage = "Please enter your email address")]
    [EmailAddress(ErrorMessage = "Please enter a valid email address")]
    [Display(Name = "Email Address")]
    public string Email { get; set; } = "";
}
