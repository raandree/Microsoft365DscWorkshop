$here = $PSScriptRoot
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml
$projectSettings = Get-Content $here\..\source\Global\ProjectSettings.yml | ConvertFrom-Yaml -ErrorAction Stop
$environments = $azureData.Environments.Keys

foreach ($environmentName in $environments) {
    $environment = $azureData.Environments.$environmentName
    Write-Host "Working in environment '$environmentName'" -ForegroundColor Magenta
    Write-Host "Connecting to Azure subscription '$($environment.AzSubscriptionId)' in tenant '$($environment.AzTenantId)'"

    $subscription = Set-AzContext -TenantId $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction SilentlyContinue
    if (-not $subscription) {
        $null = Connect-AzAccount -Tenant $environment.AzTenantId -SubscriptionId $environment.AzSubscriptionId -ErrorAction Stop
        $subscription = Get-AzContext
    }

    Connect-MgGraph -TenantId $environment.AzTenantId -Scopes RoleManagement.ReadWrite.Directory, Directory.ReadWrite.All -NoWelcome -ErrorAction Stop
    Write-Host "Connected to Azure subscription '$($subscription.Name)' and Microsoft Graph with account '$($subscription.Account.Id)'"
    
    if (-not (Get-MgApplication -Filter "displayName eq '$($projectSettings.Name)'" -ErrorAction SilentlyContinue)) {
        Write-Host "Did not find application '$($projectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'."
        Write-Host "Creating application '$($projectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        $appRegistration = New-MgApplication -DisplayName $projectSettings.Name
        Write-Host "Creating service principal for application '$($projectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        $appPrincipal = New-MgServicePrincipal -AppId $appRegistration.AppId
    
        $passwordCred = @{
            displayName = 'Secret'
            endDateTime = (Get-Date).AddMonths(12)
        }
        Write-Host "Creating password secret for application '$($projectSettings.Name)' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        $clientSecret = Add-MgApplicationPassword -ApplicationId $appRegistration.Id -PasswordCredential $passwordCred
        
        Write-Host "IMPORTANT: Update the property 'AzApplicationSecret' in the file '\source\Global\Azure.yml' for the correct environment." -ForegroundColor Magenta
        Write-Host "Registered the application '$($projectSettings.Name)' for environment '$environmentName' in the subscription '$($subscription.Name)' with password secret" -ForegroundColor Magenta
        Write-Host "  'AzApplicationId: $($appRegistration.AppId)'" -ForegroundColor Magenta
        Write-Host "  'AzApplicationSecret: $($clientSecret.SecretText)'" -ForegroundColor Magenta

        Write-Host "Waiting 10 seconds before assigning the application '$($projectSettings.Name)' to the role 'Owner' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        Start-Sleep -Seconds 10
        Write-Host "Assigning the application '$($projectSettings.Name)' to the role 'Owner' in environment '$environmentName' in the subscription '$($subscription.Name)'"
        New-AzRoleAssignment -PrincipalId $appPrincipal.Id -RoleDefinitionName Owner | Out-Null
    }

    Write-Host "Finished working in environment '$environmentName' in the subscription '$($subscription.Name)'"

}

Write-Host 'Finished working in all environments'
