using Shared.Models.Models;
using Shared.Models.DTOs;
using RedeemService.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Data.SqlClient;
using System.Data;

namespace RedeemService.Services;

public interface ICouponService
{
    Task<CouponStatusResponse?> GetCouponStatusAsync(string code);
    Task<RedeemResponse> RedeemCouponAsync(RedeemRequest request, string? ipAddress, string? userAgent);
}

public class CouponService : ICouponService
{
    private readonly CouponDbContext _context;
    private readonly ILogger<CouponService> _logger;

    public CouponService(CouponDbContext context, ILogger<CouponService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<CouponStatusResponse?> GetCouponStatusAsync(string code)
    {
        try
        {
            var couponCodeParam = new SqlParameter("@CouponCode", code);
            
            var result = await _context.Database
                .SqlQueryRaw<CouponDetailsResult>(
                    "EXEC sp_GetCouponDetails @CouponCode",
                    couponCodeParam)
                .ToListAsync();

            var couponDetails = result.FirstOrDefault();
            
            if (couponDetails == null)
            {
                return null;
            }

            return new CouponStatusResponse
            {
                CouponCode = couponDetails.CouponCode,
                Valid = couponDetails.Valid,
                Redeemed = couponDetails.Redeemed,
                ExpiresAt = couponDetails.ExpiresAt,
                CampaignId = couponDetails.CampaignId,
                AssignedTo = couponDetails.AssignedTo
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting coupon status for {CouponCode}", code);
            return null;
        }
    }

    public async Task<RedeemResponse> RedeemCouponAsync(RedeemRequest request, string? ipAddress, string? userAgent)
    {
        try
        {
            var couponCodeParam = new SqlParameter("@CouponCode", request.CouponCode);
            var userIdParam = new SqlParameter("@UserId", request.UserId);
            var ipAddressParam = new SqlParameter("@IpAddress", (object?)ipAddress ?? DBNull.Value);
            var userAgentParam = new SqlParameter("@UserAgent", (object?)userAgent ?? DBNull.Value);
            
            var successParam = new SqlParameter
            {
                ParameterName = "@Success",
                SqlDbType = SqlDbType.Bit,
                Direction = ParameterDirection.Output
            };
            
            var messageParam = new SqlParameter
            {
                ParameterName = "@Message",
                SqlDbType = SqlDbType.NVarChar,
                Size = 500,
                Direction = ParameterDirection.Output
            };
            
            var campaignIdParam = new SqlParameter
            {
                ParameterName = "@CampaignId",
                SqlDbType = SqlDbType.NVarChar,
                Size = 100,
                Direction = ParameterDirection.Output
            };

            await _context.Database.ExecuteSqlRawAsync(
                "EXEC sp_RedeemCoupon @CouponCode, @UserId, @IpAddress, @UserAgent, @Success OUTPUT, @Message OUTPUT, @CampaignId OUTPUT",
                couponCodeParam, userIdParam, ipAddressParam, userAgentParam, successParam, messageParam, campaignIdParam);

            var success = (bool)successParam.Value;
            var message = messageParam.Value?.ToString() ?? "Error desconocido";
            var campaignId = campaignIdParam.Value?.ToString() ?? string.Empty;

            if (success)
            {
                _logger.LogInformation("Coupon {CouponCode} redeemed successfully by user {UserId}", 
                    request.CouponCode, request.UserId);
                
                // Obtener información del cupón para descuento y fecha
                var couponInfo = await GetCouponStatusAsync(request.CouponCode);
                
                return new RedeemResponse
                {
                    Success = true,
                    CouponCode = request.CouponCode,
                    Message = message,
                    CampaignId = campaignId,
                    RedeemedAt = DateTime.UtcNow,
                    Discount = await GetCampaignDiscountAsync(campaignId)
                };
            }
            else
            {
                _logger.LogWarning("Failed to redeem coupon {CouponCode} for user {UserId}: {Message}", 
                    request.CouponCode, request.UserId, message);
                
                return new RedeemResponse
                {
                    Success = false,
                    CouponCode = request.CouponCode,
                    Message = message,
                    CampaignId = campaignId,
                    RedeemedAt = null,
                    Discount = null
                };
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error redeeming coupon {CouponCode} for user {UserId}", 
                request.CouponCode, request.UserId);
            
            return new RedeemResponse
            {
                Success = false,
                CouponCode = request.CouponCode,
                Message = "Error al procesar el canje del cupón",
                CampaignId = string.Empty,
                RedeemedAt = null,
                Discount = null
            };
        }
    }

    private async Task<decimal?> GetCampaignDiscountAsync(string campaignId)
    {
        try
        {
            var campaign = await _context.Campaigns
                .Where(c => c.CampaignId == campaignId)
                .Select(c => new { c.DiscountPercentage, c.DiscountAmount })
                .FirstOrDefaultAsync();
            
            return campaign?.DiscountPercentage ?? campaign?.DiscountAmount;
        }
        catch
        {
            return null;
        }
    }
}

// Helper class for sp_GetCouponDetails result
public class CouponDetailsResult
{
    public string CouponCode { get; set; } = string.Empty;
    public string CampaignId { get; set; } = string.Empty;
    public bool Redeemed { get; set; }
    public DateTime? RedeemedAt { get; set; }
    public string? RedeemedBy { get; set; }
    public DateTime ExpiresAt { get; set; }
    public string? AssignedTo { get; set; }
    public bool Valid { get; set; }
}
