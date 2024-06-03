$requiredModulesPath = (Resolve-Path -Path $PSScriptRoot\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*")
{
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

$datum = New-DatumStructure -DefinitionFile $PSScriptRoot\..\source\Datum.yml
$environments = $datum.Global.Azure.Environments.Keys

foreach ($environmentName in $environments)
{
    $environment = $datum.Global.Azure.Environments.$environmentName
    Write-Host "Working in environment '$environmentName'" -ForegroundColor Magenta
    Write-Host "Connecting to Azure subscription '$($environment.AzSubscriptionId)' in tenant '$($environment.AzTenantId)'"

    Connect-M365Dsc -TenantId $environment.AzTenantId -TenantName $environment.AzTenantName -SubscriptionId $environment.AzSubscriptionId
    if (-not (Test-M365DscConnection -TenantId $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId))
    {
        Write-Error "Failed to connect to Azure subscription '$($environment.AzSubscriptionId)' in tenant '$($environment.AzTenantId)'" -ErrorAction Stop
    }

    foreach ($identity in $environment.Identities.GetEnumerator())
    {
        $azIdentity = Get-M365DscIdentity -Name $identity.Name

        if (-not $azIdentity)
        {
            Write-Host "The application '$($identity.Name)' for environment '$environmentName' does not exist."
            continue
        }

        Write-Host "Removing the permissions for the application '$($identity.Name)' for environment '$environmentName'."
        Remove-M365DscIdentityPermission -Identity $azIdentity -SkipGraphApiPermissions

        Write-Host "Removing the application '$($identity.Name)' for environment '$environmentName'."
        Remove-M365DscIdentity -Identity $azIdentity

    }

    Disconnect-M365Dsc
    Write-Host "Finished working in environment '$environmentName'."

}

Write-Host 'Finished working in all environments'
