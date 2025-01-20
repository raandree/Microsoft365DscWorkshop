@{
    PSDependOptions                                        = @{
        AddToPath  = $true
        Target     = 'output\RequiredModules'
        Parameters = @{
            Repository      = 'PSGallery'
            AllowPreRelease = $true
        }
    }

    InvokeBuild                                            = 'latest'
    PSScriptAnalyzer                                       = 'latest'
    Pester                                                 = 'latest'
    Plaster                                                = 'latest'
    ModuleBuilder                                          = 'latest'
    ChangelogManagement                                    = 'latest'
    Sampler                                                = 'latest'
    'Sampler.GitHubTasks'                                  = 'latest'
    PowerShellForGitHub                                    = 'latest'
    'Sampler.DscPipeline'                                  = 'latest'
    MarkdownLinkCheck                                      = 'latest'
    'DscResource.AnalyzerRules'                            = 'latest'
    DscBuildHelpers                                        = @{
        Version    = 'latest'
        Parameters = @{
            AllowPrerelease = $true
        }
    }
    Datum                                                  = 'latest'
    ProtectedData                                          = 'latest'
    'Datum.ProtectedData'                                  = 'latest'
    'Datum.InvokeCommand'                                  = 'latest'
    Configuration                                          = 'latest'
    Metadata                                               = 'latest'
    xDscResourceDesigner                                   = 'latest'
    'DscResource.Test'                                     = 'latest'

    # Composites
    'DscConfig.M365'                                       = 'latest'
    'DscConfig.Demo'                                       = 'latest'

    #DSC Resources
    xPSDesiredStateConfiguration                           = '9.2.1'
    ComputerManagementDsc                                  = '9.2.0'
    NetworkingDsc                                          = '9.0.0'
    JeaDsc                                                 = '0.7.2'
    WebAdministrationDsc                                   = '4.2.1'
    FileSystemDsc                                          = '1.1.1'
    SecurityPolicyDsc                                      = '2.10.0.0'
    xDscDiagnostics                                        = '2.8.0'
    PSDesiredStateConfiguration                            = '2.0.7'

    # Azure
    'Az.KeyVault'                                          = '6.2.0'
    'Az.ManagedServiceIdentity'                            = '1.2.1'
    'Microsoft.Graph.Identity.Governance'                  = '2.25.0'
    'Microsoft.Graph.Identity.DirectoryManagement'         = '2.25.0'

    # Microsoft365DSC
    Microsoft365DSC                                        = '1.25.115.1'

    <#
        To update Microsoft365DSC and its dependencies, do the following steps:
        1. Update the Microsoft365DSC version in the RequiredModules.psd1 file.
        2. Restart the PowerShell session to close all possible open handles to the modules.
        3. Remove the output folder using the command 'del -Path .\output\ -Recurse -Force'.
        4. Discard all the delete changes reported by git for the output folder.
        5. Run the build script to download all the required modules: .\build.ps1 -UseModuleFast -ResolveDependency -Tasks noop
        6. Run 'Update-M365DSCDependencies -ValidateOnly' to get the differences between the old and new dependencies and update the RequiredModules.psd1 file accordingly.
        7. Commit the changes to the RequiredModules.psd1 file.
        8. Start the build script to build the module: .\build.ps1 -UseModuleFast -ResolveDependency

        Required for Microsoft365DSC. This section is generated by running the following command:
        Update-M365DSCDependencies -ValidateOnly | ForEach-Object { [pscustomobject]$_ }  | ForEach-Object { "'{0}' = '{1}'" -f $_.ModuleName, $_.RequiredVersion } | Set-Clipboard
        (Import-PowerShellDataFile -Path '.\output\RequiredModules\Microsoft365DSC\*\Dependencies\Manifest.psd1').Dependencies | ForEach-Object { "'{0}' = '{1}'" -f $_.ModuleName, $_.RequiredVersion } | Set-Clipboard
    #>

    'Az.Accounts'                                          = '3.0.2'
    'Az.ResourceGraph'                                     = '1.0.0'
    'Az.Resources'                                         = '7.2.0'
    'Az.SecurityInsights'                                  = '3.1.2'
    'DSCParser'                                            = '2.0.0.14'
    'ExchangeOnlineManagement'                             = '3.4.0'
    'Microsoft.Graph.Applications'                         = '2.25.0'
    'Microsoft.Graph.Beta.Applications'                    = '2.25.0'
    'Microsoft.Graph.Authentication'                       = '2.25.0'
    'Microsoft.Graph.Beta.DeviceManagement'                = '2.25.0'
    'Microsoft.Graph.Beta.Devices.CorporateManagement'     = '2.25.0'
    'Microsoft.Graph.Beta.DeviceManagement.Administration' = '2.25.0'
    'Microsoft.Graph.Beta.DeviceManagement.Enrollment'     = '2.25.0'
    'Microsoft.Graph.Beta.NetworkAccess'                   = '2.25.0'
    'Microsoft.Graph.Beta.Identity.DirectoryManagement'    = '2.25.0'
    'Microsoft.Graph.Beta.Identity.Governance'             = '2.25.0'
    'Microsoft.Graph.Beta.Identity.SignIns'                = '2.25.0'
    'Microsoft.Graph.Beta.Reports'                         = '2.25.0'
    'Microsoft.Graph.Beta.Search'                          = '2.25.0'
    'Microsoft.Graph.Beta.Teams'                           = '2.25.0'
    'Microsoft.Graph.DeviceManagement.Administration'      = '2.25.0'
    'Microsoft.Graph.Beta.DirectoryObjects'                = '2.25.0'
    'Microsoft.Graph.Groups'                               = '2.25.0'
    'Microsoft.Graph.Beta.Groups'                          = '2.25.0'
    'Microsoft.Graph.Planner'                              = '2.25.0'
    'Microsoft.Graph.Sites'                                = '2.25.0'
    'Microsoft.Graph.Users'                                = '2.25.0'
    'Microsoft.Graph.Users.Actions'                        = '2.25.0'
    'Microsoft.PowerApps.Administration.PowerShell'        = '2.0.203'
    'MicrosoftTeams'                                       = '6.7.0'
    'MSCloudLoginAssistant'                                = '1.1.34'
    'ReverseDSC'                                           = '2.0.0.22'
    'PnP.PowerShell'                                       = '1.12.0'

}
