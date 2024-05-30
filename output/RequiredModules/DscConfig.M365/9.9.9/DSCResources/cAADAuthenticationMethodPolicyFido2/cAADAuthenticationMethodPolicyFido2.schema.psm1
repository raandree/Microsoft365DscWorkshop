configuration cAADAuthenticationMethodPolicyFido2 {
    param (
        [Parameter()]
        [hashtable[]]
        $Items
)

<#
AADAuthenticationMethodPolicyFido2 [String] #ResourceName
{
    Id = [string]
    [AccessTokens = [string[]]]
    [ApplicationId = [string]]
    [ApplicationSecret = [PSCredential]]
    [CertificateThumbprint = [string]]
    [Credential = [PSCredential]]
    [DependsOn = [string[]]]
    [Ensure = [string]{ Absent | Present }]
    [ExcludeTargets = [MSFT_AADAuthenticationMethodPolicyFido2ExcludeTarget[]]]
    [IncludeTargets = [MSFT_AADAuthenticationMethodPolicyFido2IncludeTarget[]]]
    [IsAttestationEnforced = [bool]]
    [IsSelfServiceRegistrationAllowed = [bool]]
    [KeyRestrictions = [MSFT_MicrosoftGraphfido2KeyRestrictions]]
    [ManagedIdentity = [bool]]
    [PsDscRunAsCredential = [PSCredential]]
    [State = [string]{ disabled | enabled }]
    [TenantId = [string]]
}

#>


    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName Microsoft365DSC

    $dscResourceName = 'AADAuthenticationMethodPolicyFido2'

    $param = $PSBoundParameters
    $param.Remove("InstanceName")

    $dscParameterKeys = 'Id' -split ', '

        foreach ($item in $Items)
        {
            if (-not $item.ContainsKey('Ensure'))
            {
                $item.Ensure = 'Present'
            }
            $keyValues = foreach ($key in $dscParameterKeys)
        {
            $item.$key
        }
        $executionName = $keyValues -join '_'
        $executionName = $executionName -replace "[\s()\\:*-+/{}```"']", '_'
        (Get-DscSplattedResource -ResourceName $dscResourceName -ExecutionName $executionName -Properties $item -NoInvoke).Invoke($item)
    }
}

