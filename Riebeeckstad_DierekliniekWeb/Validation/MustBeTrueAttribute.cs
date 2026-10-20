using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace RiebeeckstadWeb.Validation;

/// <summary>
/// Checkbox must be ticked. Works in the browser (jQuery validation) and on the server.
/// </summary>
[AttributeUsage(AttributeTargets.Property)]
public class MustBeTrueAttribute : ValidationAttribute, IClientModelValidator
{
    public override bool IsValid(object? value) => value is true;

    public void AddValidation(ClientModelValidationContext context)
    {
        context.Attributes["data-val"] = "true";
        context.Attributes["data-val-mustbetrue"] = FormatErrorMessage(context.ModelMetadata.GetDisplayName());
    }
}