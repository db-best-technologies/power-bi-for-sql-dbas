:on error exit

-- Drop thedatabase if it already exists
USE master
GO
IF (EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE (name = '$(DBName)')))
	BEGIN
		EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'$(DBName)';
		ALTER DATABASE [$(DBName)] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE;
		DROP DATABASE [$(DBName)];
	END
GO

RESTORE DATABASE [$(DBName)] 
        FROM  
            DISK = N'$(BackupPath)' 
        WITH  FILE = 1
            , MOVE N'$(DBName)' TO N'$(DataDrv)'  
            , MOVE N'$(DBName)_log' TO N'$(LogDrv)'  
            , NOUNLOAD
            , STATS = 5
            , MAXTRANSFERSIZE = 4194304;
GO
