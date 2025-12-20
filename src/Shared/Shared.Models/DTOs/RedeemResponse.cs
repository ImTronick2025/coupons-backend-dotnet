namespace Shared.Models.DTOs;

public class RedeemResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public decimal? Discount { get; set; }
    public string CouponCode { get; set; } = string.Empty;
    public string CampaignId { get; set; } = string.Empty;
    public DateTime? RedeemedAt { get; set; }
}
