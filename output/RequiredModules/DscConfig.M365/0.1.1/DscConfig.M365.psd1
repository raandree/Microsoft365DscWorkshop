@{
    RootModule        = 'DscConfig.M365.psm1'
    ModuleVersion     = '0.1.1'
    GUID              = '3ed9a67d-9e7e-4c59-86b3-4f4bfd929c31'
    Author            = 'DSC Community'
    CompanyName       = 'DSC Community'
    Copyright         = 'Copyright the DSC Community contributors. All rights reserved.'
    Description       = 'DSC composite resource for https://github.com/dsccommunity/DscWorkshop'
    PowerShellVersion = '5.1'
    FunctionsToExport = '*'
    CmdletsToExport   = '*'
    VariablesToExport = '*'
    AliasesToExport   = '*'

    PrivateData       = @{

        PSData = @{
            Prerelease   = 'preview0001'
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResource')
            LicenseUri   = 'https://github.com/dsccommunity/DscConfig.M365/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/dsccommunity/DscConfig.M365'
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'
            ReleaseNotes = ''
        }
    }
}
