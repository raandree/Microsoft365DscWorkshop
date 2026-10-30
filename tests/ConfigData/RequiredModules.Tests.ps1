BeforeDiscovery {
    $requiredModules = Import-PowerShellDataFile -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..\RequiredModules.psd1')

    $getPinnedVersion = {
        param ($Pin)

        if ($Pin -is [hashtable])
        {
            $Pin.Version
        }
        else
        {
            $Pin
        }
    }

    $authenticationVersion = & $getPinnedVersion $requiredModules['Microsoft.Graph.Authentication']

    $graphModuleNames = $requiredModules.Keys |
        Where-Object -FilterScript { $_ -like 'Microsoft.Graph.*' -and $_ -ne 'Microsoft.Graph.Authentication' } |
            Sort-Object

    $graphModuleTestCases = @(
        foreach ($graphModuleName in $graphModuleNames)
        {
            @{
                ModuleName            = $graphModuleName
                ModuleVersion         = & $getPinnedVersion $requiredModules[$graphModuleName]
                AuthenticationVersion = $authenticationVersion
            }
        }
    )
}

Describe 'Microsoft Graph SDK pins in RequiredModules.psd1' -Tag Integration {
    # Every Microsoft Graph SDK module manifest requires one exact version of Microsoft.Graph.Authentication. A pin to
    # another version makes the restore save a second copy of Microsoft.Graph.Authentication, and importing the module
    # next to the pinned one fails with 'Assembly with same name is already loaded'.
    It "Should pin '<ModuleName>' to the version of 'Microsoft.Graph.Authentication'" -ForEach $graphModuleTestCases {
        $ModuleVersion | Should -Be $AuthenticationVersion -Because "the manifest of '$ModuleName' requires exactly that version of 'Microsoft.Graph.Authentication'"
    }
}
