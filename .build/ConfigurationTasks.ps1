task StartDscConfiguration {

    $environment = $env:buildEnvironment
    if (-not $environment)
    {
        Write-Error 'The build environment is not set'
    }

    $MofOutputDirectory = Join-Path -Path $OutputDirectory -ChildPath $MofOutputFolder

    $programFileModulePath = 'C:\Program Files\WindowsPowerShell\Modules'
    $modulesToKeep = 'Microsoft.PowerShell.Operation.Validation', 'PackageManagement', 'Pester', 'PowerShellGet', 'PSReadline'

    dir -Path $programFileModulePath | Where-Object { $_.BaseName -notin $modulesToKeep } | Remove-Item -Recurse -Force

    dir -Path $requiredModulesPath | Copy-Item -Destination $programFileModulePath -Recurse -Force

    Start-DscConfiguration -Path "$MofOutputDirectory\$environment" -Wait -Verbose -Force

}

task TestDscConfiguration {
    $result = Test-DscConfiguration -Detailed

    if ($result.ResourcesNotInDesiredState)
    {
        Write-Host "The following $($result.ResourcesNotInDesiredState.ResourceId.Count) resources are not in the desired state:"

        foreach ($resourceId in $result.ResourcesNotInDesiredState.ResourceId)
        {
            Write-Host "`t$resourceId"
        }

        Write-Error 'Resources are not in desired state as listed above'
    }
    else
    {
        Write-Host 'All resources are in the desired state' -ForegroundColor Green
    }
}
