$certname = 'KeyVaultAccess'
$param = @{
    Subject = "CN=$certname"
    CertStoreLocation = "Cert:\CurrentUser\My"
    KeyExportPolicy = 'Exportable'
    KeySpec = 'Signature'
    KeyLength = 2048
    KeyAlgorithm = 'RSA'
    HashAlgorithm = 'SHA256'
}
$cert = New-SelfSignedCertificate @param

Export-Certificate -Cert $cert -FilePath ".\$certname.cer"

$pass = ConvertTo-SecureString -String Somepass1 -Force -AsPlainText
Export-PfxCertificate -Cert $cert -FilePath ".\$certname.pfx" -Password $pass
