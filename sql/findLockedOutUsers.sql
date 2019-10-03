DECLARE @Users TABLE (UserName VARCHAR(100), Processed BIT NOT NULL DEFAULT 0)
DECLARE @UserName VARCHAR(100)
DECLARE @IsLocked INT
 
SET NOCOUNT ON
 
INSERT INTO @Users (UserName)
SELECT DISTINCT Name
from sys.server_principals 
WHERE type IN ('U', 'S')
AND Name != 'sa'
 
WHILE EXISTS (SELECT TOP 1 UserName FROM @Users WHERE Processed = 0)
BEGIN
    SET @UserName  = (SELECT TOP 1 UserName FROM @Users WHERE Processed = 0)
     
    SET @IsLocked = CONVERT(INT, LOGINPROPERTY(@UserName, 'IsLocked'))
     
    IF(@IsLocked = 1)
    BEGIN
        PRINT 'User locked out ' + @UserName + ' ' + CONVERT(VARCHAR(10), @IsLocked)
    END
     
    UPDATE @Users
        SET Processed = 1
    WHERE UserName = @UserName
END
 
 
SET NOCOUNT OFF