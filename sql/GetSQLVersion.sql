if SERVERPROPERTY ('IsHadrEnabled') = 1
   begin
	    if   ( select RCS.replica_server_name
                  from sys.availability_groups_cluster AS AGC
                 inner join sys.dm_hadr_availability_replica_cluster_states AS RCS
                    on RCS.group_id = AGC.group_id
                 inner join sys.dm_hadr_availability_replica_states AS ARS
                    on ARS.replica_id = RCS.replica_id
                 inner join sys.availability_group_listeners AS AGL
                    on AGL.group_id = ARS.group_id
                 where ARS.role_desc = 'PRIMARY'
               ) = @@SERVERNAME 
    begin
        Set nocount on
    end
    else
    begin
        SELECT @@SERVERNAME, SERVERPROPERTY('ProductVersion')
    end
END
ELSE
BEGIN
    SELECT @@SERVERNAME, SERVERPROPERTY('ProductVersion')
END