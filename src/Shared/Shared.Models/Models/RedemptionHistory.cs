using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Shared.Models.Models;

[Table("RedemptionHistory")]
public class RedemptionHistory
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long RedemptionId { get; set; }
    
    [Required]
    [MaxLength(50)]
    public string CouponCode { get; set; } = string.Empty;
    
    [Required]
    [MaxLength(100)]
    public string UserId { get; set; } = string.Empty;
    
    [MaxLength(100)]
    public string? CampaignId { get; set; }
    
    [Required]
    public DateTime AttemptedAt { get; set; } = DateTime.UtcNow;
    
    [Required]
    public bool Success { get; set; }
    
    [MaxLength(500)]
    public string? FailureReason { get; set; }
    
    [MaxLength(45)]
    public string? IpAddress { get; set; }
    
    [MaxLength(500)]
    public string? UserAgent { get; set; }
}
