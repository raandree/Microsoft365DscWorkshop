$here = $PSScriptRoot
$environments = 'Dev', 'Test', 'Prod'
$randomNumber = 2

$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml

foreach ($environment in $environments)
{
    $lab = Import-Lab -Name "M365DscWorkshopWorker$($environment)$($randomNumber)" -NoValidation -PassThru

    Write-Host "Starting all VMs in $($lab.Name)"
    Start-LabVM -All

}
