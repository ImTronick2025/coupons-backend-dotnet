using Microsoft.EntityFrameworkCore;
using Shared.Models.Models;

namespace RedeemService.Data;

public class CouponDbContext : DbContext
{
    public CouponDbContext(DbContextOptions<CouponDbContext> options) : base(options)
    {
    }

    public DbSet<Coupon> Coupons { get; set; }
    public DbSet<Campaign> Campaigns { get; set; }
    public DbSet<RedemptionHistory> RedemptionHistory { get; set; }
    public DbSet<UserRedemption> UserRedemptions { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Campaigns are configured via data annotations
        // Coupons are configured via data annotations
        // RedemptionHistory are configured via data annotations
        // UserRedemptions are configured via data annotations
    }
}
