using System.Security.Cryptography;
using System.Text;
using Microsoft.Data.SqlClient;
using System.Data;

Console.WriteLine("=== Coupon Generator Job (ACI) ===");

var amount = int.TryParse(Environment.GetEnvironmentVariable("AMOUNT"), out var a) ? a : 100;
var prefix = Environment.GetEnvironmentVariable("PREFIX") ?? "COUPON";
var campaignId = Environment.GetEnvironmentVariable("CAMPAIGN_ID") ?? "default-campaign";
var connectionString = Environment.GetEnvironmentVariable("SQL_CONNECTION_STRING");
var expirationDate = DateTime.TryParse(Environment.GetEnvironmentVariable("EXPIRATION_DATE"), out var exp) 
    ? exp : DateTime.UtcNow.AddYears(1);

Console.WriteLine($"Campaign ID: {campaignId}");
Console.WriteLine($"Prefix: {prefix}");
Console.WriteLine($"Amount: {amount}");
Console.WriteLine($"Expiration: {expirationDate:O}");
Console.WriteLine($"Starting generation at {DateTime.UtcNow:O}");

var coupons = new List<CouponData>();
var duplicates = 0;
var generatedCodes = new HashSet<string>();
var batchId = Guid.NewGuid().ToString("N");

// Generar cupones
for (int i = 0; i < amount; i++)
{
    var couponCode = GenerateCoupon(prefix);
    
    if (!generatedCodes.Add(couponCode))
    {
        duplicates++;
        i--;
        continue;
    }

    coupons.Add(new CouponData
    {
        CouponCode = couponCode,
        CampaignId = campaignId,
        ExpiresAt = expirationDate,
        GenerationBatchId = batchId
    });

    if ((i + 1) % 10000 == 0)
    {
        Console.WriteLine($"Generated {i + 1:N0} coupons...");
    }
}

Console.WriteLine($"Generation completed at {DateTime.UtcNow:O}");
Console.WriteLine($"Total generated: {coupons.Count:N0}");
Console.WriteLine($"Duplicates avoided: {duplicates}");

// Insertar en base de datos si hay connection string
if (!string.IsNullOrEmpty(connectionString))
{
    Console.WriteLine("Inserting coupons into database...");
    
    try
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        
        var totalInserted = 0;
        var batchSize = 1000;
        
        for (int i = 0; i < coupons.Count; i += batchSize)
        {
            var batch = coupons.Skip(i).Take(batchSize).ToList();
            
            var dataTable = new DataTable();
            dataTable.Columns.Add("CouponCode", typeof(string));
            dataTable.Columns.Add("CampaignId", typeof(string));
            dataTable.Columns.Add("ExpiresAt", typeof(DateTime));
            dataTable.Columns.Add("GenerationBatchId", typeof(string));
            dataTable.Columns.Add("CreatedAt", typeof(DateTime));
            
            foreach (var coupon in batch)
            {
                dataTable.Rows.Add(
                    coupon.CouponCode,
                    coupon.CampaignId,
                    coupon.ExpiresAt,
                    coupon.GenerationBatchId,
                    DateTime.UtcNow
                );
            }
            
            using var bulkCopy = new SqlBulkCopy(connection);
            bulkCopy.DestinationTableName = "Coupons";
            bulkCopy.ColumnMappings.Add("CouponCode", "CouponCode");
            bulkCopy.ColumnMappings.Add("CampaignId", "CampaignId");
            bulkCopy.ColumnMappings.Add("ExpiresAt", "ExpiresAt");
            bulkCopy.ColumnMappings.Add("GenerationBatchId", "GenerationBatchId");
            bulkCopy.ColumnMappings.Add("CreatedAt", "CreatedAt");
            
            await bulkCopy.WriteToServerAsync(dataTable);
            
            totalInserted += batch.Count;
            Console.WriteLine($"Inserted {totalInserted:N0}/{coupons.Count:N0} coupons...");
        }
        
        Console.WriteLine($"Successfully inserted {totalInserted:N0} coupons into database");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"ERROR inserting coupons: {ex.Message}");
        Console.WriteLine(ex.StackTrace);
        Environment.Exit(1);
    }
}
else
{
    Console.WriteLine("WARNING: No SQL_CONNECTION_STRING provided. Coupons not persisted to database.");
    Console.WriteLine("Sample coupons:");
    foreach (var coupon in coupons.Take(10))
    {
        Console.WriteLine($"  - {coupon.CouponCode}");
    }
}

Console.WriteLine("Job completed successfully");

static string GenerateCoupon(string prefix)
{
    var guid = Guid.NewGuid().ToString("N")[..12].ToUpperInvariant();
    var checksum = CalculateChecksum($"{prefix}{guid}");
    return $"{prefix}-{guid}-{checksum}";
}

static string CalculateChecksum(string input)
{
    using var sha = SHA256.Create();
    var hash = sha.ComputeHash(Encoding.UTF8.GetBytes(input));
    return Convert.ToHexString(hash)[..4];
}

class CouponData
{
    public string CouponCode { get; set; } = string.Empty;
    public string CampaignId { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public string GenerationBatchId { get; set; } = string.Empty;
}
