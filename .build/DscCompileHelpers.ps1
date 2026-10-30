# Helpers for compiling the DSC configuration with class-based resource modules such as Microsoft365DSC 2.x.
#
# The Sampler.DscPipeline build enumerates every DSC resource of every module in 'output\RequiredModules' twice
# (Initialize-DscResourceMetaInfo and Get-DscResource), and Get-DscResource imports every composite resource module
# on the way. A composite resource of DscConfig.M365 contains 'Import-DscResource -ModuleName Microsoft365DSC', and the
# DSC engine parses all 10 MB of Microsoft365DSC classes again for each of these statements (about 4 to 8 seconds
# each, 179 composites). The functions below look up only what the nodes use. The file is dot-sourced by build.ps1 and
# by the tests, so it must contain nothing but function definitions.

function Resolve-DscCompositeResource
{
    <#
        .SYNOPSIS
            Finds the modules and versions that provide composite resources, without loading any module.

        .DESCRIPTION
            Get-DscResource imports every composite resource of every module in the module path before it filters by
            name. This function reads the folder layout instead: a composite resource is a folder
            'DscResources\<Name>' that holds '<Name>.schema.psm1'. One object is returned for each module version that
            provides a requested name, so a name that more than one module or version provides stays visible to the
            caller, as it is with Get-DscResource.

        .PARAMETER ModulePath
            The folder that holds the modules, for example 'output\RequiredModules'.

        .PARAMETER Name
            The names of the composite resources to look for. The comparison ignores case.

        .OUTPUTS
            PSCustomObject with the properties Name, ModuleName, Version, ModuleBase and SchemaPath.

        .NOTES
            UPSTREAM: SDP-1. This is the lookup that Sampler.DscPipeline needs instead of the unfiltered Get-DscResource of
            its CompileRootConfiguration.ps1. See docs/upstream-changes.md.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ModulePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String[]]
        $Name
    )

    if (-not (Test-Path -Path $ModulePath -PathType Container))
    {
        throw "The module path '$ModulePath' does not exist."
    }

    $requestedName = [System.Collections.Generic.HashSet[System.String]]::new($Name, [System.StringComparer]::OrdinalIgnoreCase)

    foreach ($moduleFolder in Get-ChildItem -Path $ModulePath -Directory)
    {
        # A module is stored as '<Module>\<Version>', or directly in '<Module>' when it has no version folder.
        $moduleBase = @($moduleFolder.FullName) + @(Get-ChildItem -Path $moduleFolder.FullName -Directory | ForEach-Object -Process { $_.FullName })

        foreach ($baseFolder in $moduleBase)
        {
            $dscResourcesFolder = Join-Path -Path $baseFolder -ChildPath 'DscResources'

            if (-not (Test-Path -Path $dscResourcesFolder -PathType Container))
            {
                continue
            }

            $moduleVersion = $null

            foreach ($compositeFolder in Get-ChildItem -Path $dscResourcesFolder -Directory)
            {
                if (-not $requestedName.Contains($compositeFolder.Name))
                {
                    continue
                }

                $schemaPath = Join-Path -Path $compositeFolder.FullName -ChildPath "$($compositeFolder.Name).schema.psm1"

                if (-not (Test-Path -Path $schemaPath -PathType Leaf))
                {
                    continue
                }

                if ($null -eq $moduleVersion)
                {
                    $manifestPath = Join-Path -Path $baseFolder -ChildPath "$($moduleFolder.Name).psd1"
                    $moduleVersion = if (Test-Path -Path $manifestPath -PathType Leaf)
                    {
                        [System.Version](Import-PowerShellDataFile -Path $manifestPath).ModuleVersion
                    }
                    else
                    {
                        [System.Version]'0.0'
                    }
                }

                [PSCustomObject]@{
                    Name       = $compositeFolder.Name
                    ModuleName = $moduleFolder.Name
                    Version    = $moduleVersion
                    ModuleBase = $baseFolder
                    SchemaPath = $schemaPath
                }
            }
        }
    }
}

function Get-DscCompositeResourceDetail
{
    <#
        .SYNOPSIS
            Reads which resource a composite resource wraps and which modules it imports.

        .DESCRIPTION
            The composite resources that DscConfig.M365 generates assign the name of the wrapped resource once to
            '$dscResourceName' and pass it to Get-DscSplattedResource. The function reads that assignment and the
            'Import-DscResource' statements from the text of the schema file. Hand written composite resources, such as
            DscTagging, usually name their resources directly and have no such assignment.

        .PARAMETER Path
            The path of the '<Name>.schema.psm1' file.

        .OUTPUTS
            PSCustomObject with the properties Path, InnerResourceName, ImportedModule (objects with Name and Version,
            without PSDesiredStateConfiguration) and UsesSplattedResource.

        .NOTES
            UPSTREAM: DBH-1. Reading the text of a schema file relies on the convention of the generated composite resources
            and is the weakest part of the workaround. See docs/upstream-changes.md for the alternatives.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Path
    )

    $line = Get-Content -LiteralPath $Path

    $innerResourceName = foreach ($text in $line)
    {
        if ($text -match '^\s*\$dscResourceName\s*=\s*''(?<name>[^'']+)''')
        {
            $Matches['name']
        }
    }

    $importedModule = foreach ($text in $line)
    {
        if ($text -notmatch '^\s*Import-DscResource\b' -or $text -notmatch '-ModuleName\s+(?<name>[\w.]+)')
        {
            continue
        }

        $moduleName = $Matches['name']
        $moduleVersion = if ($text -match '-ModuleVersion\s+(?<version>\d+(\.\d+){1,3})')
        {
            [System.Version]$Matches['version']
        }

        if ($moduleName -ne 'PSDesiredStateConfiguration')
        {
            [PSCustomObject]@{
                Name    = $moduleName
                Version = $moduleVersion
            }
        }
    }

    [PSCustomObject]@{
        Path                 = $Path
        InnerResourceName    = @($innerResourceName | Select-Object -Unique)
        ImportedModule       = @($importedModule)
        UsesSplattedResource = [bool]($line -match 'Get-DscSplattedResource')
    }
}

function Get-ModuleWithDscResource
{
    <#
        .SYNOPSIS
            Selects the modules that contain DSC resources, without loading any resource.

        .DESCRIPTION
            Sampler.DscPipeline finds these modules with Get-DscResourceFromModuleInFolder, which lists every DSC resource
            of every module and imports every composite resource on the way. This function applies the rule by which
            Get-DscResource of PSDesiredStateConfiguration 2.0.8 yields resources: a module has DSC resources when
            'Get-Module -ListAvailable' reports exported resources for it (class-based resources), or when its 'DscResources'
            folder contains a resource folder (MOF based and composite resources). An empty 'DscResources' folder does not
            count, and neither does a manifest that lists 'DscResourcesToExport' without the engine reporting any resource.

        .PARAMETER Module
            The modules to select from, for example the result of Get-ModuleFromFolder.

        .OUTPUTS
            System.Management.Automation.PSModuleInfo

        .NOTES
            UPSTREAM: SDP-3. This is the module selection that the CompressModulesWithChecksum task of Sampler.DscPipeline
            needs instead of Get-DscResourceFromModuleInFolder. See docs/upstream-changes.md.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSModuleInfo])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Management.Automation.PSModuleInfo[]]
        $Module
    )

    process
    {
        foreach ($item in $Module)
        {
            $exportsDscResource = $item.ExportedDscResources.Count -gt 0

            $dscResourcesFolder = Join-Path -Path $item.ModuleBase -ChildPath 'DscResources'
            $hasResourceFolder = (Test-Path -Path $dscResourcesFolder -PathType Container) -and
            [bool](Get-ChildItem -Path $dscResourcesFolder -Directory | Select-Object -First 1)

            if ($exportsDscResource -or $hasResourceFolder)
            {
                $item
            }
        }
    }
}

function Get-ModuleVersionDeviation
{
    <#
        .SYNOPSIS
            Returns the modules whose newest available version is not the version that a customization was written for.

        .DESCRIPTION
            The customizations of this project copy or call into modules that are pinned to 'latest' in RequiredModules.psd1:
            source\CompileRootConfiguration.ps1 and source\RootConfiguration.ps1 shadow the scripts of Sampler.DscPipeline,
            and Initialize-DscResourceMetaInfoForComposite writes private variables of DscBuildHelpers. A newer release of
            either module is not noticed otherwise, because the copy keeps running instead of the new original.

        .PARAMETER Baseline
            The module names and the version each one was last reviewed against.

        .OUTPUTS
            PSCustomObject with the properties Name, Expected and Actual. A module that is not available is not reported.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]
        $Baseline
    )

    foreach ($name in $Baseline.Keys)
    {
        $newest = Get-Module -Name $name -ListAvailable -ErrorAction SilentlyContinue |
            Sort-Object -Property Version -Descending |
                Select-Object -First 1

        if ($newest -and $newest.Version -ne [System.Version]$Baseline[$name])
        {
            [PSCustomObject]@{
                Name     = $name
                Expected = [System.Version]$Baseline[$name]
                Actual   = $newest.Version
            }
        }
    }
}

function Initialize-StandardDscEngine
{
    <#
        .SYNOPSIS
            Makes the pinned PSDesiredStateConfiguration module the only DSC engine of the session.

        .DESCRIPTION
            Microsoft365DSC 2.x requires M365DSC.PSDesiredStateConfiguration, a second DSC engine. By design it claims the
            module name PSDesiredStateConfiguration with a compatibility module of its own (version 3.1.10), so that the
            engine of a configuration resolves to it. When nothing has imported PSDesiredStateConfiguration before the first
            Get-DscResource, module auto-loading resolves that command to the first module on the module path that exports
            it. Both engines export it, and in 'output\RequiredModules' both sit in one folder, where the name
            M365DSC.PSDesiredStateConfiguration sorts first, so the M365DSC engine is loaded. The later
            'Import-DscResource -ModuleName PSDesiredStateConfiguration' then loads the pinned
            module as a second one, 'Get-Module -Name PSDesiredStateConfiguration' returns two modules, and
            RootConfiguration.ps1 of Sampler.DscPipeline fails with 'The term ''PSDesiredStateConfiguration
            PSDesiredStateConfiguration'' is not recognized'. The fast compile path of the M365DSC engine does not support
            composite resources, and its schema cache did not make 'Import-DscResource -ModuleName Microsoft365DSC' cheaper
            in a measurement, so the build uses the pinned engine alone.

        .PARAMETER RequiredModulesFile
            The path of RequiredModules.psd1. The pin of PSDesiredStateConfiguration is imported when it names a version.

        .OUTPUTS
            System.Management.Automation.PSModuleInfo of the imported module.

        .NOTES
            UPSTREAM: SDP-4, M365PSDSC-1. See docs/upstream-changes.md.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSModuleInfo])]
    param (
        [Parameter()]
        [System.String]
        $RequiredModulesFile
    )

    $requiredVersion = $null

    if ($RequiredModulesFile -and (Test-Path -Path $RequiredModulesFile -PathType Leaf))
    {
        $pin = (Import-PowerShellDataFile -Path $RequiredModulesFile)['PSDesiredStateConfiguration']

        if ($pin -is [System.Collections.Hashtable])
        {
            $pin = $pin.Version
        }

        if ($pin -and $pin -ne 'latest')
        {
            $requiredVersion = [System.Version]$pin
        }
    }

    Get-Module -Name M365DSC.PSDesiredStateConfiguration | Remove-Module -Force

    Get-Module -Name PSDesiredStateConfiguration |
        Where-Object -FilterScript { $requiredVersion -and $_.Version -ne $requiredVersion } |
            Remove-Module -Force

    $importParameters = @{
        Name          = 'PSDesiredStateConfiguration'
        Global        = $true
        ErrorAction   = 'Stop'
        WarningAction = 'SilentlyContinue'
    }

    if ($requiredVersion)
    {
        $importParameters.RequiredVersion = $requiredVersion
    }

    $null = Import-Module @importParameters

    $loadedModule = @(Get-Module -Name PSDesiredStateConfiguration)

    if ($loadedModule.Count -ne 1)
    {
        throw "Expected exactly one loaded module named 'PSDesiredStateConfiguration' but found $($loadedModule.Count): $(($loadedModule | ForEach-Object -Process { "$($_.Name) $($_.Version)" }) -join ', ')."
    }

    $loadedModule[0]
}

function Initialize-DscResourceMetaInfoForComposite
{
    <#
        .SYNOPSIS
            Fills the resource metadata of DscBuildHelpers for the resources that composite resources use.

        .DESCRIPTION
            Initialize-DscResourceMetaInfo calls the private function Get-DscResourceProperty for every resource of every
            module in a path. With Microsoft365DSC 2.x that is about 1,400 calls of up to two seconds each, because the
            module has 541 resources and 525 embedded types. Get-DscSplattedResource only needs the entries of the
            resources that the compiled composite resources call, and of the embedded types of their properties.

            This function computes exactly these entries, with the same private functions and the same filter, in the
            scope of DscBuildHelpers and stores them in the variables that Initialize-DscResourceMetaInfo fills. That
            function then returns at once when Sampler.DscPipeline calls it, because its table is no longer empty.

            Replace this function by a resource filter in Initialize-DscResourceMetaInfo when DscBuildHelpers offers one.

            Limits of this workaround: it supports class-based resources only, because it leaves the schema classes of MOF
            based resources (the variable allDscSchemaClasses) empty. It finds the wrapped resource by the generated
            '$dscResourceName' of the composite resource. It writes three private variables of DscBuildHelpers 0.4.0.

        .PARAMETER Composite
            The composite resources that the nodes use, as returned by Resolve-DscCompositeResource.

        .OUTPUTS
            PSCustomObject with the properties ResourceCount (resources and embedded types that were read), EntryCount
            (entries in the table) and Duration.

        .NOTES
            UPSTREAM: DBH-1, SDP-2. See docs/upstream-changes.md.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Object[]]
        $Composite
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $dscBuildHelpers = Get-Module -Name DscBuildHelpers

    if (-not $dscBuildHelpers)
    {
        throw "The module 'DscBuildHelpers' must be imported before the resource metadata can be initialized."
    }

    $workItem = [System.Collections.Generic.List[System.Object]]::new()

    foreach ($compositeResource in $Composite)
    {
        $detail = Get-DscCompositeResourceDetail -Path $compositeResource.SchemaPath

        if (-not $detail.InnerResourceName)
        {
            if ($detail.UsesSplattedResource)
            {
                Write-Warning -Message "The composite resource '$($compositeResource.Name)' calls Get-DscSplattedResource but names no resource in '`$dscResourceName'. The metadata of CIM typed properties of its resources is not initialized."
            }
            else
            {
                Write-Verbose -Message "The composite resource '$($compositeResource.Name)' does not use Get-DscSplattedResource, no metadata is needed."
            }

            continue
        }

        foreach ($innerResourceName in $detail.InnerResourceName)
        {
            $candidate = foreach ($import in $detail.ImportedModule)
            {
                $listParameters = @{
                    ListAvailable = $true
                    Name          = $import.Name
                    ErrorAction   = 'SilentlyContinue'
                }

                Get-Module @listParameters |
                    Where-Object -FilterScript { -not $import.Version -or $_.Version -eq $import.Version } |
                        Sort-Object -Property Version -Descending |
                            Select-Object -First 1
            }

            $moduleInfo = @($candidate | Where-Object -FilterScript { $_.ExportedDscResources -contains $innerResourceName }) | Select-Object -First 1

            if (-not $moduleInfo -and @($candidate).Count -eq 1)
            {
                $moduleInfo = $candidate
            }

            if (-not $moduleInfo)
            {
                Write-Warning -Message "The module of the resource '$innerResourceName' that the composite resource '$($compositeResource.Name)' wraps was not found among its imports. The metadata of its CIM typed properties is not initialized."
                continue
            }

            $workItem.Add([PSCustomObject]@{
                    ResourceName = $innerResourceName
                    ModuleInfo   = $moduleInfo
                })
        }
    }

    $resourceCount = & $dscBuildHelpers {
        param (
            [System.Object[]]
            $WorkItem
        )

        $script:standardCimTypes = Get-StandardCimType
        $script:allDscSchemaClasses = @()
        $script:allDscResourcePropertiesTable = @{}

        $queue = [System.Collections.Generic.Queue[System.Object]]::new()
        $seen = [System.Collections.Generic.HashSet[System.String]]::new([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($item in $WorkItem)
        {
            if ($seen.Add($item.ResourceName))
            {
                $queue.Enqueue($item)
            }
        }

        $processed = 0

        while ($queue.Count -gt 0)
        {
            $current = $queue.Dequeue()
            $processed++

            $property = Get-DscResourceProperty -ModuleInfo $current.ModuleInfo -ResourceName $current.ResourceName |
                Where-Object -Property TypeConstraint -NotIn -Value ($script:standardCimTypes.CimType -notlike 'MSFT_KeyValuePair*')

            foreach ($cimProperty in $property)
            {
                $script:allDscResourcePropertiesTable."$($current.ResourceName)-$($cimProperty.Name)" = $cimProperty

                # The embedded type is written as a resource of its own, so its properties are needed as well.
                $typeName = $cimProperty.TypeConstraint -replace '\[\]', ''

                if ($seen.Add($typeName))
                {
                    $queue.Enqueue([PSCustomObject]@{
                            ResourceName = $typeName
                            ModuleInfo   = $current.ModuleInfo
                        })
                }
            }
        }

        $processed
    } $workItem.ToArray()

    [PSCustomObject]@{
        ResourceCount = $resourceCount
        EntryCount    = & $dscBuildHelpers { $script:allDscResourcePropertiesTable.Count }
        Duration      = $stopwatch.Elapsed
    }
}
