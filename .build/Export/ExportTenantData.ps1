task ExportTenantData {

    $configPath = "$ProjectPath\export\ExportConfiguration.yml"
    $exportConfig = Get-Content -Path $configPath -Raw | ConvertFrom-Yaml

    $environments = if ($env:BuildEnvironment)
    {
        $datum.Global.Azure.Environments.GetEnumerator().Where({ $_.Name -eq $env:BuildEnvironment })
    }
    else
    {
        $datum.Global.Azure.Environments.GetEnumerator()
    }

    foreach ($env in $environments)
    {
        Write-Host "Exporting configuration for environment '$($env.Name)'" -ForegroundColor Yellow
        if (-not $env.Value.AzTenantId)
        {
            Write-Error "AzTenantId is not defined for environment $($env.Name)" -ErrorAction Stop
        }

        $exportApp = $env.Value.Identities | Where-Object { $_.Name -EQ 'M365DscExportApplication' -or $_.IsExportApplication -eq $true }
        if ($null -eq $exportApp)
        {
            Write-Error "Export application 'M365DscExportApplication' is not defined for environment '$($env.Name)' and is no application with 'IsExportApplication' set to true" -ErrorAction Stop
        }

        foreach ($dscresource in $exportConfig.DscResources)
        {
            $exportParams = @{
                Components    = $dscresource
                ApplicationId = $exportApp.ApplicationId
                TenantId      = $env.Value.AzTenantName
                Path          = "$OutputDirectory\Export\$($env.Value.AzTenantName)\$dscresource"
            }

            if ($null -ne $exportApp.CertificateThumbprint)
            {
                $exportParams.CertificateThumbprint = $exportApp.CertificateThumbprint
            }
            elseif ($null -ne $exportApp.ApplicationSecret)
            {
                $exportParams.ApplicationSecret = $exportApp.applicationSecret
            }
            elseif ($exportApp.IsManagedIdentity)
            {
                $exportParams.ManagedIdentity = $true
                $exportParams.Remove('ApplicationId')
            }
            else
            {
                Write-Error "Export application '$($exportApp.Name)' does not have a certificate thumbprint or application secret defined for environment '$($env.Name)'" -ErrorAction Stop
            }

            Write-Host '------------------ Export Parameters ------------------' -ForegroundColor Yellow
            $exportParams | Out-String | Write-Host -ForegroundColor DarkGray
            Write-Host '-------------------------------------------------------' -ForegroundColor Yellow

            Export-M365DSCConfiguration @exportParams
        }

    }

}

task InvokingDscExportConfiguration {

    Write-Host 'Invoking DSC configurations' -ForegroundColor Yellow
    Remove-Module -Name PSDesiredStateConfiguration -Force -ErrorAction SilentlyContinue

    $environments = if ($env:BuildEnvironment)
    {
        $datum.Global.Azure.Environments.GetEnumerator().Where({ $_.Name -eq $env:BuildEnvironment })
    }
    else
    {
        $datum.Global.Azure.Environments.GetEnumerator()
    }

    foreach ($env in $environments)
    {
        Write-Host "    Invoking DSC configuration for environment '$($env.Name)'" -ForegroundColor Yellow

        $tenantExportDirectory = dir -Path "$OutputDirectory\export" -Directory |
            Where-Object { $_.Name -eq $env.Value.AzTenantName }

        $dscResourceDirectories = dir -Path $tenantExportDirectory -Directory
        foreach ($dscResourceDirectory in $dscResourceDirectories)
        {
            $dscResourceDirectory | Set-Location

            Write-Host "Invoking DSC configuration in directory '$($dscResourceDirectory.FullName)'" -ForegroundColor Yellow
            try
            {
                dir -Path $Path -Recurse -Filter *.ps1 | ForEach-Object { & $_.FullName }
                Write-Host "        DSC configuration in folder '$($dscResourceDirectory.BaseName)' was successfully compiled." -ForegroundColor Green
            }
            catch
            {
                Write-Host "An exception occurred compiling the DSC configuration in folder '$($dscResourceDirectory.BaseName)'. Please see the error above."
            }
        }
    }

    Set-Location -Path $ProjectPath

}

task ConvertMofToYaml {

    $allModules = Get-ModuleFromFolder -ModuleFolder .\output\RequiredModules\
    $m365dscModule = $allModules | Where-Object { $_.Name -eq 'Microsoft365DSC' }
    $modulesWithDscResources = Get-DscResourceFromModuleInFolder -ModuleFolder .\output\RequiredModules\ -Modules $m365dscModule
    $resourceTypes = $modulesWithDscResources | Select-Object -ExpandProperty ResourceType

    $tenants = Get-ChildItem -Path "$OutputDirectory\export" -Directory

    foreach ($tenant in $tenants)
    {
        $dscresources = dir -Path $tenant -Directory
        foreach ($dscresource in $dscresources)
        {
            $mofFile = dir -Path $dscresource -Filter *.mof -Recurse
            if ($mofFile)
            {
                Write-Host "Converting MOF file '$($mofFile.FullName)' to YAML" -ForegroundColor Green
                $tenantData = Convert-MofToYaml -Path $mofFile.FullName
                $copiedData = Copy-YamlData -Data $tenantData -AllData $tenantData -ResourceTypes $resourceTypes

                Write-Host 'Exporting tenant configuration to the output folder as YAML' -ForegroundColor Yellow
                $copiedData | ConvertTo-Yaml | Out-File "$OutputDirectory\export\$($tenant.Name)\$($dscresource.Name).yml" -Force
            }
            else
            {
                Write-Host "No MOF file found in '$($dscresource.FullName)', skipping." -ForegroundColor Yellow
            }
        }
    }

}
