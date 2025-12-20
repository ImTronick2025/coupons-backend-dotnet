-- =============================================
-- Coupons Campaign System - Azure SQL Database Schema
-- Target: Azure SQL Database
-- .NET 8 Backend
-- =============================================

-- =============================================
-- Table: Campaigns
-- Purpose: Store promotional campaigns
-- =============================================
CREATE TABLE Campaigns (
    CampaignId NVARCHAR(100) PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    Description NVARCHAR(1000) NULL,
    StartDate DATETIME2 NOT NULL,
    EndDate DATETIME2 NOT NULL,
    DiscountPercentage DECIMAL(5,2) NULL,
    DiscountAmount DECIMAL(10,2) NULL,
    MaxRedemptionsPerUser INT NOT NULL DEFAULT 1,
    MaxTotalRedemptions INT NULL,
    CurrentRedemptions INT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CreatedBy NVARCHAR(100) NULL,
    
    INDEX IX_Campaigns_IsActive (IsActive),
    INDEX IX_Campaigns_Dates (StartDate, EndDate)
);

-- =============================================
-- Table: Coupons
-- Purpose: Store individual coupon codes
-- =============================================
CREATE TABLE Coupons (
    CouponId BIGINT IDENTITY(1,1) PRIMARY KEY,
    CouponCode NVARCHAR(50) NOT NULL UNIQUE,
    CampaignId NVARCHAR(100) NOT NULL,
    IsRedeemed BIT NOT NULL DEFAULT 0,
    RedeemedAt DATETIME2 NULL,
    RedeemedBy NVARCHAR(100) NULL,
    ExpiresAt DATETIME2 NOT NULL,
    AssignedTo NVARCHAR(100) NULL,
    GenerationBatchId NVARCHAR(100) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_Coupons_Campaign FOREIGN KEY (CampaignId) 
        REFERENCES Campaigns(CampaignId) ON DELETE CASCADE,
    
    INDEX IX_Coupons_Code (CouponCode),
    INDEX IX_Coupons_Campaign (CampaignId),
    INDEX IX_Coupons_IsRedeemed (IsRedeemed),
    INDEX IX_Coupons_ExpiresAt (ExpiresAt),
    INDEX IX_Coupons_RedeemedBy (RedeemedBy),
    INDEX IX_Coupons_AssignedTo (AssignedTo),
    INDEX IX_Coupons_GenerationBatch (GenerationBatchId)
);

-- =============================================
-- Table: RedemptionHistory
-- Purpose: Audit trail for all redemption attempts
-- =============================================
CREATE TABLE RedemptionHistory (
    RedemptionId BIGINT IDENTITY(1,1) PRIMARY KEY,
    CouponCode NVARCHAR(50) NOT NULL,
    UserId NVARCHAR(100) NOT NULL,
    CampaignId NVARCHAR(100) NULL,
    AttemptedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    Success BIT NOT NULL,
    FailureReason NVARCHAR(500) NULL,
    IpAddress NVARCHAR(45) NULL,
    UserAgent NVARCHAR(500) NULL,
    
    INDEX IX_RedemptionHistory_UserId (UserId),
    INDEX IX_RedemptionHistory_CouponCode (CouponCode),
    INDEX IX_RedemptionHistory_AttemptedAt (AttemptedAt),
    INDEX IX_RedemptionHistory_Success (Success)
);

-- =============================================
-- Table: GenerationRequests
-- Purpose: Track bulk coupon generation requests
-- =============================================
CREATE TABLE GenerationRequests (
    RequestId NVARCHAR(100) PRIMARY KEY,
    CampaignId NVARCHAR(100) NOT NULL,
    RequestedAmount INT NOT NULL,
    GeneratedAmount INT NOT NULL DEFAULT 0,
    Prefix NVARCHAR(20) NULL,
    ExpirationDate DATETIME2 NOT NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, running, completed, failed
    StartedAt DATETIME2 NULL,
    CompletedAt DATETIME2 NULL,
    FailureReason NVARCHAR(1000) NULL,
    RequestedBy NVARCHAR(100) NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_GenerationRequests_Campaign FOREIGN KEY (CampaignId) 
        REFERENCES Campaigns(CampaignId) ON DELETE CASCADE,
    
    INDEX IX_GenerationRequests_Status (Status),
    INDEX IX_GenerationRequests_Campaign (CampaignId),
    INDEX IX_GenerationRequests_CreatedAt (CreatedAt)
);

-- =============================================
-- Table: UserRedemptions
-- Purpose: Track redemptions per user per campaign (fraud control)
-- =============================================
CREATE TABLE UserRedemptions (
    UserRedemptionId BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId NVARCHAR(100) NOT NULL,
    CampaignId NVARCHAR(100) NOT NULL,
    RedemptionCount INT NOT NULL DEFAULT 0,
    LastRedeemedAt DATETIME2 NULL,
    
    CONSTRAINT FK_UserRedemptions_Campaign FOREIGN KEY (CampaignId) 
        REFERENCES Campaigns(CampaignId) ON DELETE CASCADE,
    
    CONSTRAINT UQ_UserRedemptions UNIQUE (UserId, CampaignId),
    
    INDEX IX_UserRedemptions_UserId (UserId),
    INDEX IX_UserRedemptions_Campaign (CampaignId)
);

-- =============================================
-- Stored Procedures
-- =============================================

-- SP: Redeem Coupon (with fraud control)
GO
CREATE OR ALTER PROCEDURE sp_RedeemCoupon
    @CouponCode NVARCHAR(50),
    @UserId NVARCHAR(100),
    @IpAddress NVARCHAR(45) = NULL,
    @UserAgent NVARCHAR(500) = NULL,
    @Success BIT OUTPUT,
    @Message NVARCHAR(500) OUTPUT,
    @CampaignId NVARCHAR(100) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        DECLARE @IsRedeemed BIT;
        DECLARE @ExpiresAt DATETIME2;
        DECLARE @AssignedTo NVARCHAR(100);
        DECLARE @MaxRedemptionsPerUser INT;
        DECLARE @CurrentUserRedemptions INT;
        DECLARE @IsActive BIT;
        DECLARE @CampaignEndDate DATETIME2;
        DECLARE @MaxTotalRedemptions INT;
        DECLARE @CurrentTotalRedemptions INT;
        
        -- Check if coupon exists
        SELECT 
            @CampaignId = c.CampaignId,
            @IsRedeemed = c.IsRedeemed,
            @ExpiresAt = c.ExpiresAt,
            @AssignedTo = c.AssignedTo,
            @IsActive = camp.IsActive,
            @CampaignEndDate = camp.EndDate,
            @MaxRedemptionsPerUser = camp.MaxRedemptionsPerUser,
            @MaxTotalRedemptions = camp.MaxTotalRedemptions,
            @CurrentTotalRedemptions = camp.CurrentRedemptions
        FROM Coupons c
        INNER JOIN Campaigns camp ON c.CampaignId = camp.CampaignId
        WHERE c.CouponCode = @CouponCode;
        
        -- Coupon not found
        IF @CampaignId IS NULL
        BEGIN
            SET @Success = 0;
            SET @Message = 'Coupon not found';
            
            INSERT INTO RedemptionHistory (CouponCode, UserId, AttemptedAt, Success, FailureReason, IpAddress, UserAgent)
            VALUES (@CouponCode, @UserId, GETUTCDATE(), 0, @Message, @IpAddress, @UserAgent);
            
            COMMIT TRANSACTION;
            RETURN;
        END
        
        -- Campaign not active
        IF @IsActive = 0
        BEGIN
            SET @Success = 0;
            SET @Message = 'Campaign is not active';
            
            INSERT INTO RedemptionHistory (CouponCode, UserId, CampaignId, AttemptedAt, Success, FailureReason, IpAddress, UserAgent)
            VALUES (@CouponCode, @UserId, @CampaignId, GETUTCDATE(), 0, @Message, @IpAddress, @UserAgent);
            
            COMMIT TRANSACTION;
            RETURN;
        END
        
        -- Already redeemed
        IF @IsRedeemed = 1
        BEGIN
            SET @Success = 0;
            SET @Message = 'Coupon already redeemed';
            
            INSERT INTO RedemptionHistory (CouponCode, UserId, CampaignId, AttemptedAt, Success, FailureReason, IpAddress, UserAgent)
            VALUES (@CouponCode, @UserId, @CampaignId, GETUTCDATE(), 0, @Message, @IpAddress, @UserAgent);
            
            COMMIT TRANSACTION;
            RETURN;
        END
        
        -- Coupon expired
        IF GETUTCDATE() > @ExpiresAt OR GETUTCDATE() > @CampaignEndDate
        BEGIN
            SET @Success = 0;
            SET @Message = 'Coupon expired';
            
            INSERT INTO RedemptionHistory (CouponCode, UserId, CampaignId, AttemptedAt, Success, FailureReason, IpAddress, UserAgent)
            VALUES (@CouponCode, @UserId, @CampaignId, GETUTCDATE(), 0, @Message, @IpAddress, @UserAgent);
            
            COMMIT TRANSACTION;
            RETURN;
        END
        
        -- Assigned to different user
        IF @AssignedTo IS NOT NULL AND @AssignedTo != @UserId
        BEGIN
            SET @Success = 0;
            SET @Message = 'Coupon assigned to different user';
            
            INSERT INTO RedemptionHistory (CouponCode, UserId, CampaignId, AttemptedAt, Success, FailureReason, IpAddress, UserAgent)
            VALUES (@CouponCode, @UserId, @CampaignId, GETUTCDATE(), 0, @Message, @IpAddress, @UserAgent);
            
            COMMIT TRANSACTION;
            RETURN;
        END
        
        -- Check max total redemptions
        IF @MaxTotalRedemptions IS NOT NULL AND @CurrentTotalRedemptions >= @MaxTotalRedemptions
        BEGIN
            SET @Success = 0;
            SET @Message = 'Campaign redemption limit reached';
            
            INSERT INTO RedemptionHistory (CouponCode, UserId, CampaignId, AttemptedAt, Success, FailureReason, IpAddress, UserAgent)
            VALUES (@CouponCode, @UserId, @CampaignId, GETUTCDATE(), 0, @Message, @IpAddress, @UserAgent);
            
            COMMIT TRANSACTION;
            RETURN;
        END
        
        -- Check user redemption limit
        SELECT @CurrentUserRedemptions = ISNULL(RedemptionCount, 0)
        FROM UserRedemptions
        WHERE UserId = @UserId AND CampaignId = @CampaignId;
        
        IF @CurrentUserRedemptions >= @MaxRedemptionsPerUser
        BEGIN
            SET @Success = 0;
            SET @Message = 'User redemption limit reached for this campaign';
            
            INSERT INTO RedemptionHistory (CouponCode, UserId, CampaignId, AttemptedAt, Success, FailureReason, IpAddress, UserAgent)
            VALUES (@CouponCode, @UserId, @CampaignId, GETUTCDATE(), 0, @Message, @IpAddress, @UserAgent);
            
            COMMIT TRANSACTION;
            RETURN;
        END
        
        -- Redeem coupon
        UPDATE Coupons
        SET IsRedeemed = 1,
            RedeemedAt = GETUTCDATE(),
            RedeemedBy = @UserId
        WHERE CouponCode = @CouponCode;
        
        -- Update campaign redemption count
        UPDATE Campaigns
        SET CurrentRedemptions = CurrentRedemptions + 1,
            UpdatedAt = GETUTCDATE()
        WHERE CampaignId = @CampaignId;
        
        -- Update user redemptions
        IF EXISTS (SELECT 1 FROM UserRedemptions WHERE UserId = @UserId AND CampaignId = @CampaignId)
        BEGIN
            UPDATE UserRedemptions
            SET RedemptionCount = RedemptionCount + 1,
                LastRedeemedAt = GETUTCDATE()
            WHERE UserId = @UserId AND CampaignId = @CampaignId;
        END
        ELSE
        BEGIN
            INSERT INTO UserRedemptions (UserId, CampaignId, RedemptionCount, LastRedeemedAt)
            VALUES (@UserId, @CampaignId, 1, GETUTCDATE());
        END
        
        -- Log success
        INSERT INTO RedemptionHistory (CouponCode, UserId, CampaignId, AttemptedAt, Success, IpAddress, UserAgent)
        VALUES (@CouponCode, @UserId, @CampaignId, GETUTCDATE(), 1, @IpAddress, @UserAgent);
        
        SET @Success = 1;
        SET @Message = 'Coupon redeemed successfully';
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        SET @Success = 0;
        SET @Message = ERROR_MESSAGE();
        
        -- Log error
        INSERT INTO RedemptionHistory (CouponCode, UserId, CampaignId, AttemptedAt, Success, FailureReason, IpAddress, UserAgent)
        VALUES (@CouponCode, @UserId, @CampaignId, GETUTCDATE(), 0, @Message, @IpAddress, @UserAgent);
    END CATCH
END
GO

-- SP: Get Coupon Details
GO
CREATE OR ALTER PROCEDURE sp_GetCouponDetails
    @CouponCode NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        c.CouponCode,
        c.CampaignId,
        CAST(c.IsRedeemed AS BIT) AS Redeemed,
        c.RedeemedAt,
        c.RedeemedBy,
        c.ExpiresAt,
        c.AssignedTo,
        CAST(CASE 
            WHEN c.IsRedeemed = 1 THEN 0
            WHEN GETUTCDATE() > c.ExpiresAt THEN 0
            WHEN GETUTCDATE() > camp.EndDate THEN 0
            WHEN camp.IsActive = 0 THEN 0
            ELSE 1
        END AS BIT) AS Valid
    FROM Coupons c
    INNER JOIN Campaigns camp ON c.CampaignId = camp.CampaignId
    WHERE c.CouponCode = @CouponCode;
END
GO

-- SP: Create Generation Request
GO
CREATE OR ALTER PROCEDURE sp_CreateGenerationRequest
    @RequestId NVARCHAR(100),
    @CampaignId NVARCHAR(100),
    @Amount INT,
    @Prefix NVARCHAR(20),
    @ExpirationDate DATETIME2,
    @RequestedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO GenerationRequests (RequestId, CampaignId, RequestedAmount, Prefix, ExpirationDate, RequestedBy, Status)
    VALUES (@RequestId, @CampaignId, @Amount, @Prefix, @ExpirationDate, @RequestedBy, 'pending');
    
    SELECT RequestId, CampaignId, RequestedAmount, Status, CreatedAt
    FROM GenerationRequests
    WHERE RequestId = @RequestId;
END
GO

-- SP: Update Generation Request Status
GO
CREATE OR ALTER PROCEDURE sp_UpdateGenerationRequest
    @RequestId NVARCHAR(100),
    @Status NVARCHAR(20),
    @GeneratedAmount INT = NULL,
    @FailureReason NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE GenerationRequests
    SET Status = @Status,
        GeneratedAmount = ISNULL(@GeneratedAmount, GeneratedAmount),
        FailureReason = @FailureReason,
        StartedAt = CASE WHEN @Status = 'running' AND StartedAt IS NULL THEN GETUTCDATE() ELSE StartedAt END,
        CompletedAt = CASE WHEN @Status IN ('completed', 'failed') THEN GETUTCDATE() ELSE CompletedAt END
    WHERE RequestId = @RequestId;
END
GO

-- SP: Bulk Insert Coupons (for ACI job)
GO
CREATE OR ALTER PROCEDURE sp_BulkInsertCoupons
    @CouponsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRANSACTION;
    
    BEGIN TRY
        INSERT INTO Coupons (CouponCode, CampaignId, ExpiresAt, AssignedTo, GenerationBatchId)
        SELECT 
            CouponCode,
            CampaignId,
            ExpiresAt,
            AssignedTo,
            GenerationBatchId
        FROM OPENJSON(@CouponsJson)
        WITH (
            CouponCode NVARCHAR(50) '$.couponCode',
            CampaignId NVARCHAR(100) '$.campaignId',
            ExpiresAt DATETIME2 '$.expiresAt',
            AssignedTo NVARCHAR(100) '$.assignedTo',
            GenerationBatchId NVARCHAR(100) '$.generationBatchId'
        );
        
        COMMIT TRANSACTION;
        
        SELECT @@ROWCOUNT AS InsertedCount;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- =============================================
-- Views
-- =============================================

-- View: Active Campaigns
GO
CREATE OR ALTER VIEW vw_ActiveCampaigns AS
SELECT 
    CampaignId,
    Name,
    Description,
    StartDate,
    EndDate,
    DiscountPercentage,
    DiscountAmount,
    MaxRedemptionsPerUser,
    MaxTotalRedemptions,
    CurrentRedemptions,
    CASE 
        WHEN MaxTotalRedemptions IS NOT NULL 
        THEN CAST(CurrentRedemptions AS FLOAT) / MaxTotalRedemptions * 100
        ELSE NULL
    END AS RedemptionPercentage,
    CreatedAt
FROM Campaigns
WHERE IsActive = 1 
  AND GETUTCDATE() BETWEEN StartDate AND EndDate;
GO

-- View: Redemption Statistics
GO
CREATE OR ALTER VIEW vw_RedemptionStats AS
SELECT 
    c.CampaignId,
    camp.Name AS CampaignName,
    COUNT(*) AS TotalCoupons,
    SUM(CASE WHEN c.IsRedeemed = 1 THEN 1 ELSE 0 END) AS RedeemedCoupons,
    SUM(CASE WHEN c.IsRedeemed = 0 AND GETUTCDATE() <= c.ExpiresAt THEN 1 ELSE 0 END) AS AvailableCoupons,
    SUM(CASE WHEN c.IsRedeemed = 0 AND GETUTCDATE() > c.ExpiresAt THEN 1 ELSE 0 END) AS ExpiredCoupons
FROM Coupons c
INNER JOIN Campaigns camp ON c.CampaignId = camp.CampaignId
GROUP BY c.CampaignId, camp.Name;
GO
