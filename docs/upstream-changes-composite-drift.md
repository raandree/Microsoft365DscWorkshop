# Composite resource drift for Microsoft365DSC 2.x

This is the evidence for entry DC365-1 of
[upstream-changes.md](upstream-changes.md). DscConfig.M365 0.8.0-preview0001 was
generated for Microsoft365DSC 1.26.819.1. The tables compare its 179 composite
resources with the DSC resources of Microsoft365DSC 2.26.1021.1. It is a
snapshot of 2026-10-29. After the generator has run for 2.x, its own diff
replaces these tables.

## Method

- The properties of a 2.x resource are the `DscProperty` members of the class
  with the `DscResource` attribute in `Classes\*.psm1` of the module. Read-only
  members (`NotConfigurable`), `DependsOn` and `PsDscRunAsCredential` are left
  out.
- The properties of a shipped composite resource are the names in the syntax
  comment of its schema file, which the generator writes from
  `Get-DscResource -Syntax`. The wrapped resource is the `$dscResourceName` of
  the file.
- The method was checked against the generator of DscConfig.M365, run with the
  2.26.1021.1 pin. It had written 89 composite resources when the comparison
  ran. 88 of them exist in the shipped set, and for all 88 the removed and the
  added properties are identical. The other one, `cIntuneDeviceCleanupRule`,
  is new.
- Not covered: changes of the type of a property, of the key properties and of
  embedded types. The generator and its unit tests show them.

## Summary

| | Composite resources |
|---|---|
| Shipped in 0.8.0-preview0001 | 179 |
| Resource list of the generator for 2.26.1021.1 | 176 |
| Wrap a resource that 2.x does not have | 4 |
| New for 2.x | 1 |
| Unchanged | 111 |
| Changed | 64 |
| Changed and lose properties (breaking) | 22 (7 scalar, 15 array) |
| Changed and only gain properties | 42 |
| Lose `Ensure` | 4, all scalar |

A scalar composite resource declares one parameter per property, so a removed
property removes a parameter. An array composite resource takes `Items`, so a
removed property only fails when a node sets it. None of the array composite
resources lost `Ensure`, so the injection of `Ensure = 'Present'` into their
items stays valid.

## Composite resources without a resource in 2.x

- `cIntuneApplicationControlPolicyWindows10`
- `cIntuneDiskEncryptionMacOS`
- `cSCSupervisoryReviewPolicy`
- `cSCSupervisoryReviewRule`

## New composite resource for 2.x

- `cIntuneDeviceCleanupRule`

## Composite resources that this project's nodes use

| Composite | Change in 2.x | Effect on the configuration data |
|---|---|---|
| `cAADAuthorizationPolicy` | loses five properties, gains `DefaultUserRolePermissions` and `EnabledPreviewFeatures` | three keys were set and are commented out until the composite is regenerated |
| `cAADSecurityDefaults` | loses `Ensure` | none, the layer does not set it |
| `cAADGroup` | gains `Theme` and `WritebackConfiguration` | none |
| `cAADTenantDetails` | gains seven properties | none |
| `cAADRoleSetting`, `cAADNamedLocationPolicy`, `cAADGroupsSettings` | unchanged | none |
| `DscTagging` | hand-written in DscConfig.Demo | none |

The two SharePoint layers `cSPOTenantSettings` and `cSPOAccessControlSettings`
are not used by a node yet. Both set `Ensure`, which their resources lost, so
the key is commented out.

## Composite resources that lose properties

| Composite | Kind | Removed properties | Added (count) |
|---|---|---|---|
| `cAADApplication` | Array | `Permissions` | 8 |
| `cAADAuthorizationPolicy` | Scalar | `DefaultUserRoleAllowedToCreateApps`, `DefaultUserRoleAllowedToCreateSecurityGroups`, `DefaultUserRoleAllowedToCreateTenants`, `DefaultUserRoleAllowedToReadBitlockerKeysForOwnedDevice`, `DefaultUserRoleAllowedToReadOtherUsers` | 2 |
| `cAADSecurityDefaults` | Scalar | `Ensure` | 0 |
| `cAADTokenLifetimePolicy` | Array | `Description` | 0 |
| `cEXODistributionGroup` | Array | `Notes` | 0 |
| `cIntuneAppProtectionPolicyiOS` | Array | `DeployedAppCount`, `Identity` | 5 |
| `cIntuneDeviceAndAppManagementAssignmentFilter` | Array | `Identity` | 2 |
| `cIntuneDeviceCompliancePolicyAndroidWorkProfile` | Array | `RestrictedApps`, `SecurityBlockDeviceAdministratorManagedDevices` | 0 |
| `cIntuneDeviceConfigurationDeliveryOptimizationPolicyWindows10` | Array | `BackgroundDownloadFromHttpDelayInSeconds`, `BandwidthMode`, `CacheServerBackgroundDownloadFallbackToHttpDelayInSeconds`, `CacheServerForegroundDownloadFallbackToHttpDelayInSeconds`, `CacheServerHostNames`, `DeliveryOptimizationMode`, `ForegroundDownloadFromHttpDelayInSeconds`, `GroupIdSource`, `MaximumCacheAgeInDays`, `MaximumCacheSize`, `MinimumBatteryPercentageAllowedToUpload`, `MinimumDiskSizeAllowedToPeerInGigabytes`, `MinimumFileSizeToCacheInMegabytes`, `MinimumRamAllowedToPeerInGigabytes`, `ModifyCacheLocation`, `RestrictPeerSelectionBy`, `VpnPeerCaching` | 37 |
| `cIntuneDeviceEnrollmentPlatformRestriction` | Array | `Identity` | 1 |
| `cIntuneWindowsAutopilotDeploymentProfileAzureADJoined` | Array | `EnableWhiteGlove`, `ExtractHardwareHash`, `Language`, `OutOfBoxExperienceSettings` | 4 |
| `cSCRetentionCompliancePolicy` | Array | `DynamicScopeLocation` | 2 |
| `cSPOAccessControlSettings` | Scalar | `Ensure` | 1 |
| `cSPOSharingSettings` | Scalar | `Ensure` | 23 |
| `cSPOTenantSettings` | Scalar | `Ensure`, `OneDriveSharingCapability` | 64 |
| `cTeamsCallingPolicy` | Array | `SafeTransferEnabled` | 4 |
| `cTeamsChannelTab` | Array | `ContentUrl`, `EntityId`, `RemoveUrl`, `WebSiteUrl` | 1 |
| `cTeamsFederationConfiguration` | Scalar | `DomainBlockingForMDOAdminsInTeams` | 3 |
| `cTeamsGuestMessagingConfiguration` | Scalar | `UsersCanDeleteBotMessages` | 0 |
| `cTeamsMessagingPolicy` | Array | `AllowExtendedWorkInfoInSearch` | 0 |
| `cTeamsOnlineVoicemailUserSettings` | Array | `OofGreetingFollowCalendarEnabled` | 4 |
| `cTeamsTenantNetworkSite` | Array | `SiteAddress` | 0 |

## Composite resources that only gain properties

| Composite | Kind | Added (count) |
|---|---|---|
| `cAADAuthenticationMethodPolicyVoice` | Array | 1 |
| `cAADAuthenticationMethodPolicyX509` | Array | 2 |
| `cAADConditionalAccessPolicy` | Array | 1 |
| `cAADDeviceRegistrationPolicy` | Scalar | 1 |
| `cAADGroup` | Array | 2 |
| `cAADServicePrincipal` | Array | 6 |
| `cAADTenantDetails` | Scalar | 7 |
| `cIntuneAppConfigurationDevicePolicy` | Array | 1 |
| `cIntuneAppProtectionPolicyAndroid` | Array | 18 |
| `cIntuneDeviceCategory` | Array | 1 |
| `cIntuneDeviceCompliancePolicyMacOS` | Array | 1 |
| `cIntuneDeviceCompliancePolicyWindows10` | Array | 5 |
| `cIntuneDeviceConfigurationCustomPolicyWindows10` | Array | 3 |
| `cIntuneDeviceConfigurationDomainJoinPolicyWindows10` | Array | 3 |
| `cIntuneDeviceConfigurationIdentityProtectionPolicyWindows10` | Array | 3 |
| `cIntuneDeviceConfigurationImportedPfxCertificatePolicyWindows10` | Array | 3 |
| `cIntuneDeviceConfigurationPolicyAndroidDeviceOwner` | Array | 6 |
| `cIntuneDeviceConfigurationPolicyAndroidWorkProfile` | Array | 3 |
| `cIntuneDeviceConfigurationPolicyMacOS` | Array | 1 |
| `cIntuneDeviceConfigurationPolicyWindows10` | Array | 3 |
| `cIntuneDeviceConfigurationSecureAssessmentPolicyWindows10` | Array | 3 |
| `cIntuneDeviceConfigurationSharedMultiDevicePolicyWindows10` | Array | 3 |
| `cIntuneDeviceConfigurationWiredNetworkPolicyWindows10` | Array | 3 |
| `cIntuneRoleAssignment` | Array | 1 |
| `cIntuneWifiConfigurationPolicyAndroidEnterpriseDeviceOwner` | Array | 7 |
| `cIntuneWifiConfigurationPolicyAndroidEnterpriseWorkProfile` | Array | 4 |
| `cIntuneWifiConfigurationPolicyAndroidOpenSourceProject` | Array | 5 |
| `cIntuneWifiConfigurationPolicyMacOS` | Array | 1 |
| `cIntuneWifiConfigurationPolicyWindows10` | Array | 1 |
| `cIntuneWindowsUpdateForBusinessRingUpdateProfileWindows10` | Array | 5 |
| `cSCComplianceTag` | Array | 1 |
| `cSCDLPCompliancePolicy` | Array | 1 |
| `cSCDLPComplianceRule` | Array | 1 |
| `cSCRetentionComplianceRule` | Array | 1 |
| `cTeamsCallQueue` | Array | 1 |
| `cTeamsChannelsPolicy` | Array | 12 |
| `cTeamsEventsPolicy` | Array | 2 |
| `cTeamsMeetingConfiguration` | Scalar | 4 |
| `cTeamsMeetingPolicy` | Array | 15 |
| `cTeamsOnlineVoicemailPolicy` | Array | 1 |
| `cTeamsUserCallingSettings` | Array | 2 |
| `cTeamsUserPolicyAssignment` | Array | 1 |

## See also

- [Upstream changes](upstream-changes.md)
