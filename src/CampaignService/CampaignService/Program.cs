using CampaignService.Services;
using CampaignService.Data;
using Microsoft.EntityFrameworkCore;
using Azure.Identity;

var builder = WebApplication.CreateBuilder(args);

// Configurar Azure Key Vault si está en producción
if (builder.Environment.IsProduction())
{
    var keyVaultUrl = builder.Configuration["KeyVaultUrl"];
    if (!string.IsNullOrEmpty(keyVaultUrl))
    {
        builder.Configuration.AddAzureKeyVault(
            new Uri(keyVaultUrl),
            new DefaultAzureCredential());
    }
}

// Configurar DbContext
var connectionString = builder.Configuration.GetConnectionString("CampaignsDb");
if (!string.IsNullOrEmpty(connectionString))
{
    builder.Services.AddDbContext<CampaignDbContext>(options =>
        options.UseSqlServer(connectionString));
}

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();

// Registrar CampaignGeneratorService con configuración
builder.Services.AddSingleton<ICampaignGeneratorService>(sp => 
{
    var logger = sp.GetRequiredService<ILogger<CampaignGeneratorService>>();
    var configuration = sp.GetRequiredService<IConfiguration>();
    var connString = configuration.GetConnectionString("CouponsDb") ?? "";
    return new CampaignGeneratorService(logger, connString);
});

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Aplicar migraciones automáticamente en producción
if (app.Environment.IsProduction())
{
    using (var scope = app.Services.CreateScope())
    {
        var dbContext = scope.ServiceProvider.GetService<CampaignDbContext>();
        if (dbContext != null)
        {
            try
            {
                dbContext.Database.Migrate();
            }
            catch (Exception ex)
            {
                var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
                logger.LogError(ex, "Error applying database migrations");
            }
        }
    }
}

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors();
app.UseHttpsRedirection();
app.MapControllers();

app.Run();
