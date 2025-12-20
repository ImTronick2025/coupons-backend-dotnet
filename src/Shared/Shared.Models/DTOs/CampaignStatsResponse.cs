namespace Shared.Models.DTOs;

public class CampaignStatsResponse
{
    public string CampaignId { get; set; } = string.Empty;
    public int TotalGenerated { get; set; }
    public int TotalUsed { get; set; }
    public int TotalAvailable { get; set; }
}
