
DECLARE @Primary as nvarchar(128)DECLARE @Machine as nvarchar(128)    SET @Machine = CASE WHEN @@SERVERNAME LIKE '%\%'                  THEN LEFT(@@SERVERNAME,charindex('\',@@SERVERNAME,1)-1)                  ELSE @@SERVERNAME                   END /*if AlwaysOn, then check if we are primary node*/IF SERVERPROPERTY('IsHadrEnabled')= 1BEGIN    /*get primary node*/    SELECT @Primary = hags.primary_replica      FROM master.sys.dm_hadr_availability_group_states hags      JOIN master.sys.availability_groups ag        ON hags.group_id=ag.group_idEND/*either AAG and primary node, or not AAG*/ IF (@Primary = @Machine) OR (@Primary IS NULL) -- BEGIN    /*Check for process log table*/    IF OBJECT_ID('dba.dbo.ProcessLog') IS NOT NULL    BEGIN
        /*Only select top 100 as the table can have millions of records*/
        SELECT TOP 100 *
          FROM dba.dbo.ProcessLog
         ORDER BY ProcessLogID desc
    END
END