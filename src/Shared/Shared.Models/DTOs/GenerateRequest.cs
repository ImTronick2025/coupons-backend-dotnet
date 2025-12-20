using System.ComponentModel.DataAnnotations;

namespace Shared.Models.DTOs;

public class GenerateRequest
{
    [Required]
    [Range(1, 1_000_000)]
    public int Amount { get; set; }
    
    [Required]
    public string Prefix { get; set; } = string.Empty;
    
    public DateTime? Expiration { get; set; }
}
