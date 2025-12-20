using Microsoft.AspNetCore.Mvc;
using Shared.Models.DTOs;
using RedeemService.Services;

namespace RedeemService.Controllers;

[ApiController]
[Route("api")]
public class CouponsController : ControllerBase
{
    private readonly ICouponService _couponService;
    private readonly ILogger<CouponsController> _logger;

    public CouponsController(ICouponService couponService, ILogger<CouponsController> logger)
    {
        _couponService = couponService;
        _logger = logger;
    }

    [HttpPost("redeem")]
    [ProducesResponseType(typeof(RedeemResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> RedeemCoupon([FromBody] RedeemRequest request)
    {
        _logger.LogInformation("Redeem request for coupon {CouponCode} by user {UserId}", 
            request.CouponCode, request.UserId);

        // Get client IP and User-Agent
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
        var userAgent = HttpContext.Request.Headers["User-Agent"].ToString();

        var response = await _couponService.RedeemCouponAsync(request, ipAddress, userAgent);

        if (!response.Success)
        {
            _logger.LogWarning("Redeem failed for coupon {CouponCode}: {Message}", 
                request.CouponCode, response.Message);
                
            return BadRequest(new ErrorResponse
            {
                Error = "REDEEM_FAILED",
                Message = response.Message
            });
        }

        _logger.LogInformation("Coupon {CouponCode} redeemed successfully", request.CouponCode);
        return Ok(response);
    }

    [HttpGet("coupon/{code}")]
    [ProducesResponseType(typeof(CouponStatusResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetCouponStatus(string code)
    {
        _logger.LogInformation("Status request for coupon {CouponCode}", code);

        var coupon = await _couponService.GetCouponStatusAsync(code);

        if (coupon == null)
        {
            _logger.LogWarning("Coupon {CouponCode} not found", code);
            
            return NotFound(new ErrorResponse
            {
                Error = "COUPON_NOT_FOUND",
                Message = "El cupón no existe."
            });
        }

        return Ok(coupon);
    }

    [HttpGet("health")]
    public IActionResult Health()
    {
        return Ok(new { status = "healthy", service = "redeem-service", timestamp = DateTime.UtcNow });
    }
}
