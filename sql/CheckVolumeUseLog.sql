DECLARE @Primary as nvarchar(128)
DECLARE @Machine as nvarchar(128) 
   SET @Machine = CASE WHEN @@SERVERNAME LIKE '%\%'
                  THEN LEFT(@@SERVERNAME,charindex('\',@@SERVERNAME,1)-1)
                  ELSE @@SERVERNAME 
                  END
 
/*if AlwaysOn, then check if we are primary node*/
IF SERVERPROPERTY('IsHadrEnabled')= 1
BEGIN
    /*get primary node*/
    SELECT @Primary = hags.primary_replica
      FROM master.sys.dm_hadr_availability_group_states hags
      JOIN master.sys.availability_groups ag
        ON hags.group_id=ag.group_id
END

/*either AAG and primary node, or not AAG*/ 
IF (@Primary = @Machine) OR (@Primary IS NULL) -- 
BEGIN
    IF OBJECT_ID('dba.dbo.VolumeUseLog') IS NOT NULL
    	BEGIN
            SELECT ServerName
                 , RunTime
                 , DriveLetter
                 , TotalSpaceInGB
                 , ((TotalSpaceInGB * PercentUsed)*.01) AS TotalSpaceUsedInGB
                 , (TotalSpaceInGB - ((TotalSpaceInGB * PercentUsed)*.01)) AS TotalSpaceFreeInGB
                 , PercentUsed
              FROM dba.dbo.VolumeUseLog
             WHERE RunTime IN ( SELECT DISTINCT TOP 3 RunTime
                                  FROM dba.dbo.VolumeUseLog
                                 WHERE RunTime BETWEEN DATEADD(HOUR, -2, SYSUTCDATETIME()) AND SYSUTCDATETIME()
                                 ORDER BY RunTime DESC
                              )
               AND DriveLetter <> 'C' 
             ORDER BY ServerName
                    , DriveLetter
        END
END
