
$Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($x)
$result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)
$result


#$cert = Get-AzKeyVaultCertificate -Name $datum.Global.Azure.Dev.AzWorkerServicePrincipalName -VaultName $datum.Global.Azure.Dev.AzKeyVaultName

$secret = Get-AzKeyVaultSecret -VaultName $datum.Global.Azure.Dev.AzKeyVaultName -Name $datum.Global.Azure.Dev.AzWorkerServicePrincipalName #-Version $cert.Version

$ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($secret.SecretValue)
$result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr)

$bytes = [system.convert]::FromBase64String($result)
$pfx = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes)
#Export-PfxCertificate -Cert $pfx -FilePath d:\cert.pfx

[System.IO.File]::WriteAllBytes('d:\cert.pfx', $bytes)

$servicePrincipal = Get-AzADServicePrincipal -DisplayName $env.Value.AzWorkerServicePrincipalName
$workerServicePrincipal = Get-AzADServicePrincipal -DisplayName $datum.Global.Azure.Dev.AzWorkerServicePrincipalName
Connect-AzAccount -CertificatePath D:\cert.pfx -ApplicationId $secret.SecretIdentifier.Identifier -Tenant $datum.Global.Azure.Dev.AzTenantId

#------------------

$keyValueServicePrincipal = Get-AzADServicePrincipal -DisplayName $datum.Global.Azure.Dev.AzKeyVaultNameServicePrincipalName
$workerServicePrincipal = Get-AzADServicePrincipal -DisplayName $datum.Global.Azure.Dev.AzWorkerServicePrincipalName
Connect-AzAccount -ApplicationId $keyValueServicePrincipal.AppId -CertificatePath .\assets\certificates\ServicePrincipal-M365DSC-KeyVaultReader-DEV.pfx -Tenant $azureBuildParameters.Dev.AzTenantId

$secret = Get-AzKeyVaultSecret -VaultName $datum.Global.Azure.Dev.AzKeyVaultName -Name $datum.Global.Azure.Dev.AzWorkerServicePrincipalName

$ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($secret.SecretValue)
$result = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($ptr)

$bytes = [system.convert]::FromBase64String($result)
$pfx = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes)
#[System.IO.File]::WriteAllBytes('d:\cert.pfx', $bytes)
$store = [System.Security.Cryptography.X509Certificates.X509Store]::new('My', 'CurrentUser')
$store.Open('MaxAllowed')
$store.Add($pfx)

Connect-AzAccount -ApplicationId $workerServicePrincipal.AppId -CertificateThumbprint $pfx.Thumbprint -Tenant $azureBuildParameters.Dev.AzTenantId
