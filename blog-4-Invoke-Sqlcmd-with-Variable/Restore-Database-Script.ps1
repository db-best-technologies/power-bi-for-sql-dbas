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

$SqlcmdParameters.Query = "SELECT DB_NAME() AS [`$(DBName)]"
Invoke-Sqlcmd @SqlcmdParameters

$SqlcmdParameters["Database"] = $Benchmark
Invoke-Sqlcmd @SqlcmdParameters

$SqlcmdParameters["Username"] = "sa"
$SqlcmdParameters["Password"] = "Poop"
Invoke-Sqlcmd @SqlcmdParameters
$SqlcmdParameters.Remove("Username")
$SqlcmdParameters.Remove("Password")
Write-Host @SqlcmdParameters

# CSV file with the sql user name, string_encrypted_password, and key
# located in file C:\TEMP\secret.csv.
$SecretsCSV = Import-Csv -Path 'C:\Temp\Secret.csv' -Delimiter ','
if ($null -ne $SecretsCSV){
    Write-Host "C:\Temp\Secret.csv loaded OK, so use the -Username -Password parameters for Invoke-Sqlcmd"
    $Key = Invoke-Expression $SecretsCSV.Key | Invoke-Expression
    $RevivedSecureString = $SecretsCSV.EncryptedPassword | ConvertTo-SecureString -Key $Key
    $Password = (New-Object PSCredential "sa",$RevivedSecureString).GetNetworkCredential().Password

    $SqlcmdParameters.Username = $SecretsCSV.SQLUser
    $SqlcmdParameters.Password = $Password
}
Invoke-Sqlcmd @SqlcmdParameters
Remove-Variable  -Name SecretsCSV, Password, Key, RevivedSecureString
$SqlcmdParameters.Remove("Username")
$SqlcmdParameters.Remove("Password")



Remove-Variable -Name OriginalPassword, SecretsCSV, Key, Encrypted, RevivedSecureString



