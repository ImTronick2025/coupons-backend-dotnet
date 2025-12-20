-- =============================================
-- Sample Data for Testing - Coupons Campaign System
-- Execute after schema.sql
-- =============================================

-- Enable data insertion
SET NOCOUNT ON;
GO

-- =============================================
-- Sample Campaigns
-- =============================================

-- Campaign 1: Black Friday 2025
INSERT INTO Campaigns (CampaignId, Name, Description, StartDate, EndDate, DiscountPercentage, DiscountAmount, MaxRedemptionsPerUser, MaxTotalRedemptions, IsActive, CreatedBy)
VALUES 
('CAMPAIGN-BF2025', 'Black Friday 2025', '10% de descuento en toda la tienda durante Black Friday', '2025-11-25 00:00:00', '2025-11-30 23:59:59', 10.00, NULL, 1, 10000, 1, 'admin@example.com');

-- Campaign 2: Cyber Monday
INSERT INTO Campaigns (CampaignId, Name, Description, StartDate, EndDate, DiscountPercentage, DiscountAmount, MaxRedemptionsPerUser, MaxTotalRedemptions, IsActive, CreatedBy)
VALUES 
('CAMPAIGN-CM2025', 'Cyber Monday 2025', '15% de descuento en productos seleccionados', '2025-12-01 00:00:00', '2025-12-02 23:59:59', 15.00, NULL, 1, 5000, 1, 'admin@example.com');

-- Campaign 3: New Year Special
INSERT INTO Campaigns (CampaignId, Name, Description, StartDate, EndDate, DiscountPercentage, DiscountAmount, MaxRedemptionsPerUser, MaxTotalRedemptions, IsActive, CreatedBy)
VALUES 
('CAMPAIGN-NY2026', 'New Year Special 2026', '$20 de descuento en compras mayores a $100', '2026-01-01 00:00:00', '2026-01-07 23:59:59', NULL, 20.00, 2, 3000, 1, 'admin@example.com');

-- Campaign 4: Summer Sale (Inactive for testing)
INSERT INTO Campaigns (CampaignId, Name, Description, StartDate, EndDate, DiscountPercentage, DiscountAmount, MaxRedemptionsPerUser, MaxTotalRedemptions, IsActive, CreatedBy)
VALUES 
('CAMPAIGN-SUMMER2025', 'Summer Sale 2025', '20% de descuento en ropa de verano', '2025-07-01 00:00:00', '2025-07-31 23:59:59', 20.00, NULL, 3, NULL, 0, 'admin@example.com');

-- Campaign 5: Welcome Bonus
INSERT INTO Campaigns (CampaignId, Name, Description, StartDate, EndDate, DiscountPercentage, DiscountAmount, MaxRedemptionsPerUser, MaxTotalRedemptions, IsActive, CreatedBy)
VALUES 
('CAMPAIGN-WELCOME', 'Welcome Bonus', 'Cupón de bienvenida para nuevos usuarios', '2025-01-01 00:00:00', '2026-12-31 23:59:59', 5.00, NULL, 1, NULL, 1, 'admin@example.com');

GO

-- =============================================
-- Sample Coupons for Black Friday Campaign
-- =============================================

-- Generate 50 sample coupons
DECLARE @i INT = 1;
DECLARE @CouponCode NVARCHAR(50);
DECLARE @ExpirationDate DATETIME2 = '2025-11-30 23:59:59';

WHILE @i <= 50
BEGIN
    SET @CouponCode = 'BF25-' + RIGHT('00000' + CAST(@i AS VARCHAR(5)), 5);
    
    INSERT INTO Coupons (CouponCode, CampaignId, ExpiresAt, GenerationBatchId)
    VALUES (@CouponCode, 'CAMPAIGN-BF2025', @ExpirationDate, 'BATCH-BF2025-001');
    
    SET @i = @i + 1;
END

GO

-- =============================================
-- Sample Coupons for Cyber Monday Campaign
-- =============================================

DECLARE @j INT = 1;
DECLARE @CouponCodeCM NVARCHAR(50);
DECLARE @ExpirationDateCM DATETIME2 = '2025-12-02 23:59:59';

WHILE @j <= 30
BEGIN
    SET @CouponCodeCM = 'CM25-' + RIGHT('00000' + CAST(@j AS VARCHAR(5)), 5);
    
    INSERT INTO Coupons (CouponCode, CampaignId, ExpiresAt, GenerationBatchId)
    VALUES (@CouponCodeCM, 'CAMPAIGN-CM2025', @ExpirationDateCM, 'BATCH-CM2025-001');
    
    SET @j = @j + 1;
END

GO

-- =============================================
-- Sample Coupons for New Year Campaign
-- =============================================

DECLARE @k INT = 1;
DECLARE @CouponCodeNY NVARCHAR(50);
DECLARE @ExpirationDateNY DATETIME2 = '2026-01-07 23:59:59';

WHILE @k <= 20
BEGIN
    SET @CouponCodeNY = 'NY26-' + RIGHT('00000' + CAST(@k AS VARCHAR(5)), 5);
    
    INSERT INTO Coupons (CouponCode, CampaignId, ExpiresAt, GenerationBatchId)
    VALUES (@CouponCodeNY, 'CAMPAIGN-NY2026', @ExpirationDateNY, 'BATCH-NY2026-001');
    
    SET @k = @k + 1;
END

GO

-- =============================================
-- Sample Welcome Coupons (assigned to users)
-- =============================================

INSERT INTO Coupons (CouponCode, CampaignId, ExpiresAt, AssignedTo, GenerationBatchId)
VALUES 
('WELCOME-USER001', 'CAMPAIGN-WELCOME', '2026-12-31 23:59:59', 'user-001', 'BATCH-WELCOME-001'),
('WELCOME-USER002', 'CAMPAIGN-WELCOME', '2026-12-31 23:59:59', 'user-002', 'BATCH-WELCOME-001'),
('WELCOME-USER003', 'CAMPAIGN-WELCOME', '2026-12-31 23:59:59', 'user-003', 'BATCH-WELCOME-001'),
('WELCOME-USER004', 'CAMPAIGN-WELCOME', '2026-12-31 23:59:59', 'user-004', 'BATCH-WELCOME-001'),
('WELCOME-USER005', 'CAMPAIGN-WELCOME', '2026-12-31 23:59:59', 'user-005', 'BATCH-WELCOME-001');

GO

-- =============================================
-- Simulate some redemptions
-- =============================================

-- Redeem some Black Friday coupons
DECLARE @TestUserId NVARCHAR(100) = 'user-test-001';
DECLARE @TestCouponCode NVARCHAR(50) = 'BF25-00001';
DECLARE @Success BIT;
DECLARE @Message NVARCHAR(500);
DECLARE @CampaignId NVARCHAR(100);

EXEC sp_RedeemCoupon 
    @CouponCode = @TestCouponCode,
    @UserId = @TestUserId,
    @IpAddress = '192.168.1.100',
    @UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    @Success = @Success OUTPUT,
    @Message = @Message OUTPUT,
    @CampaignId = @CampaignId OUTPUT;

-- Redeem another coupon
SET @TestUserId = 'user-test-002';
SET @TestCouponCode = 'BF25-00002';

EXEC sp_RedeemCoupon 
    @CouponCode = @TestCouponCode,
    @UserId = @TestUserId,
    @IpAddress = '192.168.1.101',
    @UserAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_0)',
    @Success = @Success OUTPUT,
    @Message = @Message OUTPUT,
    @CampaignId = @CampaignId OUTPUT;

-- Redeem Cyber Monday coupons
SET @TestUserId = 'user-test-003';
SET @TestCouponCode = 'CM25-00001';

EXEC sp_RedeemCoupon 
    @CouponCode = @TestCouponCode,
    @UserId = @TestUserId,
    @IpAddress = '192.168.1.102',
    @UserAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X)',
    @Success = @Success OUTPUT,
    @Message = @Message OUTPUT,
    @CampaignId = @CampaignId OUTPUT;

-- Redeem Welcome coupon
SET @TestUserId = 'user-001';
SET @TestCouponCode = 'WELCOME-USER001';

EXEC sp_RedeemCoupon 
    @CouponCode = @TestCouponCode,
    @UserId = @TestUserId,
    @IpAddress = '10.0.0.15',
    @UserAgent = 'Mozilla/5.0 (Android)',
    @Success = @Success OUTPUT,
    @Message = @Message OUTPUT,
    @CampaignId = @CampaignId OUTPUT;

GO

-- =============================================
-- Sample failed redemption attempts
-- =============================================

-- Attempt to redeem already redeemed coupon
DECLARE @FailUserId NVARCHAR(100) = 'user-test-999';
DECLARE @FailCouponCode NVARCHAR(50) = 'BF25-00001'; -- Already redeemed
DECLARE @FailSuccess BIT;
DECLARE @FailMessage NVARCHAR(500);
DECLARE @FailCampaignId NVARCHAR(100);

EXEC sp_RedeemCoupon 
    @CouponCode = @FailCouponCode,
    @UserId = @FailUserId,
    @IpAddress = '192.168.1.200',
    @UserAgent = 'Mozilla/5.0',
    @Success = @FailSuccess OUTPUT,
    @Message = @FailMessage OUTPUT,
    @CampaignId = @FailCampaignId OUTPUT;

-- Attempt to redeem non-existent coupon
SET @FailCouponCode = 'INVALID-COUPON';

EXEC sp_RedeemCoupon 
    @CouponCode = @FailCouponCode,
    @UserId = @FailUserId,
    @IpAddress = '192.168.1.200',
    @UserAgent = 'Mozilla/5.0',
    @Success = @FailSuccess OUTPUT,
    @Message = @FailMessage OUTPUT,
    @CampaignId = @FailCampaignId OUTPUT;

-- Attempt to redeem coupon assigned to different user
SET @FailUserId = 'user-hacker-001';
SET @FailCouponCode = 'WELCOME-USER002'; -- Assigned to user-002

EXEC sp_RedeemCoupon 
    @CouponCode = @FailCouponCode,
    @UserId = @FailUserId,
    @IpAddress = '192.168.1.200',
    @UserAgent = 'Mozilla/5.0',
    @Success = @FailSuccess OUTPUT,
    @Message = @FailMessage OUTPUT,
    @CampaignId = @FailCampaignId OUTPUT;

GO

-- =============================================
-- Sample Generation Requests
-- =============================================

INSERT INTO GenerationRequests (RequestId, CampaignId, RequestedAmount, GeneratedAmount, Prefix, ExpirationDate, Status, StartedAt, CompletedAt, RequestedBy)
VALUES 
('gen-req-bf2025-001', 'CAMPAIGN-BF2025', 50, 50, 'BF25', '2025-11-30 23:59:59', 'completed', DATEADD(HOUR, -24, GETUTCDATE()), DATEADD(HOUR, -23, GETUTCDATE()), 'admin@example.com'),
('gen-req-cm2025-001', 'CAMPAIGN-CM2025', 30, 30, 'CM25', '2025-12-02 23:59:59', 'completed', DATEADD(HOUR, -12, GETUTCDATE()), DATEADD(HOUR, -11, GETUTCDATE()), 'admin@example.com'),
('gen-req-ny2026-001', 'CAMPAIGN-NY2026', 20, 20, 'NY26', '2026-01-07 23:59:59', 'completed', DATEADD(HOUR, -6, GETUTCDATE()), DATEADD(HOUR, -5, GETUTCDATE()), 'admin@example.com'),
('gen-req-welcome-001', 'CAMPAIGN-WELCOME', 5, 5, 'WELCOME', '2026-12-31 23:59:59', 'completed', DATEADD(HOUR, -2, GETUTCDATE()), DATEADD(HOUR, -1, GETUTCDATE()), 'admin@example.com'),
('gen-req-pending-001', 'CAMPAIGN-BF2025', 1000, 0, 'BF25', '2025-11-30 23:59:59', 'pending', NULL, NULL, 'admin@example.com');

GO

-- =============================================
-- Verification Queries
-- =============================================

PRINT '==============================================';
PRINT 'Data Inserted Successfully!';
PRINT '==============================================';
PRINT '';

PRINT 'Total Campaigns: ';
SELECT COUNT(*) AS TotalCampaigns FROM Campaigns;
PRINT '';

PRINT 'Total Coupons: ';
SELECT COUNT(*) AS TotalCoupons FROM Coupons;
PRINT '';

PRINT 'Total Redeemed: ';
SELECT COUNT(*) AS TotalRedeemed FROM Coupons WHERE IsRedeemed = 1;
PRINT '';

PRINT 'Total Redemption Attempts (History): ';
SELECT COUNT(*) AS TotalAttempts FROM RedemptionHistory;
PRINT '';

PRINT 'Failed Redemption Attempts: ';
SELECT COUNT(*) AS FailedAttempts FROM RedemptionHistory WHERE Success = 0;
PRINT '';

PRINT 'Active Campaigns: ';
SELECT * FROM vw_ActiveCampaigns;
PRINT '';

PRINT 'Redemption Statistics: ';
SELECT * FROM vw_RedemptionStats;
PRINT '';

PRINT '==============================================';
PRINT 'Sample Data Setup Complete!';
PRINT '==============================================';

GO
