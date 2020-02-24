param
(
[string]$Cloud = "local", # Use aws, azure, gcp, or local
[string]$Benchmark = "tpcc", # Also DB name
[string]$Scenario = "HammerDB3.3",
[string]$BackupDrv = "G",
[string]$DataDrv = "E",
[string]$LogDrv = "L",
[string]$Warehouses = "10",  
[string]$sql_instance_name = "BILL\SQLEXPRESS"
)

$SqlcmdVariables= @(
    "DBName=$Benchmark",
    "BackupPath=$($BackupDrv):\Backup\$($Benchmark)_$($Scenario)_$($Warehouses).bak",
    "DataDrv=$($DataDrv):\DATA\$($Benchmark)_$($Scenario)_$($Warehouses).mdf",
    "LogDrv=$($LogDrv):\LOG\$($Benchmark)_$($Scenario)_$($Warehouses).ldf"
)

$SqlcmdParameters = @{
    ServerInstance = $sql_instance_name
    QueryTimeout = 0
    Query = "SELECT '`$(DBName)' AS DBName, '`$(BackupPath)' AS BackupPath, '`$(DataDrv)' AS DataDrv, '`$(LogDrv)' AS LogDrv" 
    Verbose = $true
    Variable = $SqlcmdVariables
}


Invoke-Sqlcmd @SqlcmdParameters

# Delete the Query key value with Remove method
$SqlcmdParameters.Remove("Query")

# Add the Inputfile key value pair with the Add Method
$SqlcmdParameters.Add('InputFile', '.\Restore-Database-Sqlcmd.sql')

# Sanity check
$SqlcmdParameters

# Updating a parameter value
$SqlcmdParameters.Verbose = $false
Write-Host $SqlcmdParameters.Verbose

Set-Location -Path .\blog-4-Invoke-Sqlcmd-with-Variable
Invoke-Sqlcmd @SqlcmdParameters

# Query sys.master_files to results
$SqlcmdParameters.Remove("InputFile")
$SqlcmdParameters.Add("Database", "master")
$SqlcmdParameters.Add("Query", "SELECT name as [Logical Name], physical_name AS [File Location] FROM sys.master_files WHERE name LIKE ('$($Benchmark)%')")



