using System.ComponentModel.DataAnnotations;

namespace Shared.Models.DTOs;

public class RedeemRequest
{
    [Required]
    public string CouponCode { get; set; } = string.Empty;
    
    [Required]
    public string UserId { get; set; } = string.Empty;
}
