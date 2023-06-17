$here = $PSScriptRoot
$environments = 'Dev', 'Test', 'Prod'
$randomNumber = 2

$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml

foreach ($environment in $environments)
{
    $notes = @{
        Environment = $environment
    }

    $subscriptions = Get-AzSubscription -TenantId $azureData.$environment.AzTenantId

    New-LabDefinition -Name "M365DscWorkshopWorker$($environment)$($randomNumber)" -DefaultVirtualizationEngine Azure -Notes $notes

    Add-LabAzureSubscription -SubscriptionId $subscriptions[0].SubscriptionId -DefaultLocation 'UK South'

    Set-LabInstallationCredential -Username Install -Password Somepass1

    $PSDefaultParameterValues = @{
        'Add-LabMachineDefinition:ToolsPath'       = "$labSources\Tools"
        'Add-LabMachineDefinition:OperatingSystem' = 'Windows Server 2022 Datacenter (Desktop Experience)'
    }

    Add-LabDiskDefinition -Name "Lcm$($environment)Data1" -DiskSizeInGb 1000 -Label Data

    Add-LabMachineDefinition -Name "Lcm$($environment)" -AzureRoleSize Standard_D8lds_v5 -DiskName "Lcm$($environment)Data1"

    Install-Lab

}
