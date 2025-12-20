using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Shared.Models.Models;

[Table("GenerationRequests")]
public class GenerationRequest
{
    [Key]
    [MaxLength(100)]
    public string RequestId { get; set; } = string.Empty;
    
    [Required]
    [MaxLength(100)]
    public string CampaignId { get; set; } = string.Empty;
    
    [Required]
    public int RequestedAmount { get; set; }
    
    [Required]
    public int GeneratedAmount { get; set; } = 0;
    
    [MaxLength(20)]
    public string? Prefix { get; set; }
    
    [Required]
    public DateTime ExpirationDate { get; set; }
    
    [Required]
    [MaxLength(20)]
    public string Status { get; set; } = "pending";
    
    public DateTime? StartedAt { get; set; }
    
    public DateTime? CompletedAt { get; set; }
    
    [MaxLength(1000)]
    public string? FailureReason { get; set; }
    
    [Required]
    [MaxLength(100)]
    public string RequestedBy { get; set; } = string.Empty;
    
    [Required]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    
    [ForeignKey("CampaignId")]
    public virtual Campaign? Campaign { get; set; }
}
