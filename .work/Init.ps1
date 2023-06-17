$tenentName = 'Microsoft'
$subscriptionName = 'AL5'
$keyVaultReaderName = 'DscKeyVaultReaderDev'

$tenant = Get-AzTenant | Where-Object Name -eq $tenentName
$keyVaultReader = Get-AzADServicePrincipal -DisplayName $keyVaultReaderName

$d = New-DatumStructure -DefinitionFile $ProjectPath\source\Datum.yml

foreach ($env in $d.Global.Azure.GetEnumerator())
{
    $param = @{
        ServicePrincipal    = $true
        ApplicationId       = $readUserApplicationId
        CertificatePath     = 'D:\KeyVaultAccess.pfx'
        CertificatePassword = $pass
        Tenant              = $tenant.Id
        Subscription        = $subscriptionName
    }
    Connect-AzAccount @param
}
