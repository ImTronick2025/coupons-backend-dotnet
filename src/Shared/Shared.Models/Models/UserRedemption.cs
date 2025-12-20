using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Shared.Models.Models;

[Table("UserRedemptions")]
public class UserRedemption
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long UserRedemptionId { get; set; }
    
    [Required]
    [MaxLength(100)]
    public string UserId { get; set; } = string.Empty;
    
    [Required]
    [MaxLength(100)]
    public string CampaignId { get; set; } = string.Empty;
    
    [Required]
    public int RedemptionCount { get; set; } = 0;
    
    public DateTime? LastRedeemedAt { get; set; }
    
    [ForeignKey("CampaignId")]
    public virtual Campaign? Campaign { get; set; }
}
