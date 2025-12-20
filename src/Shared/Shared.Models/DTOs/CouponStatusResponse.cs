namespace Shared.Models.DTOs;

public class CouponStatusResponse
{
    public string CouponCode { get; set; } = string.Empty;
    public bool Valid { get; set; }
    public bool Redeemed { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public string CampaignId { get; set; } = string.Empty;
    public string? AssignedTo { get; set; }
}
