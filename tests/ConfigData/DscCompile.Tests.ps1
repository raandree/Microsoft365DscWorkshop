BeforeDiscovery {
    $requiredModulesDirectory = Join-Path -Path $PSScriptRoot -ChildPath '..\..\output\RequiredModules'
    $hasM365Composites = [bool](Get-ChildItem -Path (Join-Path -Path $requiredModulesDirectory -ChildPath 'DscConfig.M365\*\DscResources') -Directory -ErrorAction SilentlyContinue)
}

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '..\..\.build\DscCompileHelpers.ps1')

    $requiredModulesDirectory = Join-Path -Path $PSScriptRoot -ChildPath '..\..\output\RequiredModules'
}

Describe 'Resolve-DscCompositeResource' -Tag Integration {
    BeforeAll {
        function Add-FakeModule
        {
            param (
                [string] $Root,
                [string] $Name,
                [string] $Version,
                [string[]] $Composite,
                [string[]] $FolderWithoutSchema = @()
            )

            $base = Join-Path -Path $Root -ChildPath "$Name\$Version"
            $null = New-Item -Path $base -ItemType Directory -Force
            Set-Content -Path (Join-Path -Path $base -ChildPath "$Name.psd1") -Value "@{ ModuleVersion = '$Version' }"

            foreach ($compositeName in $Composite)
            {
                $folder = Join-Path -Path $base -ChildPath "DscResources\$compositeName"
                $null = New-Item -Path $folder -ItemType Directory -Force
                Set-Content -Path (Join-Path -Path $folder -ChildPath "$compositeName.schema.psm1") -Value "configuration $compositeName { }"
            }

            foreach ($compositeName in $FolderWithoutSchema)
            {
                $null = New-Item -Path (Join-Path -Path $base -ChildPath "DscResources\$compositeName") -ItemType Directory -Force
            }
        }

        $root = Join-Path -Path $TestDrive -ChildPath 'RequiredModules'
        Add-FakeModule -Root $root -Name 'DscConfig.A' -Version '1.0.0' -Composite 'cOne', 'cTwo' -FolderWithoutSchema 'cBroken'
        Add-FakeModule -Root $root -Name 'DscConfig.A' -Version '2.0.0' -Composite 'cOne'
        Add-FakeModule -Root $root -Name 'DscConfig.B' -Version '3.1.0' -Composite 'cTwo', 'cThree'
        Add-FakeModule -Root $root -Name 'NoComposites' -Version '1.0.0' -Composite @()
        $script:fakeRoot = $root
    }

    It 'Should return the module, version and schema path of a composite' {
        $result = Resolve-DscCompositeResource -ModulePath $script:fakeRoot -Name 'cThree'

        $result | Should -HaveCount 1
        $result.Name | Should -Be 'cThree'
        $result.ModuleName | Should -Be 'DscConfig.B'
        $result.Version | Should -Be ([version]'3.1.0')
        $result.ModuleBase | Should -Be (Join-Path -Path $script:fakeRoot -ChildPath 'DscConfig.B\3.1.0')
        $result.SchemaPath | Should -Be (Join-Path -Path $script:fakeRoot -ChildPath 'DscConfig.B\3.1.0\DscResources\cThree\cThree.schema.psm1')
    }

    It 'Should return one result per module version that provides the name so that an ambiguity stays visible' {
        $result = Resolve-DscCompositeResource -ModulePath $script:fakeRoot -Name 'cOne'

        $result | Should -HaveCount 2
        ($result.Version | Sort-Object) | Should -Be @([version]'1.0.0', [version]'2.0.0')
    }

    It 'Should return the same name from different modules' {
        $result = Resolve-DscCompositeResource -ModulePath $script:fakeRoot -Name 'cTwo'

        ($result.ModuleName | Sort-Object) | Should -Be @('DscConfig.A', 'DscConfig.B')
    }

    It 'Should return only the requested names' {
        $result = Resolve-DscCompositeResource -ModulePath $script:fakeRoot -Name 'cThree', 'cTwo'

        ($result.Name | Sort-Object -Unique) | Should -Be @('cThree', 'cTwo')
    }

    It 'Should match names without regard to case' {
        $result = Resolve-DscCompositeResource -ModulePath $script:fakeRoot -Name 'CTHREE'

        $result | Should -HaveCount 1
        $result.Name | Should -Be 'cThree'
    }

    It 'Should return nothing for a name that no module provides' {
        Resolve-DscCompositeResource -ModulePath $script:fakeRoot -Name 'cMissing' | Should -BeNullOrEmpty
    }

    It 'Should ignore a composite folder without a schema file' {
        Resolve-DscCompositeResource -ModulePath $script:fakeRoot -Name 'cBroken' | Should -BeNullOrEmpty
    }

    It 'Should throw when the module path does not exist' {
        { Resolve-DscCompositeResource -ModulePath (Join-Path -Path $TestDrive -ChildPath 'DoesNotExist') -Name 'cOne' } | Should -Throw
    }
}

Describe 'Get-DscCompositeResourceDetail' -Tag Integration {
    BeforeAll {
        $script:generatedComposite = @'
configuration cAADRoleSetting {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADRoleSetting'

    $param = $PSBoundParameters
}
'@
        $script:versionedComposite = @'
configuration cX {
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC -ModuleVersion 2.26.1021.1
    Import-DscResource -ModuleName xPSDesiredStateConfiguration -Name xRegistry

    # $dscResourceName = 'NotThisOne'
    $dscResourceName = 'ExampleResource'
}
'@
        $script:handWrittenComposite = @'
configuration DscTagging {
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    xRegistry DscVersion { Key = 'HKLM:\SOFTWARE\X' }
}
'@
    }

    It 'Should find the inner resource of a generated composite' {
        $path = Join-Path -Path $TestDrive -ChildPath 'generated.schema.psm1'
        Set-Content -Path $path -Value $script:generatedComposite

        $result = Get-DscCompositeResourceDetail -Path $path

        $result.InnerResourceName | Should -Be 'AADRoleSetting'
    }

    It 'Should list the imported modules without PSDesiredStateConfiguration' {
        $path = Join-Path -Path $TestDrive -ChildPath 'generated2.schema.psm1'
        Set-Content -Path $path -Value $script:generatedComposite

        $result = Get-DscCompositeResourceDetail -Path $path

        $result.ImportedModule.Name | Should -Be 'Microsoft365DSC'
    }

    It 'Should keep a pinned module version of an import' {
        $path = Join-Path -Path $TestDrive -ChildPath 'versioned.schema.psm1'
        Set-Content -Path $path -Value $script:versionedComposite

        $result = Get-DscCompositeResourceDetail -Path $path

        $microsoft365Dsc = $result.ImportedModule | Where-Object -Property Name -EQ -Value 'Microsoft365DSC'
        $microsoft365Dsc.Version | Should -Be ([version]'2.26.1021.1')
        ($result.ImportedModule | Where-Object -Property Name -EQ -Value 'xPSDesiredStateConfiguration').Version | Should -BeNullOrEmpty
    }

    It 'Should ignore a commented out assignment' {
        $path = Join-Path -Path $TestDrive -ChildPath 'commented.schema.psm1'
        Set-Content -Path $path -Value $script:versionedComposite

        (Get-DscCompositeResourceDetail -Path $path).InnerResourceName | Should -Be 'ExampleResource'
    }

    It 'Should report no inner resource for a hand written composite' {
        $path = Join-Path -Path $TestDrive -ChildPath 'handwritten.schema.psm1'
        Set-Content -Path $path -Value $script:handWrittenComposite

        $result = Get-DscCompositeResourceDetail -Path $path

        $result.InnerResourceName | Should -BeNullOrEmpty
        $result.ImportedModule.Name | Should -Be 'xPSDesiredStateConfiguration'
    }
}

Describe 'Get-ModuleWithDscResource' -Tag Integration {
    BeforeAll {
        function Add-FakeModuleManifest
        {
            param (
                [string] $Root,
                [string] $Name,
                [string] $Manifest = '',
                [string[]] $DscResourceFolder = @()
            )

            $base = Join-Path -Path $Root -ChildPath "$Name\1.0.0"
            $null = New-Item -Path $base -ItemType Directory -Force
            Set-Content -Path (Join-Path -Path $base -ChildPath "$Name.psd1") -Value "@{ ModuleVersion = '1.0.0'; $Manifest }"

            foreach ($folder in $DscResourceFolder)
            {
                $null = New-Item -Path (Join-Path -Path $base -ChildPath "DscResources\$folder") -ItemType Directory -Force
            }
        }

        $root = Join-Path -Path $TestDrive -ChildPath 'ModulesWithDsc'
        Add-FakeModuleManifest -Root $root -Name 'MofBasedModule' -DscResourceFolder 'MSFT_Thing'
        Add-FakeModuleManifest -Root $root -Name 'CompositeModule' -DscResourceFolder 'cThing'
        Add-FakeModuleManifest -Root $root -Name 'ClassBasedModule' -Manifest "DscResourcesToExport = @('ThingA', 'ThingB')"
        Add-FakeModuleManifest -Root $root -Name 'EmptyExportModule' -Manifest 'DscResourcesToExport = @()'
        Add-FakeModuleManifest -Root $root -Name 'PlainModule'
        Add-FakeModuleManifest -Root $root -Name 'EmptyDscResourcesFolderModule'
        $null = New-Item -Path (Join-Path -Path $root -ChildPath 'EmptyDscResourcesFolderModule\1.0.0\DscResources') -ItemType Directory -Force

        $previousModulePath = $env:PSModulePath
        $env:PSModulePath = $root
        $script:fakeModules = Get-Module -ListAvailable -Refresh
        $env:PSModulePath = $previousModulePath
    }

    It 'Should find the fake modules' {
        $script:fakeModules.Name | Should -Contain 'PlainModule'
    }

    It 'Should select a module with a DscResources folder' {
        (Get-ModuleWithDscResource -Module $script:fakeModules).Name | Should -Contain 'MofBasedModule'
        (Get-ModuleWithDscResource -Module $script:fakeModules).Name | Should -Contain 'CompositeModule'
    }

    It 'Should select a module whose manifest exports DSC resources' {
        (Get-ModuleWithDscResource -Module $script:fakeModules).Name | Should -Contain 'ClassBasedModule'
    }

    It 'Should not select a module without DSC resources' {
        $selected = (Get-ModuleWithDscResource -Module $script:fakeModules).Name

        $selected | Should -Not -Contain 'PlainModule'
        $selected | Should -Not -Contain 'EmptyExportModule'
        $selected | Should -Not -Contain 'EmptyDscResourcesFolderModule'
    }

    It 'Should accept modules from the pipeline' {
        ($script:fakeModules | Get-ModuleWithDscResource).Name | Should -Contain 'ClassBasedModule'
    }
}

Describe 'Get-ModuleVersionDeviation' -Tag Integration {
    BeforeAll {
        $root = Join-Path -Path $TestDrive -ChildPath 'BaselineModules'

        foreach ($module in @('SameModule', '1.0.0'), @('NewerModule', '1.0.0'), @('NewerModule', '2.0.0'), @('OlderModule', '1.0.0'))
        {
            $name, $version = $module
            $base = Join-Path -Path $root -ChildPath "$name\$version"
            $null = New-Item -Path $base -ItemType Directory -Force
            Set-Content -Path (Join-Path -Path $base -ChildPath "$name.psd1") -Value "@{ ModuleVersion = '$version' }"
        }

        $script:previousModulePath = $env:PSModulePath
        $env:PSModulePath = $root
    }

    AfterAll {
        $env:PSModulePath = $script:previousModulePath
    }

    It 'Should return nothing when the newest version is the baseline' {
        Get-ModuleVersionDeviation -Baseline @{ SameModule = '1.0.0' } | Should -BeNullOrEmpty
    }

    It 'Should report a version that is newer than the baseline' {
        $result = Get-ModuleVersionDeviation -Baseline @{ NewerModule = '1.0.0' }

        $result.Name | Should -Be 'NewerModule'
        $result.Expected | Should -Be ([System.Version]'1.0.0')
        $result.Actual | Should -Be ([System.Version]'2.0.0')
    }

    It 'Should report a version that is older than the baseline' {
        $result = Get-ModuleVersionDeviation -Baseline @{ OlderModule = '2.0.0' }

        $result.Expected | Should -Be ([System.Version]'2.0.0')
        $result.Actual | Should -Be ([System.Version]'1.0.0')
    }

    It 'Should ignore a module that is not available' {
        Get-ModuleVersionDeviation -Baseline @{ MissingModule = '1.0.0' } | Should -BeNullOrEmpty
    }

    It 'Should return only the modules that deviate' {
        $result = Get-ModuleVersionDeviation -Baseline @{ SameModule = '1.0.0'; NewerModule = '1.0.0'; MissingModule = '1.0.0' }

        @($result).Count | Should -Be 1
        $result.Name | Should -Be 'NewerModule'
    }
}

Describe 'Composite resources of DscConfig.M365' -Tag Integration {
    It 'Should name exactly one inner resource in every composite so that the metadata can be limited to the used resources' -Skip:(-not $hasM365Composites) {
        $composites = Get-ChildItem -Path (Join-Path -Path $requiredModulesDirectory -ChildPath 'DscConfig.M365\*\DscResources\*\*.schema.psm1')
        $composites | Should -Not -BeNullOrEmpty

        $withoutInnerResource = foreach ($composite in $composites)
        {
            $detail = Get-DscCompositeResourceDetail -Path $composite.FullName
            if (@($detail.InnerResourceName).Count -ne 1)
            {
                $composite.BaseName
            }
        }

        $withoutInnerResource | Should -BeNullOrEmpty -Because 'Initialize-DscResourceMetaInfoForComposite reads the inner resource from $dscResourceName'
    }
}
