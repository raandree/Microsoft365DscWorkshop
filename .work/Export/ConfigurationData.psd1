@{
    AllNodes = @(
        @{
            NodeName                    = "localhost"
            PSDscAllowPlainTextPassword = $true;
            PSDscAllowDomainUser        = $true;
            #region Parameters
            # Default Value Used to Ensure a Configuration Data File is Generated
            ServerNumber = "0"

        }
    )
    NonNodeData = @(
        @{
            # Tenant's default verified domain name
            OrganizationName = "b246c1af-87ab-41d8-9812-83cd5ff534c"

            # The Id or Name of the tenant to authenticate against
            TenantId = "b246c1af-87ab-41d8-9812-83cd5ff534c"

        }
    )
}
