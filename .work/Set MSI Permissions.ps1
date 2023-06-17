$TenantID = 'b246c1af-87ab-41d8-9812-83cd5ff534cb'
$GraphAppId = '00000003-0000-0000-c000-000000000000'
$exchAppId = '00000002-0000-0ff1-ce00-000000000000'
$DisplayNameOfMSI = 'LCM'
$resourceGroupName = 'M365Demo50'
$PermissionNames = 'user.read.all', 'Group.ReadWrite.All', 'Group.Read.All', 'Directory.Read.All', 'GroupMember.Read.All', 'Directory.ReadWrite.All', 'RoleManagement.Read.Directory'
#Save-Module -Name AzureAD -Path .\output\RequiredModules\
#Save-Module -Name Microsoft.Graph.Applications -Path .\output\RequiredModules\
#Save-Module -Name Az.ManagedServiceIdentity -Path .\output\RequiredModules\
#Connect-AzureAD -TenantId $TenantID
#Connect-MgGraph -TenantId $TenantID
#Login-AzAccount -Tenant $TenantID

$PermissionNames = $PermissionNames.split(',')
$GraphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$GraphAppId'"
#$msi = Get-AzureADServicePrincipal -Filter "displayName eq '$DisplayNameOfMSI'"
$msi = Get-MgServicePrincipal -Filter "displayName eq '$DisplayNameOfMSI'"
#$MI_ID = (Get-AzUserAssignedIdentity -Name "<UserAssignedMI>" -ResourceGroupName "<MIResourceGroupName>").PrincipalId
$GraphServicePrincipalApproles = $GraphServicePrincipal.AppRoles
$appRoleValues = $GraphServicePrincipalApproles.Value

foreach ($PermissionName in $PermissionNames)
{
    if (-not $appRoleValues.Contains($PermissionName))
    {
        continue
    }
    $AppRole = $GraphServicePrincipal.AppRoles | Where-Object { $_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains 'Application' }
    New-AzureADServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId `
        -ResourceId $GraphServicePrincipal.ObjectId -Id $AppRole.Id
}

$exchangeServicePrincipal = Get-AzureADServicePrincipal -Filter "AppId eq '$exchAppId'"

#$Approles = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $MSI.ObjectId

$AppRoleID = 'dc50a0fb-09a3-484d-be87-e023b12c6440'
$exchangeServicePrincipal = Get-AzureADServicePrincipal -Filter "AppId eq '$exchAppId'"
#New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $Msi.ObjectId -PrincipalId $msi.ObjectId -AppRoleId $AppRoleID -ResourceId 4d86974a-be4d-43c4-88de-5f9a6d720011 #$ResourceID
New-AzureADServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId -ResourceId $exchangeServicePrincipal.ObjectId -Id $AppRoleID

Connect-MgGraph -ContextScope Process -ForceRefresh -TenantId b246c1af-87ab-41d8-9812-83cd5ff534cb -Scopes Group.ReadWrite.All, 'Application.ReadWrite.All', 'Directory.ReadWrite.All'
Get-AzureADServiceAppRoleAssignment -ObjectId $MSI.ObjectId
#Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId
$appRoles = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $msi.Id
foreach ($appRole in $appRoles) {
    New-MgServicePrincipalAppRoleAssignment
}
$AssignedRoles = $GraphServicePrincipal.AppRoles | Where-Object { $_.Id -in $Approles.AppRoleId } | Select-Object -ExpandProperty Value
