$here = $PSScriptRoot
Import-Module -Name $here\AzHelpers.psm1 -Force
$labs = Get-Lab -List | Where-Object { $_ -Like 'M365DscWorkshopWorker*' }

foreach ($lab in $labs)
{
    $lab = Import-Lab -Name $lab -NoValidation -PassThru
    Set-AzContext -SubscriptionId $lab.AzureSettings.DefaultSubscription.SubscriptionId -Tenant $lab.AzureSettings.DefaultSubscription.TenantId
    
    if (-not ($id = Get-AzUserAssignedIdentity -Name "Lcm$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -ErrorAction SilentlyContinue))
    {
        $id = New-AzUserAssignedIdentity -Name "Lcm$($lab.Notes.Environment)" -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Location $lab.AzureSettings.DefaultLocation.Location
    }
    
    $vm = Get-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -Name "Lcm$($lab.Notes.Environment)"
    Update-AzVM -ResourceGroupName $lab.AzureSettings.DefaultResourceGroup.ResourceGroupName -VM $vm -IdentityType UserAssigned -IdentityId $id.Id

    Connect-MgGraph -ContextScope Process -ForceRefresh -TenantId (Get-AzContext).Tenant.Id -Scopes Group.ReadWrite.All, Application.ReadWrite.All, Directory.ReadWrite.All, AppRoleAssignment.ReadWrite.All

    $permissions = Get-M365DSCCompiledPermissionList2

    Add-ServicePrincipalAppPermissions -DisplayName "Lcm$($lab.Notes.Environment)" -Permissions $permissions
    
    Disconnect-MgGraph
}
