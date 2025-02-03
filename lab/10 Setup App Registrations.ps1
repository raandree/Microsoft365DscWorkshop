[CmdletBinding()]
param (
    [Parameter()]
    [string[]]$EnvironmentName
)

$requiredModulesPath = (Resolve-Path -Path $PSScriptRoot\..\output\RequiredModules).Path
if ($env:PSModulePath -notlike "*$requiredModulesPath*")
{
    $env:PSModulePath = $env:PSModulePath + ";$requiredModulesPath"
}

$datum = New-DatumStructure -DefinitionFile $PSScriptRoot\..\source\Datum.yml
$environments = $datum.Global.Azure.Environments.Keys
if ($EnvironmentName)
{
    $environments = $environments | Where-Object { $EnvironmentName -contains $_ }
}

foreach ($environmentName in $environments)
{
    $environment = $datum.Global.Azure.Environments."$environmentName"
    $pass = $datum.__Definition.DatumHandlers.'Datum.ProtectedData::ProtectedDatum'.CommandOptions.PlainTextPassword | ConvertTo-SecureString -AsPlainText -Force

    Write-Host "Working in environment '$environmentName'" -ForegroundColor Magenta
    Write-Host "Connecting to Azure subscription '$($environment.AzSubscriptionId)' in tenant '$($environment.AzTenantId)'"

    $param = @{
        TenantId   = $environment.AzTenantId
        TenantName = $environment.AzTenantName
    }
    if (-not [string]::IsNullOrEmpty($environment.AzSubscriptionId))
    {
        $param.SubscriptionId = $environment.AzSubscriptionId
    }

    Connect-M365Dsc @param

    $param.Remove('TenantName')
    if (-not (Test-M365DscConnection @param))
    {
        Write-Error "Failed to connect to Azure subscription '$($environment.AzSubscriptionId)' in tenant '$($environment.AzTenantId)'" -ErrorAction Stop
    }

    Write-Host "Successfully connected to Azure subscription '$($environment.AzTenantName) ($($environment.AzSubscriptionId))' with account '$((Get-AzContext).Account.Id)'"

    foreach ($identity in $environment.Identities.GetEnumerator())
    {
        $azIdentity = if ($identity.ApplicationSecret -eq '<AutoGeneratedLater>')
        {
            Write-Host "Registering the application '$($identity.Name)' for environment '$environmentName' with auto-generated secret."
            New-M365DscIdentity -Name $identity.Name -GenereateAppSecret -PassThru
        }
        elseif ($identity.CertificateThumbprint -eq '<AutoGeneratedLater>')
        {
            Write-Host "Registering the application '$($identity.Name)' for environment '$environmentName' with certificate."
            New-M365DscIdentity -Name $identity.Name -GenereateCertificate -PassThru
        }
        else
        {
            Write-Host "Registering the application '$($identity.Name)' for environment '$environmentName' without secret."
            New-M365DscIdentity -Name $identity.Name -PassThru
        }

        if ($identity.ApplicationSecret -eq '<AutoGeneratedLater>' -and $null -eq $azIdentity.Secret)
        {
            Write-Error "Failed to generate secret for application '$($identity.Name)' in environment '$environmentName'. Please run the script again." -ErrorAction Stop
        }
        elseif ($identity.CertificateThumbprint -eq '<AutoGeneratedLater>' -and $null -eq $azIdentity.CertificateThumbprint)
        {
            Write-Error "Failed to generate certificate for application '$($identity.Name)' in environment '$environmentName'. Please run the script again." -ErrorAction Stop
        }

        Add-M365DscIdentityPermission -Identity $azIdentity -AccessType Update

        Write-Host "Registered the application '$($identity.Name)' for environment '$environmentName'." -ForegroundColor Magenta
        Write-Host "  'AzApplicationId: $($azIdentity.AppId)'" -ForegroundColor Magenta
        if ($azIdentity.Secret)
        {
            Write-Host "  'AzApplicationSecret: $($azIdentity.Secret)'" -ForegroundColor Magenta
        }
        elseif ($azIdentity.CertificateThumbprint)
        {
            Write-Host "  'AzCertificateThumbprint: $($azIdentity.CertificateThumbprint)'" -ForegroundColor Magenta
        }

        Write-Host "Updating credentials for environment '$environmentName'."

        $identity.ApplicationId = $azIdentity.AppId
        if ($identity.ApplicationSecret -eq '<AutoGeneratedLater>')
        {
            $identity.ApplicationSecret = $azIdentity.Secret | Protect-Datum -Password $pass -MaxLineLength 9999
        }
        elseif ($identity.CertificateThumbprint -eq '<AutoGeneratedLater>')
        {
            $identity.CertificateThumbprint = $azIdentity.CertificateThumbprint
        }
    }
    Disconnect-M365Dsc
    Write-Host "Finished working in environment '$environmentName'."
}

Write-Host 'Finished working in all environments'

Write-Host "Updating the file '\source\Global\Azure\Azure.yml' to store the new credentials."
$datum.Global.Azure | ConvertTo-Yaml | Out-File -FilePath $PSScriptRoot\..\source\Global\Azure.yml -Force

Write-Host "Committing and pushing the changes to the repository '$(git config --get remote.origin.url)'."
$currentBranchName = git rev-parse --abbrev-ref HEAD
git add $PSScriptRoot/../source/Global/Azure.yml
git commit -m 'Tenant Update' | Out-Null
git push --set-upstream origin $currentBranchName | Out-Null

Write-Host "Checking if there are any changes in the build agents and committing them to the git repository."
$buildAgendChanges = (git status -s) -like '*source/BuildAgents/*.yml'
if ($null -ne $buildAgendChanges)
{
    foreach ($changedFile in $buildAgendChanges)
    {
        Write-Host "  Adding change '$changedFile' to git."
        git add $changedFile.Substring(3)
    }

    Write-Host 'Committing changes to build agents.'
    git commit -m 'Updated build agents' | Out-Null
    git push | Out-Null
}

Write-Host Done. -ForegroundColor Green
