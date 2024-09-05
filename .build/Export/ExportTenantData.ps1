task ExportTenantData {

    $configPath = "$ProjectPath\export\ExportConfiguration.yml"
    $exportConfig = Get-Content -Path $configPath -Raw | ConvertFrom-Yaml

    foreach ($env in $datum.Global.Azure.Environments.GetEnumerator())
    {
        Write-Host "Exporting configuration for environment $($env.Name)" -ForegroundColor Yellow
        if (-not $env.Value.AzTenantId)
        {
            Write-Error "AzTenantId is not defined for environment $($env.Name)" -ErrorAction Stop
        }

        $exportApp = $env.Value.Identities | Where-Object Name -EQ M365DscExportApplication
        if ($null -eq $exportApp)
        {
            Write-Error "Export application 'M365DscExportApplication' is not defined for environment $($env.Name)" -ErrorAction Stop
        }

        $exportParams = @{
            Components            = $exportConfig.DscResources
            ApplicationId         = $exportApp.ApplicationId
            CertificateThumbprint = $exportApp.CertificateThumbprint
            TenantId              = $env.Value.AzTenantName
            Path                  = "$OutputDirectory\Export\$($env.Value.AzTenantName)"
        }

        Export-M365DSCConfiguration @exportParams

    }

}

task InvokingDscExportConfiguration {

    Remove-Module -Name PSDesiredStateConfiguration -Force -ErrorAction SilentlyContinue

    $directories = dir -Path "$OutputDirectory\export" -Directory
    foreach ($directory in $directories)
    {
        $directory | Set-Location

        Write-Host "Invoking DSC configuration in directory $($directory.FullName)" -ForegroundColor Yellow
        dir -Path $Path -Recurse -Filter *.ps1 | ForEach-Object { & $_.FullName }
    }

    Set-Location -Path $ProjectPath

}

task ConvertMofToYaml {

    $data = Convert-MofToYaml -Path "$OutputDirectory\export"

    Write-Host 'Exporting tenant configuration to the output folder as YAML' -ForegroundColor Yellow
    $data | ConvertTo-Yaml | Out-File "$OutputDirectory\export\TenantConfiguration.yml"

}