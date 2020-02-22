$InstanceName = "BILL\SQLEXPRESS"
$SQLUserName = "sa"
$Password = "Soaked_Drown_Finger"
$Secure = ConvertTo-SecureString -String $Password -AsPlainText -Force
$Key = (1..16)
$KeyString = "'(1..16)'"
$Encrypted = ConvertFrom-SecureString -SecureString $Secure -Key $Key

@([PSCustomObject]@{
    SQLUser = $SQLUserName
    EncryptedPassword = $Encrypted
    Key = $KeyString
}) | Export-Csv -Path "C:\TEMP\Secret.csv" -NoTypeInformation

$SecretsCSV = Import-Csv -Path 'C:\Temp\Secret.csv' -Delimiter ','
$Key = Invoke-Expression $SecretsCSV.Key | Invoke-Expression
$RevivedSecureString = $Encrypted | ConvertTo-SecureString -Key $key
$OriginalPassword = (New-Object PSCredential "sa",$RevivedSecureString).GetNetworkCredential().Password
Write-Host "SQL User Name: $($SecretsCSV.SQLUser), Password: $OriginalPassword"
Remove-Variable -Name OriginalPassword, Password, SecretsCSV, Key, KeyString, Encrypted, RevivedSecureString

