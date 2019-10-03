USE util
GO

IF EXISTS(SELECT * FROM sys.objects WHERE type = 'P' and name = 'ia_addtenant') 
BEGIN
    DROP PROCEDURE api_alias.ia_addtenant
END
GO

CREATE PROCEDURE api_alias.ia_addtenant @database_name sysname, @user_name sysname
WITH EXECUTE AS OWNER
AS
BEGIN
    /*Create variables for the loop*/
    DECLARE @newdbname nvarchar(200) = @database_name + '_'
    DECLARE @individual nvarchar(200) = null
    DECLARE @customer nvarchar(200) = null
    DECLARE @environment nvarchar(200) = null
    DECLARE @product varchar(200) = null
    DECLARE @dbtype varchar(200) = null
    DECLARE @enumerator varchar(200) = null
    DECLARE @counter int = 0
    
    /*Loop through the database name structure and find the components*/
    /*There are only four '_' characters */
    WHILE @counter < 5
        BEGIN
            SET @counter = @counter + 1;
            IF (PATINDEX('%[_]%',@newdbname) > 0)
            BEGIN
                /*Get the individual string element that we want*/
                /*[] are to escape the _ character*/
                SET @individual = SUBSTRING(@newdbname, 0, PATINDEX('%[_]%',@newdbname))
                /*first part is the customer name*/
                IF (@counter = 1)
                BEGIN 
                    SET @customer = @individual
                END
                /*second part is the environment*/
                ELSE IF (@counter = 2)
                BEGIN
                    SET @environment = @individual
                END
                /*third part is the product name*/
                ELSE IF (@counter = 3)
                BEGIN
                    SET @product = @individual
                END
                /*fourth part is the database type for the specific app*/
                ELSE IF (@counter = 4)
                BEGIN
                    SET @dbtype = @individual
                END
                /*fifth part is the enumerator*/
                ELSE IF (@counter = 5)
                BEGIN
                    SET @enumerator = @individual
                END
                SET @newdbname = SUBSTRING(@newdbname, LEN(@individual + '_') + 1,LEN(@newdbname))
            END
        END
    
    /*Only proceed if an IA database*/
    IF (@product = 'IAR')
    BEGIN
        /*Build string for comparision*/
        DECLARE @dbcompare nvarchar(200) = null
           SET @dbcompare = @customer + '_' + @environment + '_' + @product + '%'
            /*Make sure at least 4 databases for IA have been provisioned already*/
            IF ( (SELECT COUNT(*) FROM master.sys.databases WHERE name LIKE @dbcompare) >= 4 )
               BEGIN
                   INSERT INTO util.dbo.poop VALUES('1') 
                   /*Create temp table to hold list of databases to loop through*/
                       IF OBJECT_ID('tempdb..#ia_addtenant') IS NOT NULL
    	                  BEGIN
    	                      DROP TABLE #ia_addtenant
    	                  END

                   CREATE TABLE #ia_addtenant ([name] sysname)

                   INSERT INTO #ia_addtenant
                   SELECT name
                     FROM master.sys.databases
                    WHERE name LIKE @dbcompare

                    /*Loop through list of databases*/
                    WHILE EXISTS ( SELECT 1 from #ia_addtenant )
                          BEGIN
                              /*Get a database name*/
                             DECLARE @DatabaseName sysname = NULL
                              SELECT TOP 1 @DatabaseName = name
                                FROM #ia_addtenant 
                               ORDER BY name
                              
                              /*Delete that database from the temp table so that the loop will continue*/
                              DELETE 
                                FROM #ia_addtenant
                               WHERE name = @DatabaseName
    
                              /*Declare variables for inner loop*/
                              DECLARE @INNERDatabaseName sysname = @DatabaseName + '_'
                              DECLARE @INNERindividual nvarchar(200) = null
                              DECLARE @INNERcustomer nvarchar(200) = null
                              DECLARE @INNERenvironment nvarchar(200) = null
                              DECLARE @INNERproduct varchar(200) = null
                              DECLARE @INNERdbtype varchar(200) = null
                              DECLARE @INNERenumerator varchar(200) = null
                              DECLARE @INNERcounter int = 0 
                               
                               /*Loop through the database name structure and find the components*/
                               /*There are only four '_' characters */
                               WHILE @INNERcounter < 5
                                     BEGIN
                                         SET @INNERcounter = @INNERcounter + 1;
                                         IF (PATINDEX('%[_]%',@INNERDatabaseName) > 0)
                                         BEGIN
                                             /*Get the individual string element that we want*/
                                             /*[] are to escape the _ character*/
                                             SET @INNERindividual = SUBSTRING(@INNERDatabaseName, 0, PATINDEX('%[_]%',@INNERDatabaseName))
                                             /*first part is the customer name*/
                                             IF (@INNERcounter = 1)
                                             BEGIN 
                                                 SET @INNERcustomer = @INNERindividual
                                             END
                                             /*second part is the environment*/
                                             ELSE IF (@INNERcounter = 2)
                                             BEGIN
                                                 SET @INNERenvironment = @INNERindividual
                                             END
                                             /*third part is the product name*/
                                             ELSE IF (@INNERcounter = 3)
                                             BEGIN
                                                 SET @INNERproduct = @INNERindividual
                                             END
                                             /*fourth part is the database type for the specific app*/
                                             ELSE IF (@INNERcounter = 4)
                                             BEGIN
                                                 SET @INNERdbtype = @INNERindividual
                                             END
                                             /*fifth part is the enumerator*/
                                             ELSE IF (@INNERcounter = 5)
                                             BEGIN
                                                 SET @INNERenumerator = @INNERindividual
                                             END
                                             SET @INNERDatabaseName = SUBSTRING(@INNERDatabaseName, LEN(@INNERindividual + '_') + 1,LEN(@INNERDatabaseName))
                                         END
                                     END
    
                               /*If we have the staging db map the staging user into the recommender databases*/
                               IF (@INNERdbtype = 'eCo')
                                  BEGIN
                                      /*Build comparision string*/
                                      DECLARE @RECdbcompare nvarchar(200) = NULL
                                         SET @RECdbcompare = @INNERcustomer + '_' + @INNERenvironment + '_' + @INNERproduct + '_rec_%'
                                      /*Create temp table to hold list of databases to loop through*/
                                          IF OBJECT_ID('tempdb..#ia_addtenant_rec') IS NOT NULL
    	                                     BEGIN
    	                                         DROP TABLE #ia_addtenant_rec
    	                                     END
                                      CREATE TABLE #ia_addtenant_rec ([name] sysname)
                                      INSERT INTO #ia_addtenant_rec
                                      SELECT name
                                        FROM master.sys.databases
                                       WHERE name LIKE @RECdbcompare
                                       
                                       /*Loop through list of databases*/
                                       WHILE EXISTS ( SELECT 1 from #ia_addtenant_rec )
                                             BEGIN
                                                 /*Get a database name*/
                                                 DECLARE @RECDatabaseName sysname = NULL
                                                 SELECT TOP 1 @RECDatabaseName = name
                                                   FROM #ia_addtenant_rec 
                                                  ORDER BY name
                                                
                                                 /*Delete that database from the temp table so that the loop will continue*/
                                                 DELETE 
                                                   FROM #ia_addtenant_rec
                                                  WHERE name = @RECDatabaseName
                                                 
                                                 /*Validate if staging user already exists in recommender database*/
                                                 DECLARE @Query1Output INT
                                                 DECLARE @Query1 NVARCHAR(300)
                                                    SET @Query1 = 'SELECT @Query1Output = COUNT(*) 
                                                                     FROM ' + @RECDatabaseName + '.sys.database_principals
                                                                    WHERE name = ''' + @DatabaseName + ''''
                                                   
                                                   EXEC master.sys.sp_executesql @Query = @Query1
                                                                               , @Params = N'@Query1Output INT OUTPUT'
                                                                               , @Query1Output = @Query1Output OUTPUT
                                                 /*If staging user is not in the recommender database*/
                                                     IF (@Query1Output = 0)
                                                        BEGIN
                                                            /*Add staging user into recommender database*/
                                                              EXEC ( '   USE [' + @RECDatabaseName + '];
                                                                      CREATE USER [' + @DatabaseName + '] for login [' + @DatabaseName + '];'
                                                                   ) ;
                                                        END
    
                                                 /*Validate if staging user is already a memeber of the db_owner role in recommender database*/
                                                 DECLARE @Query2Output INT
                                                 DECLARE @Query2 NVARCHAR(800)
                                                    SET @Query2 = '  USE ' + @RECDatabaseName + ';
                                                                  SELECT @Query2Output = COUNT(*)
                                                                    FROM ' + @RECDatabaseName + '.sys.database_principals dp
                                                                   INNER JOIN ' + @RECDatabaseName + '.sys.database_role_members drm
                                                                      ON drm.member_principal_id = dp.principal_id
                                                                   WHERE dp.principal_id = USER_ID(''' + @DatabaseName + ''')
                                                                     AND drm.role_principal_id = ( SELECT principal_id 
                                                                                                     FROM ' + @RECDatabaseName + '.sys.database_principals
                                                                                                    WHERE [type] = ''R''
                                                                                                      AND name = ''db_owner'' )'
                                                    
                                                   EXEC master.sys.sp_executesql @Query = @Query2
                                                                             , @Params = N'@Query2Output INT OUTPUT'
                                                                             , @Query2Output = @Query2Output OUTPUT
                                                 
                                                 /*If staging user is not a memeber of the db_owner role*/
                                                     IF (@Query2Output = 0)
                                                        BEGIN
                                                            /*Add staging user to the db_owner role in the recommender database*/
                                                              EXEC ( '   USE [' + @RECDatabaseName + '];
                                                                       ALTER ROLE [db_owner] add member [' + @DatabaseName + '];'
                                                                   ) ;
                                                        END
                                             END
                                       IF OBJECT_ID('tempdb..#ia_addtenant_rec') IS NOT NULL
    	                                  BEGIN
    	                                      DROP TABLE #ia_addtenant_rec
    	                                  END
                                  END
                          END
                   IF OBJECT_ID('tempdb..#ia_addtenant') IS NOT NULL
    	              BEGIN
    	                  DROP TABLE #ia_addtenant
    	              END
               END 
    END
END
