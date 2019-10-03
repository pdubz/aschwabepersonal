/*
   input:
   db_name - database name
   db_log_path - location where log files will be stored	
   mdp_tmvxprim01_size - size of primary database log file
   mdp_tmvxtranl_size - size of transaction log file
   db_table_path - location where database files will be stored
   mdp_tmvxsd01_size - size of database file 1
   mdp_tmvxsd02_size - size of database file 2
   mdp_tmvxsd03_size - size of database file 3
   db_index_path - location where database indexes will be stored
   mdp_tmvxsi01_size - size of database indexes file 1
   mdp_tmvxsi02_size - size of database indexes file 2
   mdp_tmvxsi03_size - size of database indexes file 3
   db_collation - specifies the collation for the database
*/
if not exists (select name from sys.databases where name = '$(db_name)') 
begin
create database $(db_name)
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'$(db_name)', 
  FILENAME = N'$(db_log_path)\$(db_name).mdf' , 
  SIZE = 334016KB , 
  MAXSIZE = UNLIMITED, 
  FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'$(db_name)_log', 
  FILENAME = N'$(db_log_path)\$(db_name)_log.ldf' , 
  SIZE = 39936KB , 
  MAXSIZE = UNLIMITED , 
  FILEGROWTH = 10%)
    collate $(db_collation)
    alter database $(db_name) set DB_CHAINING off, TRUSTWORTHY off
end
GO

ALTER DATABASE $(db_name) SET COMPATIBILITY_LEVEL = 120
GO

IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC $(db_name).[dbo].[sp_fulltext_database] @action = 'enable'
end
GO

ALTER DATABASE $(db_name) SET ANSI_NULL_DEFAULT OFF 
GO

ALTER DATABASE $(db_name) SET ANSI_NULLS OFF 
GO

ALTER DATABASE $(db_name) SET ANSI_PADDING OFF 
GO

ALTER DATABASE $(db_name) SET ANSI_WARNINGS OFF 
GO

ALTER DATABASE $(db_name) SET ARITHABORT OFF 
GO

ALTER DATABASE $(db_name) SET AUTO_CLOSE OFF 
GO

ALTER DATABASE $(db_name) SET AUTO_SHRINK OFF 
GO

ALTER DATABASE $(db_name) SET AUTO_UPDATE_STATISTICS ON 
GO

ALTER DATABASE $(db_name) SET CURSOR_CLOSE_ON_COMMIT OFF 
GO

ALTER DATABASE $(db_name) SET CURSOR_DEFAULT  GLOBAL 
GO

ALTER DATABASE $(db_name) SET CONCAT_NULL_YIELDS_NULL OFF 
GO

ALTER DATABASE $(db_name) SET NUMERIC_ROUNDABORT OFF 
GO

ALTER DATABASE $(db_name) SET QUOTED_IDENTIFIER OFF 
GO

ALTER DATABASE $(db_name) SET RECURSIVE_TRIGGERS OFF 
GO

ALTER DATABASE $(db_name) SET  ENABLE_BROKER 
GO

ALTER DATABASE $(db_name) SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO

ALTER DATABASE $(db_name) SET DATE_CORRELATION_OPTIMIZATION OFF 
GO

ALTER DATABASE $(db_name) SET TRUSTWORTHY OFF 
GO

ALTER DATABASE $(db_name) SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO

ALTER DATABASE $(db_name) SET PARAMETERIZATION SIMPLE 
GO

ALTER DATABASE $(db_name) SET READ_COMMITTED_SNAPSHOT OFF 
GO

ALTER DATABASE $(db_name) SET HONOR_BROKER_PRIORITY OFF 
GO

ALTER DATABASE $(db_name) SET RECOVERY SIMPLE 
GO

ALTER DATABASE $(db_name) SET  MULTI_USER 
GO

ALTER DATABASE $(db_name) SET PAGE_VERIFY CHECKSUM  
GO

ALTER DATABASE $(db_name) SET DB_CHAINING OFF 
GO

ALTER DATABASE $(db_name) SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO

ALTER DATABASE $(db_name) SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO

ALTER DATABASE $(db_name) SET DELAYED_DURABILITY = DISABLED 
GO

ALTER DATABASE $(db_name) SET  READ_WRITE 
GO

