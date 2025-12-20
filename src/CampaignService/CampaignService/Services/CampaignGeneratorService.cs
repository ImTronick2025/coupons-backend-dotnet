using Shared.Models.DTOs;

namespace CampaignService.Services;

public interface ICampaignGeneratorService
{
    Task<GenerateResponse> RequestGenerationAsync(string campaignId, GenerateRequest request);
    Task<CampaignStatsResponse> GetCampaignStatsAsync(string campaignId);
}

public class CampaignGeneratorService : ICampaignGeneratorService
{
    private readonly ILogger<CampaignGeneratorService> _logger;
    private readonly string _connectionString;
    private static readonly Dictionary<string, GenerateResponse> _requests = new();

    public CampaignGeneratorService(ILogger<CampaignGeneratorService> logger, string connectionString)
    {
        _logger = logger;
        _connectionString = connectionString;
    }

    public Task<GenerateResponse> RequestGenerationAsync(string campaignId, GenerateRequest request)
    {
        var requestId = $"gen-req-{Guid.NewGuid():N}";

        var response = new GenerateResponse
        {
            Success = true,
            Generated = 0,
            Message = "Generación iniciada",
            RequestId = requestId,
            CampaignId = campaignId,
            Status = "pending",
            EstimatedCompletionTime = DateTime.UtcNow.AddMinutes(5)
        };

        _logger.LogInformation(
            "Generation request {RequestId} created for campaign {CampaignId}: {Amount} coupons with prefix {Prefix}",
            requestId, campaignId, request.Amount, request.Prefix);

        // Generación asíncrona real de cupones
        Task.Run(async () =>
        {
            try
            {
                _logger.LogInformation("Starting coupon generation for request {RequestId}: {Amount} coupons", 
                    requestId, request.Amount);
                
                response.Status = "running";
                
                // Generar cupones usando el stored procedure
                await GenerateCouponsInDatabaseAsync(campaignId, request.Prefix, request.Amount);
                
                response.Status = "completed";
                response.Generated = request.Amount;
                response.Message = $"Generación completada: {request.Amount} cupones creados";
                
                _logger.LogInformation("Generation completed for request {RequestId}: {Amount} coupons created", 
                    requestId, request.Amount);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Generation failed for request {RequestId}", requestId);
                response.Status = "failed";
                response.Success = false;
                response.Message = $"Error en la generación: {ex.Message}";
            }
        });

        return Task.FromResult(response);
    }

    private async Task GenerateCouponsInDatabaseAsync(string campaignId, string prefix, int amount)
    {
        using var connection = new Microsoft.Data.SqlClient.SqlConnection(_connectionString);
        await connection.OpenAsync();

        using var command = new Microsoft.Data.SqlClient.SqlCommand("sp_GenerateCoupons", connection);
        command.CommandType = System.Data.CommandType.StoredProcedure;
        command.CommandTimeout = 300; // 5 minutos para generaciones grandes
        
        command.Parameters.AddWithValue("@CampaignId", campaignId);
        command.Parameters.AddWithValue("@Prefix", prefix);
        command.Parameters.AddWithValue("@Amount", amount);
        command.Parameters.AddWithValue("@ExpiresAt", DateTime.UtcNow.AddYears(1)); // Expiran en 1 año
        command.Parameters.AddWithValue("@GenerationBatchId", Guid.NewGuid().ToString());

        await command.ExecuteNonQueryAsync();
        
        _logger.LogInformation("Generated {Amount} coupons for campaign {CampaignId} with prefix {Prefix}", 
            amount, campaignId, prefix);
    }

    public async Task<CampaignStatsResponse> GetCampaignStatsAsync(string campaignId)
    {
        try
        {
            using var connection = new Microsoft.Data.SqlClient.SqlConnection(_connectionString);
            await connection.OpenAsync();

            using var totalCommand = new Microsoft.Data.SqlClient.SqlCommand(
                "SELECT COUNT(*) FROM Coupons WHERE CampaignId = @CampaignId",
                connection);
            totalCommand.Parameters.AddWithValue("@CampaignId", campaignId);
            var totalCoupons = (int)await totalCommand.ExecuteScalarAsync();

            using var usedCommand = new Microsoft.Data.SqlClient.SqlCommand(
                "SELECT COUNT(*) FROM Coupons WHERE CampaignId = @CampaignId AND IsRedeemed = 1",
                connection);
            usedCommand.Parameters.AddWithValue("@CampaignId", campaignId);
            var usedCoupons = (int)await usedCommand.ExecuteScalarAsync();

            return new CampaignStatsResponse
            {
                CampaignId = campaignId,
                TotalGenerated = totalCoupons,
                TotalUsed = usedCoupons,
                TotalAvailable = totalCoupons - usedCoupons
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting campaign stats for {CampaignId}", campaignId);
            return new CampaignStatsResponse
            {
                CampaignId = campaignId,
                TotalGenerated = 0,
                TotalUsed = 0,
                TotalAvailable = 0
            };
        }
    }
}
