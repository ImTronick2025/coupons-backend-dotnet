using Microsoft.AspNetCore.Mvc;
using Shared.Models.DTOs;
using CampaignService.Services;

namespace CampaignService.Controllers;

[ApiController]
[Route("api/campaigns")]
public class CampaignsController : ControllerBase
{
    private readonly ICampaignGeneratorService _generatorService;
    private readonly ILogger<CampaignsController> _logger;

    public CampaignsController(ICampaignGeneratorService generatorService, ILogger<CampaignsController> logger)
    {
        _generatorService = generatorService;
        _logger = logger;
    }

    [HttpPost("{id}/generate")]
    [ProducesResponseType(typeof(GenerateResponse), StatusCodes.Status202Accepted)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> GenerateCoupons(string id, [FromBody] GenerateRequest request)
    {
        _logger.LogInformation(
            "Generate request for campaign {CampaignId}: {Amount} coupons with prefix {Prefix}",
            id, request.Amount, request.Prefix);

        var response = await _generatorService.RequestGenerationAsync(id, request);

        _logger.LogInformation("Generation request {RequestId} accepted", response.RequestId);

        return StatusCode(StatusCodes.Status202Accepted, response);
    }

    [HttpGet("{id}/stats")]
    [ProducesResponseType(typeof(CampaignStatsResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetCampaignStats(string id)
    {
        var stats = await _generatorService.GetCampaignStatsAsync(id);
        return Ok(stats);
    }

    [HttpGet("health")]
    public IActionResult Health()
    {
        return Ok(new { status = "healthy", service = "campaign-service" });
    }
}
