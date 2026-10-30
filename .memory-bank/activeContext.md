---
status: current
last-verified: 2026-10-30
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Bumping `Microsoft365DSC` to `2.26.1021.1` and `DscConfig.M365` to
`0.8.0-preview0001` made `.\build.ps1` fail in `TestConfigData`: 26 of 166 tests
in `tests\ConfigData\AzHelpers.Tests.ps1` reported `This test should run but it
did not. Most likely a setup in some parent block failed.` The four hand-kept
Graph SDK pins (`Microsoft.Graph.Applications`,
`Microsoft.Graph.Identity.DirectoryManagement`,
`Microsoft.Graph.Identity.Governance`, `Microsoft.Graph.Users`) still said
`2.35.1` while the regenerated block moved `Microsoft.Graph.Authentication` to
`2.41.1`. Every sub-module manifest requires exactly its own version of
`Microsoft.Graph.Authentication`, so the restore saved a second copy, and the
`BeforeAll` died on `Import-Module Microsoft.Graph.Applications -RequiredVersion
2.35.1` with `FileLoadException: Could not load file or assembly
'Microsoft.Graph.Authentication, Version=2.35.1.0 ... Assembly with same name is
already loaded`. The four pins are now `2.41.1`, the new
`tests/ConfigData/RequiredModules.Tests.ps1` fails by pin name when they drift,
and the upgrade steps inside `RequiredModules.psd1` name the step. All edits are
uncommitted on `update/2610`, together with the user's own bump.

The build still failed after that fix, in `CompileRootConfiguration` after 1 h
10 min, with `The term 'PSDesiredStateConfiguration PSDesiredStateConfiguration'
is not recognized`. The pins do not cause it: Microsoft365DSC 2.x brings its
own DSC engine, `M365DSC.PSDesiredStateConfiguration` 3.1.10, and once it is
loaded next to `PSDesiredStateConfiguration` 2.0.8,
`Get-Module -Name PSDesiredStateConfiguration` returns two modules, which breaks
`RootConfiguration.ps1` of Sampler.DscPipeline `0.3.0`. No pipeline or composite
release supports 2.x yet.

The user then reported that the build "hangs for an hour" at `Reading DSC
Resource metadata...`, stopped it, and asked for an investigation. It is not a
hang but the same cost the clean run measured: with 2.x the pipeline imports
all 205 composites twice, and each of the 179 that import Microsoft365DSC
re-parses the 10 MB of Microsoft365DSC
classes (`debugging-insights.md`). Offered the choice between returning to
Microsoft365DSC `1.26.909.1` (verified green) and changing the pipeline, the
user chose to keep `2.26.1021.1` and to implement the pipeline changes in this
repository and branch. They are in the working tree as project-level overrides
(Decision 28 in `systemPatterns.md`): the `PrepareDscCompile` task, an override
of `CompressModulesWithChecksum`, `source/CompileRootConfiguration.ps1` and
`source/RootConfiguration.ps1`, plus `source/` changes for the 5 keys that 2.x
dropped. The default workflow is green in a clean clone. Nothing is committed or
pushed, at the user's request.

## Upstream register, 2026-10-29

The user then asked to work until the build is green and to track every change
that the dependencies need, so that the upstream changes can be made later in
the owning repositories.

- The default workflow is green in the working tree itself, not only in a
  clone: `Build succeeded. 22 tasks, 0 errors, 0 warnings 00:06:27` on the
  final run (`PrepareDscCompile` 37.6 s, `CompileRootConfiguration` 4 min 35 s),
  `TestConfigData` 199 tests (194 plus the 5 of the register guard), acceptance
  12, 3 MOF files, 13 archives.
- `docs/upstream-changes.md` is the register: 13 entries with IDs `SDP-1` to
  `SDP-4` (Sampler.DscPipeline), `DBH-1` to `DBH-4` (DscBuildHelpers),
  `DC365-1` to `DC365-3` (raandree/DscConfig.M365) and `M365PSDSC-1` to
  `M365PSDSC-3` (the Microsoft365DSC engine). Each entry has the problem, the
  evidence, the proposed change, the reference implementation, the local
  workaround and when to remove it. The three small changes (SDP-4, DBH-3,
  DBH-4) are exact diffs against upstream `main`.
  `docs/upstream-changes-composite-drift.md` holds the composite resource drift.
- Every workaround carries a comment `UPSTREAM: <ID>`, and
  `tests/ConfigData/UpstreamChanges.Tests.ps1` (5 tests) fails when a marker
  names an ID the register does not define, when an entry names a workaround
  that no marker carries, and when a named file does not exist. A mutation run
  on a scratch copy proved that each of the four defects fails exactly its
  test. The test builds the marker from two parts so that it does not match
  itself, and it asserts on offender lists, because Pester 6 treats an empty
  `-ForEach` as an error.
- Upstream state checked through GitHub and shallow clones: the four
  Sampler.DscPipeline files and the three DscBuildHelpers files that the
  workarounds shadow are identical to `main` (2ded4e7 and 84eb1b6). The real
  source of DscConfig.M365 is `raandree/DscConfig.M365`; the manifest names
  `dsccommunity/DscConfig.M365`, which returns 404. Its `main` still generates
  for Microsoft365DSC 1.26.819.1. No existing issue covers these problems.
- Corrections of earlier claims: module auto-loading takes the first module on
  the module path that exports the command, so the fork wins in
  `output\RequiredModules` because its name sorts first, not because its
  manifest lists the command (2.0.8 lists its four commands too). Only the 179
  DscConfig.M365 composites import Microsoft365DSC; the 26 DscConfig.Demo
  composites import MOF-based modules. The M365DSC engine claims the module name
  `PSDesiredStateConfiguration` on purpose, with a compatibility module.
- DscConfig.M365 drift against 2.26.1021.1, computed from the class definitions
  and checked against the generator on 88 composites without a disagreement: of
  179 shipped composites 111 are unchanged, 64 changed (22 lose properties, 42
  only gain), 4 wrap a resource that no longer exists, 1 is new. Four scalar
  composites lose `Ensure`. No array composite lost it, so the `Ensure`
  injection risk noted earlier does not exist. Of the 7 used composites 4
  changed. Exactly five keys of this project's data named removed properties,
  all five handled.
- Proof in a scratch clone, in two steps. First, with 88 regenerated composites
  swapped into DscConfig.M365 and the three settings written as
  `DefaultUserRolePermissions` (`AllowedToCreateApps`,
  `AllowedToCreateSecurityGroups`, `AllowedToReadOtherUsers`), `TestConfigData`
  passed 199 tests, but `CompileRootConfiguration` FAILED. That is DBH-4:
  `Write-CimPropertyValue` of DscBuildHelpers does not unwrap
  `System.Nullable[System.Boolean]`, which the 2.x embedded classes (for
  example `MSFT_DefaultUserRolePermissions`) use for their properties, so it
  writes ``AllowedToCreateApps = Nullable`1 { }`` and the generated block
  does not parse. Second, with the one-line fix
  (`[System.Nullable]::GetUnderlyingType`) in a patched copy of the installed
  module, the `build` workflow of the same scratch clone succeeded
  (`Build succeeded. 16 tasks, 0 errors, 0 warnings 00:06:47`;
  `CompileRootConfiguration` took 4 min 52 s) and each of the 3 MOF files
  contains `instance of MSFT_DefaultUserRolePermissions` with the three values,
  referenced by `AADAuthorizationPolicy`. The real tree keeps the three keys
  commented out, because it still has the 1.x composite resources.
- Measured on the way: with the M365DSC engine as the only engine
  `Import-DscResource -ModuleName Microsoft365DSC` costs the same as with
  2.0.8 (8.1/5.7/5.2 s against 9.2/7.0/4.7 s for three invocations, with
  another job on the CPU), so using the fork as the one engine is no way out.
  The DscConfig.M365 generator against 2.x needed more than 31 minutes for 89
  of 176 composites and grew to 11.9 GB; I stopped it. Running its two tasks
  alone wrote `DSCResources.yml` and a `DSCResources` folder to `C:\`, which I
  removed.

## Implementation evidence, 2026-10-29

- Test first: `tests/ConfigData/DscCompile.Tests.ps1` was red for each helper
  before it existed and has 24 tests, all passing. They cover
  `Resolve-DscCompositeResource` and `Get-DscCompositeResourceDetail` on fake
  module trees, `Get-ModuleWithDscResource` on fake manifests,
  `Get-ModuleVersionDeviation`, and one guard on the real data: all 179
  composites of DscConfig.M365 name exactly one `$dscResourceName`. A test that a
  wildcard `DscResourcesToExport` selects a module was dropped again: the engine
  imports class-based resources only when `ExportedDscResources.Count` is above
  0, so the original selection ignores such a module too.
- Final proof in a clean clone (a clone of `HEAD` with the working-tree files
  laid over it and a copy of `output\RequiredModules`), default workflow, no other
  job running: `Build succeeded. 22 tasks, 0 errors, 0 warnings 00:06:32`.
  `TestConfigData` 194 tests passed (47.9 s), `PrepareDscCompile` 34.5 s,
  `CompileRootConfiguration` 4 min 39 s, `CompressModulesWithChecksum` 2.5 s,
  `TestBuildAcceptance` 12 passed, 3 MOF and 3 meta MOF files. An earlier run of
  the same workflow, with a 24-minute reference job competing for the CPU, took 7
  min 54 s.
- Polluted session, which is what the user's console looks like after the
  stopped builds: a fresh process first imported
  `M365DSC.PSDesiredStateConfiguration` and `Microsoft365DSC` (so
  `PSDesiredStateConfiguration` 3.1.10, the engine's compatibility module, was
  loaded), then ran `.\build.ps1` and, in the same session,
  `.\build.ps1 -Tasks build`. Both succeeded (`22 tasks, 0 errors, 0 warnings
  00:06:21` and `16 tasks, 0 errors, 0 warnings 00:03:33`).
  `Initialize-StandardDscEngine` removed the M365DSC modules and imported 2.0.8
  each time, and the seeding resets the private table, so a second run does not
  collide. Loaded .NET assemblies stay for the life of a process, so a console
  that loaded older module versions can still fail with `Assembly with same name
  is already loaded` (see the `AzHelpers.Tests.ps1` entry of
  `debugging-insights.md`): restart the PowerShell session or use a new `pwsh`.
- `PrepareDscCompile` logs `PSDesiredStateConfiguration 2.0.8 is the only module
  of that name`, `The nodes use 8 configurations, 8 of them are composite
  resources` and `Resource metadata: 4 entries from 11 resources and types`. The
  4 entries are `AADAuthorizationPolicy-DefaultUserRolePermissions`,
  `AADGroup-AssignedLicenses`, `AADGroup-WritebackConfiguration` and
  `AADTenantDetails-PrivacyProfile`.
- The MOFs are class-based: `instance of AADAuthorizationPolicy` and the other
  resources, with `ModuleName = "Microsoft365DSC"` and `ModuleVersion =
  "2.26.1021.1"`, and without the `MSFT_` prefix of 1.x.
- Pack equivalence: the original selection, run separately with
  `Get-ModuleFromFolder` and `Get-DscResourceFromModuleInFolder`, took 24.3 min
  and selected 9 modules. The override selects the same 9 in 2.5 s, and the
  archives match in name and version (`debugging-insights.md`).
- Static checks: AST parse and an ASCII check of all new files report no
  problems. `Invoke-ScriptAnalyzer` reports nothing for the new `.build` and
  `source` scripts, and only the known `PSUseDeclaredVarsMoreThanAssignments`
  Pester scope false positives for the two new test files.
- Not verified: how the LCM or an agent applies the class-based MOFs, whether
  every 2.x resource accepts the `Ensure` that the Items-style composites inject
  (the compile accepts it), and any effect on a live tenant. The user's own
  `output\` was only read, never changed.

## Investigation evidence, 2026-10-29

- The user's build ran in the PowerShell Editor Services console at 100% of one
  core (CPU +7.8 s per 8 s, 2.4 GB working set) about 6 minutes after it had
  started, so it was computing, not stuck.
- Per-step costs, measured in isolated sessions with the build's `PSModulePath`:
  parse of all class files 10 s; `Get-DscResource -Module Microsoft365DSC` 25 s
  (fork) and 30 s (2.0.8), 1,066 resources; importing one composite 3.8 to 7.1 s;
  `Import-DscResource -ModuleName Microsoft365DSC` 3.4 to 7.9 s, unchanged by
  `-Name` and by repetition.
- The RSOP of the three nodes lists 8 distinct configurations (`DscTagging`,
  `cAADTenantDetails`, `cAADRoleSetting`, `cAADNamedLocationPolicy`, `cAADGroup`,
  `cAADAuthorizationPolicy`, `cAADGroupsSettings`, `cAADSecurityDefaults`), 6 to
  8 per node, out of 179 + 26 composites that the pipeline enumerates.
- `Get-Command Get-DscResource` resolves to `M365DSC.PSDesiredStateConfiguration`
  in a session that has not imported 2.0.8, and that auto-load is what creates
  the second `PSDesiredStateConfiguration` module. A scratch folder reproduces
  the failure and the fix in seconds (`debugging-insights.md`).
- `FastHost.ps1` of the engine rejects modules that contain composite resources,
  so Microsoft's fast compile path does not apply to this project.
- Microsoft365DSC `1.26.909.1` in a clean clone with a fresh restore: `Build
  succeeded. 21 tasks, 0 errors, 0 warnings 00:06:04`, 170 configuration-data
  and 12 acceptance tests passing, 3 MOF and 3 meta MOF files;
  `CompileRootConfiguration` took 4 min 18 s. Only `DSCParser`, `MSCloudLoginAssistant`
  and `ReverseDSC` change against the `1.26.729.2` block, and the Graph pins stay
  `2.35.1`.
- The working tree was not changed by the investigation. The scratch junction
  folder, the 1.x clone and all temp logs were removed, and the junction targets
  were verified intact.

## Evidence

- Red then green: the new test reports 4 failures (`Expected: '2.41.1' But was:
  '2.35.1'`) before the pin change and 4 passes after it.
- The failed run left `output\testResults\IntegrationTestResults.xml` with
  `total="166" failures="26"`, and its `output\RequiredModules` held
  `Microsoft.Graph.Authentication` `2.35.1` and `2.41.1` side by side.
- Clean-room proof in `%TEMP%\cr`, a `git clone` of `HEAD` plus the changed
  files: `-ResolveDependency -Tasks noop` took 110 s and restored a single Graph
  version, `2.41.1`, for all five modules. All 33 non-`latest` pins exist on
  disk, and the 16 entries of Microsoft365DSC's `Dependencies\Manifest.psd1`
  match the generated block. `.\build.ps1` there passes `TestConfigData` with
  `Tests Passed: 170, Failed: 0` (166 existing plus 4 new). The same build in the
  working tree also reports 170 passed, 0 failed.
- Microsoft365DSC 2.x is class-based: no `DSCResources\MSFT_*` folders and no
  per-resource `schema.mof`, but 541 exported resources in
  `Classes\Part00..15.psm1` (about 10 MB of PowerShell classes) plus
  `SchemaDefinition.json` and `DscSchemaCache.json`. `CompileRootConfiguration`
  calls `Initialize-DscResourceMetaInfo` (DscBuildHelpers `0.4.0`), which clears
  the DSC class cache and re-imports keywords once per resource.
- Measured cost of that design in a clean clone: `Get-DscResourceProperty` takes
  a flat 1.4 to 2.2 s per resource and `Initialize-DscResourceMetaInfo` about 48
  minutes in total; the next step, "Preloading available resources", is a second
  plain `Get-DscResource` and took 21 minutes. The build therefore failed after
  `01:10:18`, against 5 min 31 s for the whole green build with `1.26.729.2`.
- Second failure, reproduced in 10 s without the build: importing
  `M365DSC.PSDesiredStateConfiguration` next to `PSDesiredStateConfiguration`
  `2.0.8` registers three modules, the fork and an inner module that is also
  named `PSDesiredStateConfiguration` (`3.1.10`). `Get-Module -Name
  PSDesiredStateConfiguration` then returns two objects,
  `Import-DscResource -ModuleName PSDesiredStateConfiguration` reports `Multiple
  versions of the module ... were found`, and `RootConfiguration.ps1` runs
  `& $module { ... }` on that array, which PowerShell reads as the command name
  `PSDesiredStateConfiguration PSDesiredStateConfiguration`. With `2.0.8` alone a
  Microsoft365DSC `2.26.1021.1` resource compiles to a MOF in about 11 s.
- Static pre-check of `source/` against the 2.x schema, using DscBuildHelpers'
  `Get-DscResourceProperty` on the 19 resources the project uses: 5 keys no
  longer exist, namely `DefaultUserRoleAllowedToCreateApps`,
  `DefaultUserRoleAllowedToCreateSecurityGroups` and
  `DefaultUserRoleAllowedToReadOtherUsers` on `AADAuthorizationPolicy` (now one
  embedded `DefaultUserRolePermissions`) and `Ensure` on `SPOAccessControlSettings`
  and `SPOTenantSettings`. No enumeration or type mismatches. `DscConfig.M365`
  `0.8.0-preview0001`, published 2026-08-30 and the newest, was generated for
  Microsoft365DSC `1.26.819.1` and still declares the old parameters.
- Gallery on 2026-10-29: Microsoft365DSC `2.26.1028.1` is the newest and
  `1.26.909.1` the last 1.x; Sampler.DscPipeline `0.3.0` and DscBuildHelpers
  `0.4.0-preview0001` date from February and March.
- `Microsoft.Graph.Authentication` `2.41.1` ships `Microsoft.Identity.Client`
  `4.90.0.0` (`2.35.1` shipped `4.78.0.0`); `Az.Accounts` `5.3.2` still ships
  `4.65.0.0`.
- Environment trap: the VS Code PowerShell console (PowerShell Editor Services)
  that ran the failed build keeps `Az.Accounts`, `Az.Resources`,
  `Microsoft.Graph.Authentication`, `Pester`, `ProtectedData`,
  `Microsoft.PowerShell.PSResourceGet` and `powershell-yaml` loaded from
  `output\RequiredModules`. `Resolve-Dependency.ps1` re-extracts PSResourceGet
  unless the restoring session has already imported it, so an in-place restore
  died with `Access to the path '...NuGet.Versioning.dll' is denied`. Restart the
  PowerShell session before deleting `output\` or restoring in place.
- A `Remove-Item -Recurse` on that locked `output\` aborted after removing 308
  files: `output\Module`, four unused `Az.Accounts` versions and 10 files of the
  pinned `Az.Accounts 5.3.2`. `5.3.2` was repaired from the Gallery package (74
  of 74 files byte-identical), the stale `2.35.1` Graph folders were removed, and
  the four `2.41.1` Graph folders were copied in from the clean room.
- Static checks: AST parse of the changed `.ps1`, `.psm1` and `.psd1` files
  reports 0 errors; `Invoke-ScriptAnalyzer` reports only the known
  `PSUseDeclaredVarsMoreThanAssignments` on a Pester discovery variable in the
  new test, and the 82 findings of `lab/AzHelpers.psm1` are unchanged.

## Earlier focus

`.\build.ps1` failed in `TestConfigData` with `[-] tests\ConfigData\AzHelpers.Tests.ps1
failed with: InvalidOperationException: A 'break' or 'continue' statement with a
label that does not match any enclosing loop escaped from your code`. That
message is a Pester 6.1.0 misdiagnosis. The real error is a
`System.IO.FileLoadException: Assembly with same name is already loaded` raised by
the `Import-Module -Force` calls in the file's top-level `BeforeAll`, because
`.build/ConfigDataPreparation.ps1` has already loaded `Az.Accounts` and
`Az.Resources` into the build session. The `BeforeAll` now imports a module only
when the session holds none of that name, and reads the version to pin from
`RequiredModules.psd1` so the pins cannot drift from the manifest. The edit is
uncommitted at the user's request.

## Evidence

- Red proof: `.\build.ps1 -Tasks rsop` before the fix is `Build FAILED. 6 tasks,
  1 errors` with `Tests Passed: 140, Failed: 26` and `Container failed: 1 -
  tests\ConfigData\AzHelpers.Tests.ps1`.
- The real error was recovered by temporarily wrapping the `BeforeAll` in a
  `try/catch` that logged to `$env:TEMP`: `Import-Module -Name Az.Accounts
  -RequiredVersion 5.3.2` throws `Could not load file or assembly
  'Microsoft.Azure.PowerShell.AssemblyLoading, Version=5.3.2.0' ... Assembly with
  same name is already loaded`. The same log dumped `Get-Module` at that point:
  the session already held `Az.Accounts 5.5.2` and `Az.Resources 9.0.1`, loaded by
  `Import-Module -Name Az.Resources -ErrorAction SilentlyContinue` in
  `.build/ConfigDataPreparation.ps1:6`, which carries no version pin.
- `output/RequiredModules/Az.Accounts` holds both `5.3.2` (the
  `RequiredModules.psd1` pin) and a stale `5.5.2`, so the unpinned import picks
  the higher one. Reported to the user, not changed.
- Pester 6.1.0 masks the cause by design defect: `Invoke-ScriptBlock` wraps user
  code in `try { do { ... } while ($false); $flowControlEscaped = $false } finally
  { if ($flowControlEscaped) { throw (New-EscapedFlowControlErrorRecord) } }`
  (`Pester.psm1:2211-2232`). Any terminating error skips the assignment, so the
  `finally` throws the flow-control record over the original exception. A
  four-line probe with a `BeforeAll { throw 'the real error' }` reports `BLOCK
  ERROR: the real error` under Pester 5.7.1 and the bogus break/continue message
  under 6.1.0.
- A clean-session probe shows `Import-Module Az.Accounts -RequiredVersion 5.3.2
  -Force` succeeds when nothing else is loaded and throws
  `FileLoadException: Microsoft.Azure.PowerShell.Authentication.Abstractions ...
  already loaded` once `Az.KeyVault` has pulled `Az.Accounts` in first, so the
  trigger is the sibling module, not the version pin alone.
- Green proof: `.\build.ps1 -Tasks rsop` is `Build succeeded. 7 tasks, 0 errors, 0
  warnings` with `Tests Passed: 166, Failed: 0` and no failed container. The
  standalone `Invoke-Pester -Path .\tests\ConfigData\AzHelpers.Tests.ps1` run is
  `Passed: 26 Failed: 0 FailedContainers: 0` and leaves `Az.Accounts 5.3.2`,
  `Az.Resources 9.0.1`, `ExchangeOnlineManagement 3.9.2` and the
  `Microsoft.Graph.* 2.35.1` set loaded, so the clean-session path still applies
  the manifest pins.
- The pins are resolved with `Import-PowerShellDataFile` against
  `RequiredModules.psd1`, the same way `tests/ConfigData/CompositeResources.Tests.ps1`
  reads it. A probe over that manifest maps the six modules to their current
  pins and degrades to an unpinned import for the `latest` string form
  (`Pester`), the hashtable form (`DscBuildHelpers`) and an absent entry.
- AST parse of the changed file reports 0 errors; `Invoke-ScriptAnalyzer` reports
  only the pre-existing `PSUseDeclaredVarsMoreThanAssignments` on the
  `connectingLabScripts` discovery variable.

## Earlier focus

The `push` pipeline failed in `Deploy DSC Configuration` with `PowerShell DSC
resource MSFT_SPOAccessControlSettings failed to execute Test-TargetResource
functionality with error message: The current connection holds no SharePoint
context`. The Dev tenant has no SharePoint Online at all, so the workload cannot
be configured. `HasSharePointOnline` is now the per-environment counterpart of
`HasExchangeOnline`: `source/Datum.yml` swaps both SharePoint layers for the new
empty `source/1-AllTenantsConfig/SharePointDisabled` layer, the export task skips
the `SPO*` components, and a configuration data test guards the mechanism. The
edits are uncommitted on `main` at the user's request, together with the pipeline
fixes of the previous turns.

## Evidence

- `Resolve-DnsName MngEnvMCAP167509.sharepoint.com` and
  `MngEnvMCAP167509-admin.sharepoint.com` both return `DNS name does not exist`,
  while `microsoft.sharepoint.com` resolves. The Entra tenant itself is healthy:
  `login.microsoftonline.com/MngEnvMCAP167509.onmicrosoft.com/v2.0/.well-known/openid-configuration`
  returns issuer `.../a1627b4f-281e-4f8b-bf13-bddc0eb6857e/v2.0`, the
  `AzTenantId` of `source/Global/Azure.yml`. So the tenant exists and SharePoint
  Online is simply not provisioned in it.
- The failure chain is mechanical: `Connect-MSCloudLoginPnP` derives the URLs
  from the tenant name (`TenantId.Replace('.onmicrosoft.', '-admin.sharepoint.')`),
  `Connect-PnPOnline` leaves `PnPConnection.Current.Context` null for a host that
  does not exist, and PnP's `NoDefaultSharePointConnection` resource string is
  verbatim the reported message. `Get-PnPTenant -ErrorAction Stop` in
  `MSFT_SPOAccessControlSettings\Get-TargetResource` then logs and rethrows.
- The two SharePoint composites were the only resources still authenticating
  with `M365DscLcmApplication` plus `CertificateThumbprint`; the other 20
  instances use `ManagedIdentity: true` and pass, which is why only SharePoint
  failed. Purview is already commented out in its `Configurations.yml`.
- Red proof: with `HasSharePointOnline: false` but no Datum gate,
  `.\build.ps1 -Tasks rsop` fails the new case with `Expected $null or empty,
  but got @('cSPOAccessControlSettings', 'cSPOTenantSettings')`.
- Green proof: `.\build.ps1 -Tasks rsop` is `7 tasks, 0 errors, 0 warnings` with
  158 passed and 4 skipped, and the full `.\build.ps1` is `21 tasks, 0 errors, 0
  warnings`. The Dev RSOP composes `DscTagging, cAADGroup,
  cAADNamedLocationPolicy, cAADAuthorizationPolicy, cAADGroupsSettings,
  cAADSecurityDefaults`, Prod is unchanged and keeps both `cSPO*` entries, and
  `output/MOF/Dev/LcmM3653Dev.mof` holds zero `MSFT_SPO*` and `MSFT_EXO*`
  instances.
- `Invoke-ScriptAnalyzer` on both changed `.ps1` files reports only the
  pre-existing `PSAvoidUsingWriteHost`, `PSAvoidUsingCmdletAliases` and
  `PSUseDeclaredVarsMoreThanAssignments` findings; AST parse 0 errors.

## Earlier focus

The `push` pipeline failed in `Build DSC Artifacts` with `##[error]Detected
characters in arguments that may not be executed correctly by the shell`. The
organization or project has `Enable shell tasks arguments validation` enabled,
and `pipelines/buildTemplate.yml` passed the environment filter as a script
block through the `arguments` input of `PowerShell@2`. Both that step and the
disabled `Pack DSC Artifacts` step now call `./build.ps1` from an inline
`script`. The edits are uncommitted on `main` at the user's request, together
with the export pipeline fix of the previous turn.

## Evidence

- The validation is the documented `aka.ms/ado/75787` setting. It inspects the
  `arguments` input of `PowerShell`, `BatchScript`, `Bash`, `Ssh`,
  `AzureFileCopy` and `WindowsMachineFileCopy`, and cannot be worked around
  inside the same input: the suggested backtick escaping would reach
  `build.ps1` and bind `-Filter` to a literal string instead of a script block.
- `build.ps1` declares `[ScriptBlock] $Filter = {}` at position 1, so the
  inline form is the only equivalent that keeps the type.
- The neighbouring steps were unaffected because their arguments hold no shell
  metacharacter; `-ResolveDependency -Tasks InitializeModuleFolder
  #-UseModuleFast` passed. `arguments:.*[{}$]` now matches nothing under
  `pipelines/`.
- Verified: `buildTemplate.yml` parses as YAML, both inline invocations parse
  with 0 errors, and re-binding the unchanged argument text against a probe
  function returns `filterType=ScriptBlock filter='$_.Environment -eq
  $env:BuildEnvironment'` for `build` and `pack`.

## Earlier focus

The export pipeline stage failed in `Publish Exported Data` with
`##[error]Path does not exist: C:\Agent1\_work\1\s\output\Export`. The
artifact task was only the messenger: `source/Global/Azure.yml` still carried
the sample identity `<Name of your Application of Managed Identity>` with
`IsExportApplication: true`, so `.build/Export/ExportTenantData.ps1` matched two
export applications and stopped before creating the export folder, and
`continueOnError: true` downgraded that to a warning. The placeholder was
removed, the task now ignores `<...>` placeholders and counts matches instead of
testing for `$null`, and the export step no longer runs with `continueOnError`.
The edits are uncommitted on `main` at the user's request.

## Evidence

- Red proof against the committed configuration: the original selection
  expression returns `Dev: matches=2 -> M365DscExportApplication | <Name of your
  Application of Managed Identity>`, which is exactly the input for
  `Write-Error "Multiple export applications defined ..." -ErrorAction Stop`.
- Green proof: with the placeholder filter and the same committed data the
  expression returns `old filter=2 new filter=1 -> M365DscExportApplication`, so
  the code fix alone unblocks the task; removing the placeholder from
  `source/Global/Azure.yml` restores the documented three-identity example.
- `Clean` is the first task of the `export` workflow and preserves only
  `RequiredModules`, so a failing `ExportTenantData` leaves no `output\Export`
  at all and `PublishPipelineArtifact@1` fails on the missing path.
- `continueOnError` was removed from `Export Tenant Configuration` only.
  `Convert Exported Tenant Configuration` keeps it, because the raw export is
  still worth publishing when only the MOF-to-YAML conversion fails.
- `.\build.ps1 -Tasks rsop` in a detached `pwsh`: `Build succeeded. 7 tasks, 0
  errors, 0 warnings`, 158 tests passed, including the new
  `[+] The environment 'Dev' defines exactly one export application`.
- `Invoke-ScriptAnalyzer` on both changed `.ps1` files reports only the
  pre-existing `PSAvoidUsingWriteHost`, `PSAvoidUsingCmdletAliases` and
  `PSUseDeclaredVarsMoreThanAssignments` findings; AST parse 0 errors.
- Unfixed finding, reported to the user: `InvokingDscExportConfiguration` calls
  `dir -Path $Path -Recurse -Filter *.ps1` with an undefined `$Path`. Its own
  `try/catch` swallows the binding error, so the task compiles no MOF and
  `ConvertMofToYaml` then reports `No MOF file found`. Out of scope for the
  reported failure.

## Earlier focus

`lab/31 Agent Setup.ps1` could no longer fetch the Azure Pipelines agent:
`vstsagentpackage.azureedge.net` was retired with the Edgio Azure CDN and no
longer resolves, so `Get-LabInternetFile` failed with `No such host is known`.
All build agent software now comes from Chocolatey, which also removed the
script's dependency on the Azure lab sources share and with it the second
defect, the hard-coded `C:\AL\AzureLabSources.ps1` call. The edits are
uncommitted on `main` at the user's request.

## Earlier evidence

- `Resolve-DnsName vstsagentpackage.azureedge.net` returns nothing;
  `download.agent.dev.azure.com` resolves to `96.16.53.162`. The Chocolatey
  package `azure-pipelines-agent` 4.274.1 downloads from that host, and
  `vscode` 1.132.0, `vscode-powershell` 2025.4.0, `git` 2.55.0.3 and
  `notepadplusplus` 8.9.7 all exist on the community feed.
- Its `chocolateyinstall.ps1` only runs `Agent.Listener.exe configure` when the
  `/Url` package parameter is set, so installing it with `/Directory` alone
  extracts the binaries without registering an agent. That keeps the personal
  access token out of the Chocolatey command line and log, and the existing
  per-agent `config.cmd` flow, its idempotency guard and the `DeployDebug`
  helper `.cmd` files stay unchanged.
- `AutomatedLabWorker` 5.61.0 writes `AzureLabSources.ps1` to
  `Join-Path $deployDebug AL`, where `$deployDebug` expands
  `$AL_DeployDebugFolder`. `Get-LabConfigurationItem -Name AL_DeployDebugFolder`
  returns `$([Environment]::GetFolderPath('ApplicationData'))/DeployDebug`, so
  the file lives below `%APPDATA%\DeployDebug\AL` and never at `C:\AL`.
  `AutomatedLab.Common` 2.3.37 still hard-codes the same legacy path in its own
  `Install-LabSoftwarePackage` fallback, which is a third-party defect.
- `lab/31` was the only file in the repository referencing the lab sources share
  or the `Z:` drive, so removing the mapping activity affects nothing else.
- Red proof in a scratch tree against the committed script: both new cases fail
  with `Expected $null or empty, but got 'https://vstsagentpackage.azureedge.net/agent/4.251.0/vsts-agent-win-x64-4.251.0.zip'`
  and `... but got 'C:\AL\AzureLabSources.ps1'`. With the fix,
  `tests/ConfigData/AzHelpers.Tests.ps1` is 26 passed, 0 failed.
- The live run against the lab is untested; the change was validated statically.

## Earlier focus

The first successful `lab/30 Create Agent VMs.ps1` run surfaced two further
defects. It created the build agent identity with `New-M365DscIdentity` without
`-OnlyServicePrincipals`, so Entra registered a superfluous application next to
the user-assigned managed identity and the immediate `Update-MgApplication`
returned `404` before replication caught up. And the post-deployment validation
of `Install-Lab` reported `Lab deployment seems to have failed` for a healthy
lab, because `AutomatedLabTest` 5.61.4 cannot be discovered under Pester 6.

## Earlier evidence

- Red proof against the committed scripts in a scratch tree: the two new guards
  fail — `Expected 'OnlyServicePrincipals' to be found in collection @('Name',
  'PassThru')` and the `Remove-MgApplication` invocation count. With the fix,
  `tests/ConfigData/AzHelpers.Tests.ps1` is 24 passed, 0 failed.
- The leftover application `M365DscLcmM3652DevIdentity`
  (`6bfa5419-43de-40c2-8f80-06a5bd68cc17`, AppId `b845e41e-...`) was removed
  from the Dev tenant. Its AppId differed from the managed identity service
  principal `1bbc976d-b631-43ce-a900-507cba535114` (AppId `0962a055-...`),
  which is untouched. The recycle bin holds a second such application
  (`701a55a8-...`), so an earlier run had produced the same artefact.
- `Invoke-LabPester` builds `[PesterConfiguration]::Default` and passes it to
  `Invoke-Pester -Configuration`, so `$PesterPreference` cannot set
  `Run.FailOnNullOrEmptyForEach`. The host had only Pester 3.4.0, 6.0.1 and
  6.1.0, hence `lab/00 Prep.ps1` pins `5.7.1` and `lab/30` imports it before
  `Install-Lab`. Not yet exercised in a live deployment.
- `Get-Item: Cannot find path 'C:\AL'` during "Configuring localization and
  additional disks" is AutomatedLab's own `$Global:AL_DeployDebugFolder`: some
  guest blocks read it with `Get-Item` although only other blocks create it.
  Third-party, non-terminating, not fixed here.

## Earlier focus

`lab/30`, `lab/31`, `lab/88`, `lab/89` and `lab/97` passed no
`SkipExchangeOnline` to `Connect-M365Dsc`, so the entitlement check ran although
none of them touches Exchange Online and the Dev tenant is configured with
`HasExchangeOnline: false`. All five now derive the switch from the environment,
and a Pester case guards every `lab/` script that connects.

## Earlier focus (git paths)

`lab/20 Configure AzDo Project.ps1` adapted the five pipeline files but could
not commit them: it prefixed the repository-root relative paths of `git diff
--name-only` with `..`, which lands outside the repository when the script runs
from the repository root. The block now uses `git -C <repository root>` with the
unchanged paths, and `lab/31 Agent Setup.ps1` lost the same `..` assumption. The
edits are uncommitted at the user's request, and the five adapted pipeline files
are still uncommitted from the failed run.

## Earlier evidence

- `git add (Join-Path -Path .. -ChildPath 'pipelines/build.yml')` from
  `C:\Git\M3652` reproduces the verbatim fatal; `git -C C:\Git\M3652 add
  --dry-run 'pipelines/build.yml'` succeeds from the repository root and from
  `lab`. Both checks ran with `--dry-run`, so the index is untouched.- `git status` still lists the five adapted `pipelines/*.yml` files as modified,
  so re-running the script commits and pushes them.
- `lab/10 Setup App Registrations.ps1` is not affected: it reads `git status -s`,
  whose paths are relative to the current directory, so its `Substring(3)` form
  works from either folder.

## Earlier focus

`Disconnect-AzAccount` failed in every `lab/` script with `Method not found:
'Void Microsoft.Identity.Client.Extensions.Msal.MsalCacheHelper.RegisterCache(Microsoft.Identity.Client.ITokenCache)'`.
`Disconnect-M365Dsc` now falls back to `Clear-AzContext -Scope Process` for that
specific failure. The Exchange Online entitlement work of the same session is
complete and committed on `ai/exchange-license-optional`.

## Earlier evidence (MSAL)

- Measured assembly versions: `Az.Accounts` `5.3.2` ships
  `Microsoft.Identity.Client` and `Microsoft.Identity.Client.Extensions.Msal` at
  `4.65.0.0`, `ExchangeOnlineManagement` `3.9.2` ships only
  `Microsoft.Identity.Client` `4.74.1.0`, and `Microsoft.Graph.Authentication`
  `2.35.1` ships both at `4.78.0.0`.
- Probe with Graph loaded first: the process holds
  `Microsoft.Identity.Client=4.78`, `Extensions.Msal=4.78` and, after importing
  `Az.Accounts`, additionally `Extensions.Msal=4.65`. Reflection shows the two
  helpers expect `ITokenCache` from their own MSAL version, which is why the
  call from the `4.65` helper cannot bind.
- Both pins come from the Microsoft365DSC dependency block, so the conflict
  cannot be resolved by bumping a version.
- `Disconnect-M365Dsc` now normalises the terminating and non-terminating form
  of the failure, warns, and calls `Clear-AzContext -Scope Process -Force`. Any
  other error is re-surfaced unchanged.
- Regression proof: with the fix reverted in a scratch copy of the module, both
  new tests fail; with the fix, all 14 tests of
  `tests/ConfigData/AzHelpers.Tests.ps1` pass.
- `.\build.ps1 -Tasks rsop` in a clean `pwsh -NoProfile`:
  `Build succeeded. 7 tasks, 0 errors, 0 warnings`, 147 tests, 0 failures, 2
  skipped.

## Exchange Online entitlement

The per-environment `HasExchangeOnline` setting in `source/Global/Azure.yml` is
the single switch the user maintains: it drives the prep scripts, the Datum
hierarchy and the export. No script writes it back. The Dev environment is
currently set to `false` and the full build is green.

- Entitlement check: `Test-M365DscExchangeOnlineLicense` reads the
  `00000002-0000-0ff1-ce00-000000000000` service principal and the subscribed
  SKUs through Graph, so it needs no Exchange Online connection. It rejects a
  disabled resource service principal and a tenant whose only Exchange service
  plan is `EXCHANGE_S_FOUNDATION`, which ships with almost every SKU.
- `Connect-M365Dsc` skips `Connect-M365DscExchangeOnline` when the caller passes
  `-SkipExchangeOnline`, and otherwise fails with an actionable error when the
  tenant is not licensed. `Disconnect-M365Dsc` no longer calls
  `Disconnect-ExchangeOnline` without a connection.
- `lab/10`, `lab/11` and `lab/98` read `HasExchangeOnline` from the environment
  and pass the switch to `Connect-M365Dsc` and `Test-M365DscConnection`.
- Skipped prep steps: the EXO service principal in `New-M365DscIdentity`,
  `Get-M365DscIdentity` and `Remove-M365DscIdentity`; the Exchange API
  permissions in `Get-M365DSCCompiledPermissionList2`; the `Exchange
  Administrator` directory role and the eight Exchange role groups in
  `Add-M365DscIdentityPermission` and `Remove-M365DscIdentityPermission`.
- Config data: `source/Datum.yml` swaps both Exchange layers for
  `1-AllTenantsConfig\ExchangeDisabled` through a `Datum.InvokeCommand`
  expression that reads the environment's `HasExchangeOnline`. Isolated probes
  confirmed that both `$Node` and `$datum` are usable inside a
  `ResolutionPrecedence` entry.
- Full `.\build.ps1` with `HasExchangeOnline: false` on Dev:
  `Build succeeded. 21 tasks, 0 errors, 0 warnings`, 145 tests, 0 failures, 2
  skipped. The Dev RSOP holds 0 `cEXO*` configurations against 4 for Prod and
  Test, and `output/MOF/Dev/LcmM3652Dev.mof` holds 0 `MSFT_EXO` instances
  against 8 each for the other two.
- Re-running the build repeatedly in one long-lived session fails the two tests
  that construct an `M365DscIdentity` with `Cannot convert the "M365DscIdentity"
  value of type "M365DscIdentity" to type "M365DscIdentity"`. That is the
  PowerShell class identity drift of `Import-Module -Force`, not a defect; a
  fresh process is green.
- `source/Global/Azure.yml` defines only the `Dev` environment, so the `Test`
  and `Prod` nodes resolve `HasExchangeOnline` to `$null`, which the `-ne $false`
  default treats as licensed.
- The live run against an unlicensed tenant is untested.

## Earlier evidence

- `lab/98 Cleanup App Registrations.ps1` was the last `lab/` script without
  `Import-Module -Name $PSScriptRoot\AzHelpers.psm1 -Force`; it only ever ran in
  a session that had executed another script.
- `Add-M365DscIdentityPermission` already replayed the claims challenge around
  `New-AzRoleAssignment`; `Remove-M365DscIdentityPermission` had no such retry
  and called `Remove-AzRoleAssignment` without `-ErrorAction Stop`. Azure
  PowerShell writes a non-terminating error, so the removal continued and
  printed `Removing the application ... from the role 'Owner'.` after the
  failure, then closed the block with `Done adding Azure permissions`.
- The retry now lives in `Resolve-M365DscAzureMfaChallenge`, which both
  functions call from their catch block. It returns `$false` for an unrelated
  error, and the caller rethrows.
- Regression proof: with the removal fix reverted in a scratch copy of the
  module, `Should retry the Owner role removal after replaying the claims
  challenge` fails with the verbatim MFA error.
- The live run of `lab/98 Cleanup App Registrations.ps1` is untested against the
  tenant. The claims-challenge replay itself is unchanged code that was already
  verified for `New-AzRoleAssignment`.

- `lab/11 Test Connection.ps1` connected to the Azure account's default
  subscription instead of the subscription configured for the Dev environment.
- `source/Global/Azure.yml` configures Dev subscription
  `9522bd96-d34f-4910-9667-0517ab5dc595`, but application-secret authentication
  connected to the account's other subscription
  `<other-subscription-id>`. Validation correctly exposed the mismatch.
- `Connect-M365DscAzure` forwarded `SubscriptionId` only in its interactive
  branch. Its application-secret and certificate branches omitted the value
  from `Connect-AzAccount`, which then selected the account's default Azure
  context. Both branches now pass the canonical `Subscription` parameter when
  a subscription is configured.
- Az.Accounts `5.3.2` exposes `Subscription` in both
  `ServicePrincipalWithSubscriptionId` and
  `ServicePrincipalCertificateWithSubscriptionId`; `SubscriptionId` is an
  alias. A focused Pester 6.0.1 regression test covers both branches: 2 passed,
  0 failed.
- Final `\.\build.ps1 -Tasks rsop`: 131 tests passed, 0 failed; 7 tasks,
  0 errors and 0 warnings.
- The exact live command `& '.\lab\11 Test Connection.ps1'` now connects to
  `<dev-subscription-name>` (`9522bd96-d34f-4910-9667-0517ab5dc595`). Azure
  tenant and subscription, Microsoft Graph tenant, and Exchange Online tenant
  validation all pass before the script disconnects cleanly.
- The placeholder identity `<Name of your Application of Managed Identity>` was
  registered as application `<registered-application-id>` on
  2026-08-05. It received 166 Graph application permissions and the `Global
  Reader` and `Exchange Administrator` directory roles. The subscription `Owner`
  assignment failed on the MFA claims challenge, and the eight Exchange role
  groups failed on licensing, so those two did not take effect. Cleanup is
  `Remove-M365DscIdentityPermission` followed by `Remove-M365DscIdentity`; not
  run, it needs the user's approval.
- `New-M365DscIdentity -OnlyServicePrincipals -PassThru` was broken: it looked
  the result up through `$appRegistration.DisplayName`, which is `$null` on that
  path. Changed to the `Name` parameter, which is what the application is
  created and searched with anyway.
- The claims-challenge regex was tested against the verbatim `New-AzRoleAssignment`
  error text: it captures `eyJhY2Nlc3NfdG9rZW4i...`, which decodes to
  `{"access_token":{"acrs":{"essential":true,"values":["p1"]}}}`; an unrelated
  error text does not match, so it rethrows.
- The placeholder guard `^<.+>$` matches only the placeholder, not
  `M365DscSetupApplication`, `M365DscLcmApplication` or
  `M365DscExportApplication`.
- After removing the placeholder from `source/Global/Azure.yml`,
  `New-DatumStructure` resolves three identities and exactly one export
  application, which is what `.build/Export/ExportTenantData.ps1` requires.
- `.\build.ps1 -Tasks rsop`: `Build succeeded. 7 tasks, 0 errors, 0 warnings` in
  27 seconds, 129 configuration-data tests, 0 failures.
- `.\build.ps1 -Tasks init` is a documented prerequisite
  (`docs/GettingStarted.md` 1.4.1) and `.build/InitLab.ps1` imports `AzHelpers`,
  `CertHelpers` and `M365DscHelpers` into the session. Skipping it produced
  `The term 'New-M365DSCSelfSignedCertificate' is not recognized`, because
  `New-M365DscIdentity -GenereateCertificate` resolved that function only
  through the global session state. `AzHelpers.psm1` now imports `CertHelpers`
  itself; verified in a clean `pwsh -NoProfile` that importing `AzHelpers` alone
  exports 20 functions including `New-M365DSCSelfSignedCertificate`.
  `Invoke-ScriptAnalyzer` reports the same 71 pre-existing findings, AST parse 0
  errors.
- `init` does not explain the other three failures of the same run: the missing
  `Microsoft.Graph.*` modules were absent from disk and `InitLab` imports only
  `ExchangeOnlineManagement`, `Az.Accounts`, `Az.Resources` and
  `Microsoft365DSC`; the `New-AzRoleAssignment` MFA claims challenge is a tenant
  Conditional Access requirement; and `Add-RoleGroupMember` failing with
  `Organization ... is not licensed for Exchange email functionality` is tenant
  licensing.
- The script failed with `The term 'Get-MgApplication' is not recognized`, then
  cascaded into `Get-M365DscIdentity: Cannot bind argument to parameter 'Name'`
  and `The property 'Secret' cannot be found on this object`, because
  `New-M365DscIdentity` kept going with a `$null` application. Only
  `Microsoft.Graph.Authentication` `2.35.1` was installed on the machine.
- `git show 467c719^:RequiredModules.psd1` lists 26 `Microsoft.Graph.*` pins at
  `2.28.0` under Microsoft365DSC `1.25.730.1`. `1.26.729.2` pins
  `Microsoft.Graph.Authentication` alone, so the lab scripts lost the SDK they
  had been free-riding on. `RequiredModules.psd1` now declares the four
  sub-modules they need, outside the generated block.
- All four exist on the gallery at `2.35.1` (latest is `2.39.0`). Verified in a
  clean `pwsh -NoProfile` after saving them: all 25 `Mg*` cmdlets used by
  `lab/AzHelpers.psm1` and `lab/M365DscHelpers.psm1` resolve at `2.35.1`, and
  `AzHelpers` still imports.
- `.\build.ps1 -ResolveDependency -Tasks noop` aborted on
  `Access to the path 'PowerShellYamlSerializer.dll' is denied`. Four other
  `pwsh` processes held `powershell-yaml`. `Resolve-Dependency.ps1` skips that
  module only when the *restoring* session has it loaded, so a lock held by
  another process still fails the save. The four modules were saved with the
  same `Save-PSResource` call `Resolve-Dependency` makes.
- `AADSTS500014` on Exchange Online, seen earlier in the session, was a lapsed
  Microsoft 365 subscription in the Dev tenant: zero subscribed SKUs, all 88
  `organization.assignedPlans` entries `Deleted`, and the Exchange, SharePoint,
  Teams and Management API service principals disabled while Graph stayed
  enabled. Resolved outside this repository.

- `lab/10 Setup App Registrations.ps1` was the only `lab/` script without
  `Import-Module -Name $PSScriptRoot\AzHelpers.psm1 -Force`; `11`, `30`, `31`,
  `88`, `89` and `97` all carry it, and `.build/InitLab.ps1` imports the module
  too. It only ever ran because a session that had executed another script still
  held the module. A `CommandNotFoundException` also aborts the whole `if`
  statement, so the failed `Test-M365DscConnection` guard was skipped instead of
  stopping the script, and the run continued into `New-M365DscIdentity`.
- Verified in a clean `pwsh -NoProfile`: after the added import, all of
  `Connect-M365Dsc`, `Disconnect-M365Dsc`, `Test-M365DscConnection`,
  `New-M365DscIdentity`, `Add-M365DscIdentityPermission` and
  `Select-M365DscCommandParameter` resolve from `AzHelpers`, and
  `New-DatumStructure`, `Protect-Datum` and `ConvertTo-Yaml` resolve from
  `output/RequiredModules`. `New-DatumStructure` loads and yields the `Dev`
  environment.
- `source/Global/Azure.yml` still lists a fourth identity named
  `<Name of your Application of Managed Identity>` with `IsManagedIdentity: true`.
  Nothing under `lab/` reads `IsManagedIdentity`, so the loop would register an
  application under that literal name and assign it subscription `Owner`. Not
  changed; it is tenant data the user owns.
- `Sync-M365DSCParameter` has 0 occurrences in the pinned Microsoft365DSC
  `1.26.729.2` package; older releases exported it from `M365DSCUtil.psm1`.
  `Connect-M365Dsc` called it twice, so `$param` was `$null` and
  `Connect-M365DscAzure @param` passed `$null` positionally, which produced the
  misleading `A positional parameter cannot be found that accepts argument
  '$null'` and left every service unconnected.
- `Select-M365DscCommandParameter` now does the filtering locally. Verified in
  an imported session: for `@{TenantId;TenantName;SubscriptionId;ErrorAction}`
  it returns `TenantId,TenantName` for `Connect-M365DscExchangeOnline` and
  `TenantId,SubscriptionId` for `Connect-M365DscAzure`. AST parse reports 0
  errors and `Invoke-ScriptAnalyzer` reports no new findings.
- `Get-AzAccessToken` in `Az.Accounts` `5.3.2` returns `Token` as a
  `SecureString`, and `Connect-MgGraph -AccessToken` in
  `Microsoft.Graph.Authentication` `2.35.1` takes `SecureString`. The token hand-off
  inside `Connect-M365DscAzure` therefore needs no change.

## Older evidence

- `build.yaml` configures the Sampler task `Set_PSModulePath` with
  `RemovePersonal: true` and `RemoveProgramFiles: true`. A session that ran
  `build.ps1` therefore sees neither the CurrentUser nor the AllUsers module
  scope. Running `lab/00 Prep.ps1` there reinstalled `AutomatedLab` although
  5.61.0 was present, `Install-Module` resolved to the PSResourceGet
  compatibility shim and prompted about the untrusted gallery, and
  `Install-LabAzureRequiredModule` and `Get-LabConfigurationItem` were still
  unrecognized. `Restore-DefaultModulePath` now repairs the process
  `PSModulePath` first. Measured in a session with the stripped path:
  `AutomatedLab` went from 0 to 2 discovered copies and both commands resolved,
  while `output/RequiredModules` was kept behind the defaults.
- `Az.Accounts` `5.5.1` sat in `C:\Users\<user>\Documents\PowerShell\Modules`
  while `5.5.2` sat in `C:\Program Files\PowerShell\Modules`. PowerShell imports
  from the first `PSModulePath` entry containing a module, and the CurrentUser
  path comes first, so every session loaded `5.5.1`. `Az.Storage` `9.7.2`
  demands `5.5.2`, hence `Test-LabAzureModuleAvailability` returned `$false` in
  a completely clean `pwsh -NoProfile` too. Restarting the script could never
  help.
- `AutomatedLab` `5.57.3-preview` in `C:\Program Files\PowerShell\Modules`
  shadowed `5.61.0` in `C:\Program Files\WindowsPowerShell\Modules`, while every
  AutomatedLab sub-module on the machine was already `5.61.0`.
- The pin `5.57.3-preview` was never recognised as installed:
  `Where-Object Version -eq '5.57.3-preview'` compares a `[version]` against the
  full prerelease string. The script reinstalled `AutomatedLab` on every run.
- The `Administrator rights are required` message was a false lead. Reproduced
  in an elevated session: PowerShellGet's `Copy-Module` raises
  `AdministratorRightsNeededOrSpecifyCurrentUserScope` when the destination
  module is in use by another PowerShell process.
- `Get-LabConfigurationItem -Name RequiredAzModules` lists Az.Accounts,
  Az.Storage, Az.Compute, Az.Network, Az.Resources, Az.Websites and Az.Security.
  `Install-LabAzureRequiredModule` accepts any installed copy at or above the
  minimum version, so it never repairs a shadowed scope.
- After the fix, a clean `pwsh -NoProfile` run of the script removed
  `Az.Accounts 5.5.1` and `AutomatedLab 5.57.3`, and
  `Test-LabAzureModuleAvailability` loaded all seven Az modules without a
  version conflict. The run then stopped at the interactive
  `Enable-LabHostRemoting` confirmation, which needs a real user at the console.
- `Invoke-ScriptAnalyzer` reports no findings besides the pre-existing
  `PSAvoidUsingWriteHost` warnings, and `Get-Help` resolves the new script-level
  help rather than the help of `Resolve-ShadowedModule`.

- `RequiredModules.psd1` pinned `DscConfig.M365` `0.7.9-preview0001`, a version
  that is not published on the PowerShell Gallery. The newest published releases
  are `0.6.1` (stable) and `0.7.0-preview0001`, both from 2026-08-04.
- The restore skipped the module without failing, leaving 51 folders in
  `output/RequiredModules` and no `DscConfig.M365`. `TestConfigData` then failed
  during Pester discovery with `Cannot find path ...\DscConfig.M365`, because
  `tests/ConfigData/CompositeResources.Tests.ps1` resolves every entry of
  `build.yaml`'s `Sampler.DscPipeline.DscCompositeResourceModules`. Only 73 of
  129 configuration-data tests ran.
- `.\build.ps1` after that fix: `Build succeeded. 21 tasks, 0 errors, 0 warnings`
  in 5 minutes 31 seconds, with 129 configuration-data tests and 12 acceptance
  tests, both 0 failures.
- `RequiredModules.psd1` pins Microsoft365DSC `1.26.729.2`,
  ComputerManagementDsc `10.0.0`, NetworkingDsc `9.1.0`,
  PSDesiredStateConfiguration `2.0.8` and Az.KeyVault `6.4.2`.
- `Resolve-Dependency.psd1` bootstraps `Microsoft.PowerShell.PSResourceGet`
  `1.2.0`. Version `1.0.1` aborted the restore with `Requested value 'V2' was
  not found`.

## Open risk

`.memory-bank/` is tracked, so a push sends it to the public repository. The
three identifiers that `HEAD` did not already contain — the account's second
subscription ID, the application ID registered on 2026-08-05, and the Dev
subscription display name — are redacted to angle-bracket placeholders in this
file and in `progress.md`. Keep new tenant facts redacted the same way.

The `tests/ConfigData/AzHelpers.Tests.ps1` mocks still hard-code the live tenant
and subscription IDs. Both are already public through `docs/GettingStarted.md`
and `export/readme.md`, so this exposes nothing new, but the mocks would work
just as well with placeholder GUIDs. The service-principal object ID from the
2026-08-06 cleanup failure was replaced with a placeholder GUID before the test
was added.

## Next step

Nothing is committed or pushed on `update/2610`. The default workflow is green
in the working tree and in a clean clone, so what remains is the work that this
repository cannot prove or do alone:

- Decide when to commit and how to slice the branch into pull requests. The
  register, the `UPSTREAM: <ID>` markers in the code and
  `tests/ConfigData/UpstreamChanges.Tests.ps1` are one unit; the Graph pin fix
  stands alone.
- Plan and track the cross-repository work in the project plan, which is kept
  outside this repository. The handoff prompt for that session was written on
  2026-10-29 and is in the session files folder, not in this repository.
- Make the changes of `docs/upstream-changes.md` in their repositories, one
  handoff prompt per repository, in this order: DscBuildHelpers (DBH-4, DBH-3,
  DBH-1; DBH-2 is an investigation), Sampler.DscPipeline (SDP-4, SDP-1, SDP-3,
  SDP-2), DscConfig.M365 (DC365-2, DC365-3, DC365-1), the Microsoft365DSC
  engine (issues only) and last this repository, which bumps the pins and
  deletes the workarounds by the removal checklist at the end of the register.
  The prompts, written on 2026-10-30, are stored outside this repository next
  to a scratch-blueprint toolset that proves a change without touching
  `output\`. DBH-1 gates SDP-2 and the DscConfig.M365 unit tests.
- Apply one MOF to a lab node to see how the LCM handles the class-based MOFs
  and the `Ensure` that the Items-style composites inject, and run the export,
  reapply and test workflows on 2.x. None of that has run.
- Restore the three `DefaultUserRoleAllowedTo*` settings as
  `DefaultUserRolePermissions` when a `DscConfig.M365` release exposes it and
  DscBuildHelpers writes nullable embedded properties (DBH-4).

The warning of `PrepareDscCompile` is the signal to compare the overrides with a
newer Sampler.DscPipeline or DscBuildHelpers; a resource filter in
`Initialize-DscResourceMetaInfo` and a cache for class-based resources upstream
would make them obsolete. Restart the PowerShell session before any delete or
restore of `output\`. The live `lab/98 Cleanup App Registrations.ps1` run still
needs the user's tenant.
