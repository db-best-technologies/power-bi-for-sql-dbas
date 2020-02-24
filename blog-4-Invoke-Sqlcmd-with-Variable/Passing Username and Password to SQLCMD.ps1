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