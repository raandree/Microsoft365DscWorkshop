# Generated with Microsoft365DSC version 1.24.313.1
# For additional information on how to use Microsoft365DSC, please visit https://aka.ms/M365DSC
param (
)

Configuration M365TenantConfig
{
    param (
    )

    $OrganizationName = $ConfigurationData.NonNodeData.OrganizationName

    Import-DscResource -ModuleName 'Microsoft365DSC' -ModuleVersion '1.24.313.1'

    Node localhost
    {
        AADAdministrativeUnit "AADAdministrativeUnit-Test1"
        {
            Description          = "None";
            DisplayName          = "Test1";
            Ensure               = "Present";
            Id                   = "ce1dfd92-36c7-4592-8076-4277637fce34";
            Managedidentity      = $True;
            TenantId             = $OrganizationName;
        }
        AADConditionalAccessPolicy "AADConditionalAccessPolicy-SEC001-Block-Legacy-Authentication-All-App"
        {
            AuthenticationContexts               = @();
            BuiltInControls                      = @("mfa");
            ClientAppTypes                       = @("exchangeActiveSync","other");
            CloudAppSecurityType                 = "";
            CustomAuthenticationFactors          = @();
            DeviceFilterRule                     = "";
            DisplayName                          = "SEC001-Block-Legacy-Authentication-All-App";
            Ensure                               = "Present";
            ExcludeApplications                  = @();
            ExcludeExternalTenantsMembers        = @();
            ExcludeExternalTenantsMembershipKind = "";
            ExcludeGroups                        = @();
            ExcludeLocations                     = @();
            ExcludePlatforms                     = @();
            ExcludeRoles                         = @();
            ExcludeUsers                         = @();
            GrantControlOperator                 = "OR";
            Id                                   = "1d0a97d9-c60a-466b-961b-d3a1719cf7f3";
            IncludeApplications                  = @("All");
            IncludeExternalTenantsMembers        = @();
            IncludeExternalTenantsMembershipKind = "";
            IncludeGroups                        = @();
            IncludeLocations                     = @();
            IncludePlatforms                     = @();
            IncludeRoles                         = @();
            IncludeUserActions                   = @();
            IncludeUsers                         = @("All");
            Managedidentity                      = $True;
            PersistentBrowserMode                = "";
            SignInFrequencyType                  = "";
            SignInRiskLevels                     = @();
            State                                = "enabledForReportingButNotEnforced";
            TenantId                             = $OrganizationName;
            UserRiskLevels                       = @();
        }
        AADConditionalAccessPolicy "AADConditionalAccessPolicy-Multifactor authentication for Microsoft partners and vendors"
        {
            AuthenticationContexts               = @();
            BuiltInControls                      = @("mfa");
            ClientAppTypes                       = @("all");
            CloudAppSecurityType                 = "";
            CustomAuthenticationFactors          = @();
            DeviceFilterRule                     = "";
            DisplayName                          = "Multifactor authentication for Microsoft partners and vendors";
            Ensure                               = "Present";
            ExcludeApplications                  = @();
            ExcludeExternalTenantsMembers        = @();
            ExcludeExternalTenantsMembershipKind = "";
            ExcludeGroups                        = @();
            ExcludeLocations                     = @();
            ExcludePlatforms                     = @();
            ExcludeRoles                         = @("Directory Synchronization Accounts");
            ExcludeUsers                         = @();
            GrantControlOperator                 = "OR";
            Id                                   = "c202a2a6-1b3d-4af4-a527-dcbf4a4526c5";
            IncludeApplications                  = @("All");
            IncludeExternalTenantsMembers        = @();
            IncludeExternalTenantsMembershipKind = "";
            IncludeGroups                        = @();
            IncludeLocations                     = @();
            IncludePlatforms                     = @();
            IncludeRoles                         = @();
            IncludeUserActions                   = @();
            IncludeUsers                         = @("All");
            Managedidentity                      = $True;
            PersistentBrowserMode                = "";
            SignInFrequencyType                  = "";
            SignInRiskLevels                     = @();
            State                                = "enabled";
            TenantId                             = $OrganizationName;
            UserRiskLevels                       = @();
        }
        AADConditionalAccessPolicy "AADConditionalAccessPolicy-Secure password change on high user risk for Microsoft partners and vendors"
        {
            AuthenticationContexts               = @();
            BuiltInControls                      = @("mfa","passwordChange");
            ClientAppTypes                       = @("all");
            CloudAppSecurityType                 = "";
            CustomAuthenticationFactors          = @();
            DeviceFilterRule                     = "";
            DisplayName                          = "Secure password change on high user risk for Microsoft partners and vendors";
            Ensure                               = "Present";
            ExcludeApplications                  = @();
            ExcludeExternalTenantsMembers        = @();
            ExcludeExternalTenantsMembershipKind = "";
            ExcludeGroups                        = @();
            ExcludeLocations                     = @();
            ExcludePlatforms                     = @();
            ExcludeRoles                         = @();
            ExcludeUsers                         = @();
            GrantControlOperator                 = "AND";
            Id                                   = "71edcde9-7e3a-4231-97ce-2cd66e7ec0f3";
            IncludeApplications                  = @("All");
            IncludeExternalTenantsMembers        = @();
            IncludeExternalTenantsMembershipKind = "";
            IncludeGroups                        = @();
            IncludeLocations                     = @();
            IncludePlatforms                     = @();
            IncludeRoles                         = @();
            IncludeUserActions                   = @();
            IncludeUsers                         = @("All");
            Managedidentity                      = $True;
            PersistentBrowserMode                = "";
            SignInFrequencyType                  = "";
            SignInRiskLevels                     = @();
            State                                = "enabled";
            TenantId                             = $OrganizationName;
            UserRiskLevels                       = @("high");
        }
        AADConditionalAccessPolicy "AADConditionalAccessPolicy-Reauthentication on signin risk for Microsoft partners and vendors"
        {
            AuthenticationContexts               = @();
            BuiltInControls                      = @("mfa");
            ClientAppTypes                       = @("all");
            CloudAppSecurityType                 = "";
            CustomAuthenticationFactors          = @();
            DeviceFilterRule                     = "";
            DisplayName                          = "Reauthentication on signin risk for Microsoft partners and vendors";
            Ensure                               = "Present";
            ExcludeApplications                  = @();
            ExcludeExternalTenantsMembers        = @();
            ExcludeExternalTenantsMembershipKind = "";
            ExcludeGroups                        = @();
            ExcludeLocations                     = @();
            ExcludePlatforms                     = @();
            ExcludeRoles                         = @();
            ExcludeUsers                         = @();
            GrantControlOperator                 = "OR";
            Id                                   = "2aa130df-1cc0-4e55-bfb2-aa3ffe41db0c";
            IncludeApplications                  = @("All");
            IncludeExternalTenantsMembers        = @();
            IncludeExternalTenantsMembershipKind = "";
            IncludeGroups                        = @();
            IncludeLocations                     = @();
            IncludePlatforms                     = @();
            IncludeRoles                         = @();
            IncludeUserActions                   = @();
            IncludeUsers                         = @("All");
            Managedidentity                      = $True;
            PersistentBrowserMode                = "";
            SignInFrequencyInterval              = "everyTime";
            SignInFrequencyIsEnabled             = $True;
            SignInFrequencyType                  = "";
            SignInRiskLevels                     = @("high","medium","low");
            State                                = "enabled";
            TenantId                             = $OrganizationName;
            UserRiskLevels                       = @();
        }
        AADConditionalAccessPolicy "AADConditionalAccessPolicy-Security info registration for Microsoft partners and vendors"
        {
            AuthenticationContexts               = @();
            BuiltInControls                      = @("block");
            ClientAppTypes                       = @("all");
            CloudAppSecurityType                 = "";
            CustomAuthenticationFactors          = @();
            DeviceFilterRule                     = "";
            DisplayName                          = "Security info registration for Microsoft partners and vendors";
            Ensure                               = "Present";
            ExcludeApplications                  = @();
            ExcludeExternalTenantsMembers        = @();
            ExcludeExternalTenantsMembershipKind = "";
            ExcludeGroups                        = @();
            ExcludeLocations                     = @("0200930c-0da2-4aa4-ca01-2e651856c570");
            ExcludePlatforms                     = @();
            ExcludeRoles                         = @();
            ExcludeUsers                         = @();
            GrantControlOperator                 = "OR";
            Id                                   = "61932da7-aaea-428e-806d-ecb17980aa22";
            IncludeApplications                  = @();
            IncludeExternalTenantsMembers        = @();
            IncludeExternalTenantsMembershipKind = "";
            IncludeGroups                        = @();
            IncludeLocations                     = @("All");
            IncludePlatforms                     = @();
            IncludeRoles                         = @();
            IncludeUserActions                   = @("urn:user:registersecurityinfo");
            IncludeUsers                         = @("All");
            Managedidentity                      = $True;
            PersistentBrowserMode                = "";
            SignInFrequencyType                  = "";
            SignInRiskLevels                     = @();
            State                                = "enabled";
            TenantId                             = $OrganizationName;
            UserRiskLevels                       = @();
        }
    }
}

M365TenantConfig -ConfigurationData .\ConfigurationData.psd1
