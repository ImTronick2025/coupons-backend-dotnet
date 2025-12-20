namespace Shared.Models.DTOs;

public class GenerateResponse
{
    public bool Success { get; set; }
    public int Generated { get; set; }
    public string Message { get; set; } = string.Empty;
    public string RequestId { get; set; } = string.Empty;
    public string CampaignId { get; set; } = string.Empty;
    public string Status { get; set; } = "pending";
    public DateTime? EstimatedCompletionTime { get; set; }
}
