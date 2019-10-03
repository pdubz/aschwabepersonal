USE util;
GO
CREATE PROCEDURE dbo.usp_ag_delete 
       @dbDeleteName SYSNAME
     , @deleteBackupHistory CHAR(1) = 'Y'
AS 

/*
Name: AGDelete 
By:   Andy Schwabe 
v1.0: 20150507 -- Initial Version
v1.1: 20150514 -- Added single user to clear connections, added mandatory backup functionality
v1.2: 20150731 -- Turned into a sproc, added deleteBackupHistory param
*/

set nocount on

if SERVERPROPERTY ('IsHadrEnabled') = 1
    begin
        if( select RCS.replica_server_name
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
                --backup database
                print 'Backing up database on ' + @@SERVERNAME
                exec util.dbo.usp_backup_db @bu_type = 'full', @dbname = @dbDeleteName, @comment = 'FINAL'
                --remove database from ag
                print 'Removing database from AG on ' + @@SERVERNAME
                declare @SQL1 nvarchar(2000)
                set @SQL1 = N'alter availability group [AG1]
                                remove database ' + @dbDeleteName;
                exec master.sys.sp_executesql @stmt = @SQL1
                print 'Removed database from the availability group successfully'
                --set single user mode then back to multi user mode
                print 'Setting database to single user mode on ' + @@SERVERNAME + ' to clear connections then back to multi user mode to be safe'
                declare @SQL2 nvarchar(2000)
                set @SQL2 = N'use master;
                            alter database ' + @dbDeleteName + '
                                set single_user
                                with rollback immediate;
                                use master;
                            alter database ' + @dbDeleteName + '
                                set multi_user'
                exec master.sys.sp_executesql @stmt = @SQL2
                if( @deleteBackupHistory = 'Y')
                    begin
                        --delete backup history for database
                        print 'Deleting backup history from msdb ' + @@SERVERNAME
                        exec msdb.dbo.sp_delete_database_backuphistory @database_name = @dbDeleteName
                    end
                --delete database
                print 'Dropping database on ' + @@SERVERNAME
                declare @SQL3 nvarchar(2000)
                set @SQL3 = N'drop database ' + @dbDeleteName;
                exec master.sys.sp_executesql @stmt = @SQL3
                print 'Dropped database on ' + @@SERVERNAME
                print 'Completed tasks successfully on ' + @@SERVERNAME
            end
        else 
            while (1=1)
                begin 
                    if( select DBs.name
                        from master.sys.dm_hadr_database_replica_states as DHDRS
                        inner join master.sys.databases                 as DBs
                        on DHDRS.database_id = DBs.database_id
                        where DBs.name = @dbDeleteName ) = @dbDeleteName
                        begin      
                            continue
                        end
                    else
                        begin
                            if( @deleteBackupHistory = 'Y') 
                                begin
                                    print 'Deleting backup history from msdb on ' + @@SERVERNAME
                                    --delete backup history for database
                                    exec msdb.dbo.sp_delete_database_backuphistory @database_name = @dbDeleteName
                                end    
                            print 'Dropping database on ' + @@SERVERNAME
                            --delete database
                            declare @SQL4 nvarchar(2000)
                            set @SQL4 = N'drop database ' + @dbDeleteName;
                            exec master.sys.sp_executesql @stmt = @SQL4
                            print 'Dropped database on ' + @@SERVERNAME
                            print 'Completed tasks successfully on ' + @@SERVERNAME
                            --exit loop
                            break
                        end
                    end
                end
GO
