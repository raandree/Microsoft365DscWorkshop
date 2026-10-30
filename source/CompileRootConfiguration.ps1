[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Required for UI display')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '', Justification = 'Required for DSL-like look of function calls')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Required for dynamic configuration compilation')]

param ()

<#
    This is Scripts\CompileRootConfiguration.ps1 of Sampler.DscPipeline 0.3.0 with one change: the step 'Preloading
    available resources' runs 'Get-DscResource' without a filter. That call imports every composite resource module
    of 'output\RequiredModules', and every import of a composite resource of DscConfig.M365 makes the DSC engine parse
    the 10 MB of Microsoft365DSC 2.x classes again, so the call takes about 21 minutes. The composite resources that
    the nodes use are looked up in the folder layout instead (see .build\DscCompileHelpers.ps1).

    UPSTREAM: SDP-1 (see docs/upstream-changes.md)
#>

if (-not (Get-Command -Name Resolve-DscCompositeResource -ErrorAction SilentlyContinue))
{
    throw "The function 'Resolve-DscCompositeResource' is not available. Run this script through the build, '.\build.ps1', which loads '.build\DscCompileHelpers.ps1'."
}

Import-Module -Name DscBuildHelpers
$Error.Clear()

if (-not $ModuleVersion)
{
    $ModuleVersion = '0.0.0'
}

$environment = $node.Environment
if (-not $environment)
{
    $environment = 'NA'
}

#Compiling MOF from RSOP cache
$rsopCache = Get-DatumRsopCache

<#
This information is taken from build.yaml

Sampler.DscPipeline:
  DscCompositeResourceModules:
  - Name: CommonTasks
    Version: 0.3.259
  - PSDesiredStateConfiguration
#>

if (-not $BuildInfo.'Sampler.DscPipeline')
{
    Write-Error -Message "There are no modules to import defined in the 'build.yml'. Expected the element 'Sampler.DscPipeline'"
}
if (-not $BuildInfo.'Sampler.DscPipeline'.DscCompositeResourceModules)
{
    Write-Error -Message "There are no modules to import defined in the 'build.yml'. Expected the element 'Sampler.DscPipeline'.DscCompositeResourceModules"
}
if ($BuildInfo.'Sampler.DscPipeline'.DscCompositeResourceModules.Count -lt 1)
{
    Write-Error -Message "There are no modules to import defined in the 'build.yml'. Expected at least one module defined under 'Sampler.DscPipeline'.DscCompositeResourceModules"
}

Write-Host -Object "RootConfiguration will import these composite resource modules as defined in 'build.yaml':"
foreach ($module in $BuildInfo.'Sampler.DscPipeline'.DscCompositeResourceModules)
{
    if ($module -is [hashtable])
    {
        Write-Host -Object "`t- $($module.Name) ($($module.Version))"
    }
    else
    {
        Write-Host -Object "`t- $module"
    }
}

Write-Host -Object ''
Write-Host -Object 'Looking up the resources of the nodes'

if (-not $rsopCache)
{
    Write-Error -Message "No RSOP cache found. The task 'CompileDatumRsop' must be run before this task." -ErrorAction Stop
}

$usedConfigurationName = @(foreach ($rsopNode in $rsopCache.GetEnumerator())
    {
        $rsopNode.Value.Configurations
    }) | Select-Object -Unique

$availableResources = @(Resolve-DscCompositeResource -ModulePath $RequiredModulesDirectory -Name $usedConfigurationName)

# A configuration that is not a composite resource can still be the DSC resource of a module. Get-DscResource finds it,
# but it imports every composite resource on the way, which is slow with class-based modules.
$resourceNotFound = @($usedConfigurationName | Where-Object -FilterScript { $_ -notin $availableResources.Name })
if ($resourceNotFound)
{
    Write-Warning -Message "No composite resource was found for: $($resourceNotFound -join ', '). Falling back to Get-DscResource, which is slow with class-based modules."

    try
    {
        $availableResources += @(Get-DscResource -Name $resourceNotFound)
    }
    catch
    {
        Write-Error -Message "There was error while loading DSC resources. The error was: $($_.Exception.Message)" -Exception $_.Exception
    }
}

Write-Host -Object ''

$configData = @{}
$configData.Datum = $ConfigurationData.Datum

foreach ($node in $rsopCache.GetEnumerator())
{
    $importStatements = foreach ($configurationItem in $node.Value.Configurations)
    {
        $resource = $availableResources.Where({ $_.Name -eq $configurationItem })
        if ($null -eq $resource -or $resource.Count -eq 0)
        {
            Write-Error -Message "The DSC resource '$configurationItem' was not found in any DSC resource module." -ErrorAction Stop
            continue
        }
        if ($resource.Count -gt 1)
        {
            Write-Error -Message "The DSC resource '$configurationItem' was found in multiple DSC resource modules. Unable to determine which one to import." -ErrorAction Stop
        }

        "Import-DscResource -ModuleName $($resource.ModuleName) -ModuleVersion $($resource.Version) -Name $($resource.Name)`n"
    }

    $rootConfiguration = Get-Content -Path $PSScriptRoot\RootConfiguration.ps1 -Raw
    $rootConfiguration = $rootConfiguration -replace '#<importStatements>', ($importStatements | Select-Object -Unique)

    Invoke-Expression -Command $rootConfiguration

    $configData.AllNodes = @([hashtable]$node.Value)
    try
    {
        $path = Join-Path -Path MOF -ChildPath $node.Value.Environment
        RootConfiguration -ConfigurationData $configData -OutputPath (Join-Path -Path $BuildOutput -ChildPath $path)
    }
    catch
    {
        Write-Host -Object "Error occured during compilation of node '$($node.NodeName)' : $($_.Exception.Message)" -ForegroundColor Red
        $relevantErrors = $Error | Where-Object Exception -IsNot [System.Management.Automation.ItemNotFoundException]
        foreach ($relevantError in ($relevantErrors | Select-Object -First 3))
        {
            Write-Error -ErrorRecord $relevantError
        }
    }
}
