[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Required for UI display')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'The tasks read the parameters from the script scope')]
param
(
    # Project path
    [Parameter()]
    [System.String]
    $ProjectPath = (property ProjectPath $BuildRoot),

    # Base directory of all output (default to 'output')
    [Parameter()]
    [System.String]
    $OutputDirectory = (property OutputDirectory (Join-Path -Path $BuildRoot -ChildPath output)),

    [Parameter()]
    [System.String]
    $RequiredModulesDirectory = (property RequiredModulesDirectory 'RequiredModules'),

    [Parameter()]
    [System.String]
    $CompressedModulesFolder = (property CompressedModulesFolder 'CompressedModules'),

    [Parameter()]
    [System.Int32]
    $CurrentJobNumber = (property CurrentJobNumber 1)
)

# Synopsis: Prepares the DSC engine and the resource metadata so that CompileRootConfiguration takes minutes, not hours, with class-based resource modules.
# UPSTREAM: SDP-2, SDP-4, DBH-1 (see docs/upstream-changes.md)
task PrepareDscCompile {
    $RequiredModulesDirectory = Get-SamplerAbsolutePath -Path $RequiredModulesDirectory -RelativeTo $OutputDirectory

    # source\CompileRootConfiguration.ps1, source\RootConfiguration.ps1, the task CompressModulesWithChecksum below and
    # .build\DscCompileHelpers.ps1 shadow or call into these modules, which RequiredModules.psd1 pins to 'latest'. Compare
    # the overrides with a newer release, then update the versions here.
    $reviewedVersion = @{
        'Sampler.DscPipeline' = '0.3.0'
        DscBuildHelpers       = '0.4.0'
    }

    foreach ($deviation in Get-ModuleVersionDeviation -Baseline $reviewedVersion)
    {
        Write-Warning -Message "$($deviation.Name) $($deviation.Actual) is available, but the DSC compile overrides of this project were written for $($deviation.Expected) and shadow it. Compare them with the new version, then update the reviewed versions in '.build\DscCompileTasks.ps1'."
    }

    # Microsoft365DSC 2.x adds a second DSC engine to the modules. The first Get-DscResource of the build would load it by
    # module auto-loading, and the pinned PSDesiredStateConfiguration would be loaded next to it later.
    $engine = Initialize-StandardDscEngine -RequiredModulesFile (Join-Path -Path $ProjectPath -ChildPath 'RequiredModules.psd1')
    Write-Build DarkGray "`tDSC engine: $($engine.Name) $($engine.Version) is the only module of that name."

    Import-Module -Name DscBuildHelpers

    $rsopCache = Get-DatumRsopCache

    if (-not $rsopCache)
    {
        Write-Error -Message "No RSOP cache found. The task 'CompileDatumRsop' must be run before this task." -ErrorAction Stop
    }

    $usedConfigurationName = @(foreach ($node in $rsopCache.GetEnumerator())
        {
            $node.Value.Configurations
        }) | Select-Object -Unique

    $composite = @(Resolve-DscCompositeResource -ModulePath $RequiredModulesDirectory -Name $usedConfigurationName)

    Write-Build DarkGray "`tThe nodes use $($usedConfigurationName.Count) configurations, $($composite.Count) of them are composite resources."

    if ($composite.Count -eq 0)
    {
        return
    }

    # Sampler.DscPipeline calls Initialize-DscResourceMetaInfo for every resource of every module. That function returns at once
    # when its table is filled, so the table is filled for the resources that the used composite resources wrap.
    $summary = Initialize-DscResourceMetaInfoForComposite -Composite $composite

    Write-Build DarkGray "`tResource metadata: $($summary.EntryCount) entries from $($summary.ResourceCount) resources and types in $([System.Math]::Round($summary.Duration.TotalSeconds, 1)) seconds."
}

<#
    Replaces the task of the same name in Sampler.DscPipeline 0.3.0 (the .build folder overrides tasks of the pipeline modules).
    The only change is the selection of the modules: the original lists every DSC resource of every module with
    Get-DscResourceFromModuleInFolder, which imports every composite resource on the way and took 24 minutes with
    class-based modules (see .build\DscCompileHelpers.ps1).

    UPSTREAM: SDP-3 (see docs/upstream-changes.md)
#>
# Synopsis: Compresses every module that contains DSC resources and writes a checksum file next to each archive.
task CompressModulesWithChecksum {
    . Set-SamplerTaskVariable -AsNewBuild

    $CompressedModulesFolder = Get-SamplerAbsolutePath -Path $CompressedModulesFolder -RelativeTo $OutputDirectory
    $RequiredModulesDirectory = Get-SamplerAbsolutePath -Path $RequiredModulesDirectory -RelativeTo $OutputDirectory

    if ($SkipCompressedModulesBuild)
    {
        Write-Build Yellow 'Skipping preparation of Compressed Modules as $SkipCompressedModulesBuild is set'
        return
    }

    if (-not (Test-Path -Path $CompressedModulesFolder))
    {
        $null = New-Item -Path $CompressedModulesFolder -ItemType Directory -Force
    }

    if ($configurationData.AllNodes -and $CurrentJobNumber -eq 1)
    {
        $previousProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        # Only zip up the modules that have exported DSC resources. As in the original task, every version of such a module is zipped.
        $allModules = Get-ModuleFromFolder -ModuleFolder $RequiredModulesDirectory
        $moduleNameWithDscResources = @($allModules | Get-ModuleWithDscResource | Select-Object -ExpandProperty Name -Unique)
        $modulesWithDscResources = $allModules | Where-Object -Property Name -In -Value $moduleNameWithDscResources

        # As outlined here: https://docs.microsoft.com/en-us/dotnet/api/system.io.compression.zipfile?view=net-6.0#remarks
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        foreach ($module in $modulesWithDscResources)
        {
            $destinationPath = Join-Path -Path $CompressedModulesFolder -ChildPath "$($module.Name)_$($module.Version).zip"

            Write-Host "Compressing module '$($module.Name)' to '$destinationPath'"
            [System.IO.Compression.ZipFile]::CreateFromDirectory($module.ModuleBase, $destinationPath, 'Fastest', $false)
            $hash = (Get-FileHash -Path $destinationPath).Hash

            try
            {
                $stream = New-Object -TypeName System.IO.StreamWriter("$destinationPath.checksum", $false)
                [void] $stream.Write($hash)
            }
            finally
            {
                if ($stream)
                {
                    $stream.Close()
                }
            }
        }

        $ProgressPreference = $previousProgressPreference
    }
    else
    {
        Write-Build Green "No data in 'ConfigurationData.AllNodes', skipping task 'CompressModulesWithChecksum'."
    }
}
