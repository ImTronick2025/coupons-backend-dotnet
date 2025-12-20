-- =============================================
-- Stored Procedure: sp_GenerateCoupons
-- Purpose: Generate coupons in bulk
-- =============================================
GO
CREATE OR ALTER PROCEDURE sp_GenerateCoupons
    @CampaignId NVARCHAR(100),
    @Prefix NVARCHAR(20),
    @Amount INT,
    @ExpiresAt DATETIME2,
    @GenerationBatchId NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Counter INT = 1;
    DECLARE @CouponCode NVARCHAR(50);
    DECLARE @MaxExisting INT;
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        -- Get the highest existing coupon number for this prefix
        SELECT @MaxExisting = ISNULL(MAX(
            CAST(SUBSTRING(CouponCode, LEN(@Prefix) + 2, LEN(CouponCode)) AS INT)
        ), 0)
        FROM Coupons
        WHERE CouponCode LIKE @Prefix + '-%';
        
        -- Start from next available number
        SET @Counter = @MaxExisting + 1;
        
        -- Generate coupons
        WHILE @Counter <= (@MaxExisting + @Amount)
        BEGIN
            SET @CouponCode = @Prefix + '-' + RIGHT('00000' + CAST(@Counter AS NVARCHAR), 5);
            
            -- Insert coupon
            INSERT INTO Coupons (CouponCode, CampaignId, ExpiresAt, GenerationBatchId, IsRedeemed)
            VALUES (@CouponCode, @CampaignId, @ExpiresAt, @GenerationBatchId, 0);
            
            SET @Counter = @Counter + 1;
        END
        
        COMMIT TRANSACTION;
        
        -- Return count of generated coupons
        SELECT @Amount AS GeneratedCount;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        THROW;
    END CATCH
END
GO
