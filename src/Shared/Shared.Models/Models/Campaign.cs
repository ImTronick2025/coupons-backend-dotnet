using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Shared.Models.Models;

[Table("Campaigns")]
public class Campaign
{
    [Key]
    [MaxLength(100)]
    public string CampaignId { get; set; } = string.Empty;
    
    [Required]
    [MaxLength(200)]
    public string Name { get; set; } = string.Empty;
    
    [MaxLength(1000)]
    public string? Description { get; set; }
    
    [Required]
    public DateTime StartDate { get; set; }
    
    [Required]
    public DateTime EndDate { get; set; }
    
    [Column(TypeName = "decimal(5,2)")]
    public decimal? DiscountPercentage { get; set; }
    
    [Column(TypeName = "decimal(10,2)")]
    public decimal? DiscountAmount { get; set; }
    
    [Required]
    public int MaxRedemptionsPerUser { get; set; } = 1;
    
    public int? MaxTotalRedemptions { get; set; }
    
    [Required]
    public int CurrentRedemptions { get; set; } = 0;
    
    [Required]
    public bool IsActive { get; set; } = true;
    
    [Required]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    
    [Required]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    
    [MaxLength(100)]
    public string? CreatedBy { get; set; }
    
    public virtual ICollection<Coupon> Coupons { get; set; } = new List<Coupon>();
}
