-- =============================================
-- Verification and Testing Queries
-- Coupons Campaign System
-- =============================================

-- =============================================
-- 1. Database Overview
-- =============================================
PRINT '==============================================';
PRINT '1. DATABASE OVERVIEW';
PRINT '==============================================';
PRINT '';

SELECT 
    'Campaigns' AS TableName, 
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END) AS ActiveRecords
FROM Campaigns
UNION ALL
SELECT 
    'Coupons', 
    COUNT(*),
    SUM(CASE WHEN IsRedeemed = 0 AND GETUTCDATE() <= ExpiresAt THEN 1 ELSE 0 END)
FROM Coupons
UNION ALL
SELECT 
    'RedemptionHistory', 
    COUNT(*),
    SUM(CASE WHEN Success = 1 THEN 1 ELSE 0 END)
FROM RedemptionHistory
UNION ALL
SELECT 
    'GenerationRequests', 
    COUNT(*),
    SUM(CASE WHEN Status = 'completed' THEN 1 ELSE 0 END)
FROM GenerationRequests
UNION ALL
SELECT 
    'UserRedemptions', 
    COUNT(*),
    COUNT(DISTINCT UserId)
FROM UserRedemptions;

PRINT '';

-- =============================================
-- 2. Active Campaigns
-- =============================================
PRINT '==============================================';
PRINT '2. ACTIVE CAMPAIGNS';
PRINT '==============================================';
PRINT '';

SELECT * FROM vw_ActiveCampaigns;

PRINT '';

-- =============================================
-- 3. Coupon Statistics by Campaign
-- =============================================
PRINT '==============================================';
PRINT '3. COUPON STATISTICS BY CAMPAIGN';
PRINT '==============================================';
PRINT '';

SELECT * FROM vw_RedemptionStats;

PRINT '';

-- =============================================
-- 4. Recent Redemption History
-- =============================================
PRINT '==============================================';
PRINT '4. RECENT REDEMPTION HISTORY (Last 10)';
PRINT '==============================================';
PRINT '';

SELECT TOP 10
    RedemptionId,
    CouponCode,
    UserId,
    CampaignId,
    AttemptedAt,
    Success,
    FailureReason,
    IpAddress
FROM RedemptionHistory
ORDER BY AttemptedAt DESC;

PRINT '';

-- =============================================
-- 5. User Redemption Summary
-- =============================================
PRINT '==============================================';
PRINT '5. USER REDEMPTION SUMMARY';
PRINT '==============================================';
PRINT '';

SELECT 
    ur.UserId,
    c.Name AS CampaignName,
    ur.RedemptionCount,
    ur.LastRedeemedAt,
    camp.MaxRedemptionsPerUser,
    CASE 
        WHEN ur.RedemptionCount >= camp.MaxRedemptionsPerUser THEN 'At Limit'
        ELSE 'Available'
    END AS Status
FROM UserRedemptions ur
INNER JOIN Campaigns camp ON ur.CampaignId = camp.CampaignId
LEFT JOIN Campaigns c ON ur.CampaignId = c.CampaignId
ORDER BY ur.LastRedeemedAt DESC;

PRINT '';

-- =============================================
-- 6. Generation Requests Status
-- =============================================
PRINT '==============================================';
PRINT '6. GENERATION REQUESTS STATUS';
PRINT '==============================================';
PRINT '';

SELECT 
    gr.RequestId,
    c.Name AS CampaignName,
    gr.RequestedAmount,
    gr.GeneratedAmount,
    gr.Prefix,
    gr.Status,
    gr.CreatedAt,
    gr.CompletedAt,
    DATEDIFF(SECOND, gr.StartedAt, gr.CompletedAt) AS DurationSeconds,
    gr.RequestedBy
FROM GenerationRequests gr
LEFT JOIN Campaigns c ON gr.CampaignId = c.CampaignId
ORDER BY gr.CreatedAt DESC;

PRINT '';

-- =============================================
-- 7. TEST STORED PROCEDURES
-- =============================================
PRINT '==============================================';
PRINT '7. TEST STORED PROCEDURES';
PRINT '==============================================';
PRINT '';

-- Test: Get Coupon Details
PRINT 'Test 1: Get Coupon Details for BF25-00005';
EXEC sp_GetCouponDetails @CouponCode = 'BF25-00005';

PRINT '';

-- Test: Try to redeem a valid coupon
PRINT 'Test 2: Redeem valid coupon BF25-00010';
DECLARE @Success BIT, @Message NVARCHAR(500), @CampaignId NVARCHAR(100);
EXEC sp_RedeemCoupon 
    @CouponCode = 'BF25-00010',
    @UserId = 'test-user-verification',
    @IpAddress = '10.0.0.100',
    @UserAgent = 'TestAgent/1.0',
    @Success = @Success OUTPUT,
    @Message = @Message OUTPUT,
    @CampaignId = @CampaignId OUTPUT;

SELECT 
    @Success AS Success, 
    @Message AS Message, 
    @CampaignId AS CampaignId;

PRINT '';

-- Test: Try to redeem already redeemed coupon
PRINT 'Test 3: Attempt to redeem already redeemed coupon BF25-00010';
EXEC sp_RedeemCoupon 
    @CouponCode = 'BF25-00010',
    @UserId = 'another-user',
    @Success = @Success OUTPUT,
    @Message = @Message OUTPUT,
    @CampaignId = @CampaignId OUTPUT;

SELECT 
    @Success AS Success, 
    @Message AS Message;

PRINT '';

-- Test: Try to redeem invalid coupon
PRINT 'Test 4: Attempt to redeem invalid coupon';
EXEC sp_RedeemCoupon 
    @CouponCode = 'INVALID-CODE-999',
    @UserId = 'test-user',
    @Success = @Success OUTPUT,
    @Message = @Message OUTPUT,
    @CampaignId = @CampaignId OUTPUT;

SELECT 
    @Success AS Success, 
    @Message AS Message;

PRINT '';

-- =============================================
-- 8. FRAUD DETECTION - Suspicious Activity
-- =============================================
PRINT '==============================================';
PRINT '8. FRAUD DETECTION - SUSPICIOUS ACTIVITY';
PRINT '==============================================';
PRINT '';

-- Users with multiple failed attempts
PRINT 'Users with multiple failed redemption attempts:';
SELECT 
    UserId,
    COUNT(*) AS FailedAttempts,
    MAX(AttemptedAt) AS LastAttempt,
    COUNT(DISTINCT IpAddress) AS DistinctIPs
FROM RedemptionHistory
WHERE Success = 0
GROUP BY UserId
HAVING COUNT(*) >= 2
ORDER BY FailedAttempts DESC;

PRINT '';

-- Multiple attempts from same IP
PRINT 'IPs with multiple redemption attempts:';
SELECT 
    IpAddress,
    COUNT(*) AS TotalAttempts,
    SUM(CASE WHEN Success = 1 THEN 1 ELSE 0 END) AS SuccessfulAttempts,
    COUNT(DISTINCT UserId) AS DistinctUsers
FROM RedemptionHistory
WHERE IpAddress IS NOT NULL
GROUP BY IpAddress
HAVING COUNT(*) > 1
ORDER BY TotalAttempts DESC;

PRINT '';

-- =============================================
-- 9. PERFORMANCE METRICS
-- =============================================
PRINT '==============================================';
PRINT '9. PERFORMANCE METRICS';
PRINT '==============================================';
PRINT '';

-- Campaign performance
SELECT 
    c.CampaignId,
    c.Name,
    c.MaxTotalRedemptions,
    c.CurrentRedemptions,
    CASE 
        WHEN c.MaxTotalRedemptions IS NOT NULL 
        THEN CAST(c.CurrentRedemptions AS FLOAT) / c.MaxTotalRedemptions * 100
        ELSE NULL
    END AS RedemptionPercentage,
    (SELECT COUNT(*) FROM Coupons WHERE CampaignId = c.CampaignId) AS TotalCoupons,
    (SELECT COUNT(*) FROM Coupons WHERE CampaignId = c.CampaignId AND IsRedeemed = 1) AS RedeemedCoupons,
    DATEDIFF(DAY, c.StartDate, c.EndDate) AS CampaignDurationDays,
    DATEDIFF(DAY, GETUTCDATE(), c.EndDate) AS DaysRemaining
FROM Campaigns c
WHERE c.IsActive = 1
ORDER BY RedemptionPercentage DESC;

PRINT '';

-- =============================================
-- 10. DATA QUALITY CHECKS
-- =============================================
PRINT '==============================================';
PRINT '10. DATA QUALITY CHECKS';
PRINT '==============================================';
PRINT '';

-- Check for orphaned coupons (shouldn't exist due to FK)
SELECT COUNT(*) AS OrphanedCoupons
FROM Coupons c
LEFT JOIN Campaigns camp ON c.CampaignId = camp.CampaignId
WHERE camp.CampaignId IS NULL;

-- Check for expired but not redeemed coupons
SELECT COUNT(*) AS ExpiredUnredeemedCoupons
FROM Coupons
WHERE IsRedeemed = 0 AND ExpiresAt < GETUTCDATE();

-- Check for redemptions without history (data inconsistency)
SELECT 
    (SELECT COUNT(*) FROM Coupons WHERE IsRedeemed = 1) AS TotalRedeemed,
    (SELECT COUNT(*) FROM RedemptionHistory WHERE Success = 1) AS TotalSuccessfulAttempts,
    (SELECT COUNT(*) FROM Coupons WHERE IsRedeemed = 1) - 
    (SELECT COUNT(*) FROM RedemptionHistory WHERE Success = 1) AS Discrepancy;

PRINT '';
PRINT '==============================================';
PRINT 'VERIFICATION COMPLETE!';
PRINT '==============================================';

GO
