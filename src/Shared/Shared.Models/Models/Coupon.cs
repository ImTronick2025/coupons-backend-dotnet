using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Shared.Models.Models;

[Table("Coupons")]
public class Coupon
{
    [Key]
    [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
    public long CouponId { get; set; }
    
    [Required]
    [MaxLength(50)]
    public string CouponCode { get; set; } = string.Empty;
    
    [Required]
    [MaxLength(100)]
    public string CampaignId { get; set; } = string.Empty;
    
    public bool IsRedeemed { get; set; }
    
    public DateTime? RedeemedAt { get; set; }
    
    [MaxLength(100)]
    public string? RedeemedBy { get; set; }
    
    [Required]
    public DateTime ExpiresAt { get; set; }
    
    [MaxLength(100)]
    public string? AssignedTo { get; set; }
    
    [MaxLength(100)]
    public string? GenerationBatchId { get; set; }
    
    [Required]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    
    [ForeignKey("CampaignId")]
    public virtual Campaign? Campaign { get; set; }
}
