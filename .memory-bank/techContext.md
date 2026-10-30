---
status: current
last-verified: 2026-10-29
owner: active-agent
source: repository evidence
---

# Tech context

## Stack

- Sampler 0.120.0 build framework on InvokeBuild, with Sampler.DscPipeline 0.3.0
  supplying the DSC-specific tasks; workflows are declared in `build.yaml`.
  `.build/DscCompileTasks.ps1`, `.build/DscCompileHelpers.ps1`,
  `source/CompileRootConfiguration.ps1` and `source/RootConfiguration.ps1`
  override parts of it for class-based modules (Decision 28 in
  `systemPatterns.md`). Every such workaround is registered in
  `docs/upstream-changes.md` and carries a comment `UPSTREAM: <ID>`; the test
  `tests/ConfigData/UpstreamChanges.Tests.ps1` keeps the two consistent
  (Decision 29).
- Datum 0.41.0 for hierarchical configuration data, plus `Datum.ProtectedData`
  and `Datum.InvokeCommand` handlers; hierarchy declared in `source/Datum.yml`.
- Microsoft365DSC 2.26.1021.1 — class-based since 2.x, with no `DSCResources`
  folder and 541 exported resources — driven through the composite resource
  modules `DscConfig.M365` 0.8.0-preview0001 and `DscConfig.Demo`.
- Pester `latest` for the configuration-data and acceptance suites; 6.2.0
  resolved on 2026-10-29.
- GitVersion in `ContinuousDelivery` mode with `next-version: 0.0.1`.
- Azure DevOps YAML pipelines in `pipelines/` and `azure-pipelines.yml`;
  AutomatedLab-based provisioning scripts in `lab/`.

## Environment

- Windows. Verified locally on PowerShell 7.6.4 (Windows 10.0.26100).
- Build tasks are gated by `test7` and require PowerShell 7+. The
  `startConfiguration` and `testConfiguration` workflows are gated by `test5`
  and require Windows PowerShell 5.1.
- `SetPSModulePath` removes the personal and Program Files module paths during
  the build, so `Find-Module` and PowerShellGet are unavailable in a shell that
  has already run a build. Use a fresh shell or the PSGallery OData API.
- Dependencies resolve into `output/RequiredModules` (60 module folders after a
  clean restore on 2026-10-29, several in more than one version such as
  `Az.Accounts`, `Sampler` and `PowerShellGet`). Earlier restores also held a
  disabled Pester `_5.7.1`; the clean restore did not recreate it.

## Constraints

- Module versions in `RequiredModules.psd1` are pinned. The Microsoft365DSC
  block is generated, not hand-edited, and must match the output of
  `Update-M365DSCDependencies -ValidateOnly`.
- The upgrade procedure documented inside `RequiredModules.psd1` is: bump the
  Microsoft365DSC version, restart the session to release module handles, delete
  `output/`, restore dependencies, regenerate the dependency block, then build.
- `-UseModuleFast` is commented out in the pipeline definitions.
- `PSDependOptions` sets `AllowPreRelease = $true`, so a `latest` pin resolves
  to prerelease versions.
- `Resolve-Dependency.psd1` must bootstrap `Microsoft.PowerShell.PSResourceGet`
  1.1 or later. 1.0.1 cannot parse a `PSResourceRepository.xml` that carries
  the `APIVersion="V2"` casing written by 1.1+ and aborts the restore with
  `Requested value 'V2' was not found`.
- Az.KeyVault is capped by the Az.Accounts version Microsoft365DSC pins.
  Az.Accounts 5.3.2 allows Az.KeyVault up to 6.4.2; 6.5.0 and later demand
  5.5.0 or newer.
- The `lab/` scripts call `Microsoft.Graph.*` cmdlets that Microsoft365DSC no
  longer pins. `RequiredModules.psd1` declares `Microsoft.Graph.Applications`,
  `Microsoft.Graph.Identity.DirectoryManagement`,
  `Microsoft.Graph.Identity.Governance` and `Microsoft.Graph.Users` outside the
  generated block. Their version must equal the generated
  `Microsoft.Graph.Authentication` pin, because every Graph SDK sub-module
  manifest requires that exact version of it. A different pin makes the restore
  save a second `Microsoft.Graph.Authentication`, and the `BeforeAll` of
  `tests/ConfigData/AzHelpers.Tests.ps1` then fails with `Assembly with same name
  is already loaded`, so 26 tests report that they did not run.
  `tests/ConfigData/RequiredModules.Tests.ps1` guards the equality.
- A restore fails with `Access to the path 'PowerShellYamlSerializer.dll' is
  denied` when any other PowerShell process holds `powershell-yaml`.
  `Resolve-Dependency.ps1` skips that module only when the restoring session
  itself has it loaded. Close the other sessions, or save the affected module
  on its own with `Save-PSResource -Path output\RequiredModules
  -TrustRepository`.
- Every pin must name a version that exists on the PowerShell Gallery. A pin to
  an unpublished version is skipped by the restore without failing it, and only
  surfaces later as a missing folder under `output/RequiredModules`.
- Never push to a git remote unless the user asks for it in the current turn.
- `Az.Accounts` `5.3.2` is built against MSAL `4.65`, `Microsoft.Graph.Authentication`
  `2.41.1` against MSAL `4.90` (`2.35.1` shipped `4.78`), and
  `ExchangeOnlineManagement` `3.9.2` ships
  `Microsoft.Identity.Client` `4.74.1` without the `Extensions.Msal` companion.
  Both versions are dictated by the Microsoft365DSC dependency block, so the
  conflict cannot be resolved by bumping a pin. Once Graph has loaded its newer
  MSAL — observed with `4.78`, not re-observed with `4.90` — `Disconnect-AzAccount` fails with `Method not found: 'Void
  Microsoft.Identity.Client.Extensions.Msal.MsalCacheHelper.RegisterCache(Microsoft.Identity.Client.ITokenCache)'`.
  `Disconnect-M365Dsc` falls back to `Clear-AzContext -Scope Process`.
- A VS Code PowerShell console that ran a build keeps modules from
  `output\RequiredModules` loaded (`Az.Accounts`, `Pester`, `PSResourceGet`,
  `powershell-yaml` and others). While it does, deleting `output\` aborts
  part-way and damages the pinned modules it had already reached, and
  `Resolve-Dependency.ps1` fails re-extracting PSResourceGet with `Access to the
  path '...NuGet.Versioning.dll' is denied`. Restart the PowerShell session
  first, or restore and build in a clean clone under `%TEMP%`.
- Microsoft365DSC 2.x adds `M365DSC.PSDesiredStateConfiguration` to its
  dependency block. With the build's `PSModulePath` the first `Get-DscResource`
  resolves to that module by auto-loading: module auto-loading takes the first
  module on the module path that exports the command, and in
  `output\RequiredModules` both engines sit in one folder, where the fork's name
  sorts first (measured 2026-10-29; with the 2.0.8 folder first on the path it
  resolves to 2.0.8). Nothing in the pipeline imports `PSDesiredStateConfiguration` 2.0.8
  first, so two modules of that name end up loaded: the later `Import-DscResource
  -ModuleName PSDesiredStateConfiguration` adds 2.0.8 next to the fork's inner
  3.1.10 module. The 1.x block has no such module. `PrepareDscCompile` imports
  the pinned 2.0.8 with `-Global`, removes the fork and fails unless exactly one
  module of that name remains.
- Microsoft365DSC 2.x resources are PowerShell classes (10 MB), and the engine
  re-parses the module for every `Import-DscResource` statement, 3.4 to 7.9 s
  each. Composite modules carry one per composite, so unfiltered enumeration is
  quadratic in practice; see `debugging-insights.md` for the numbers. The build
  therefore never enumerates all resources: it resolves the used composites by
  folder layout, seeds the DscBuildHelpers metadata for the resources they wrap
  and selects the modules to zip without listing their resources.

## Dependency state, pins on 2026-10-29

| Module | Pinned |
|---|---|
| Microsoft365DSC | 2.26.1021.1 |
| DscConfig.M365 | 0.8.0-preview0001 |
| DscConfig.Demo | `latest` (0.8.3 resolved) |
| ComputerManagementDsc | 10.0.0 |
| NetworkingDsc | 9.1.0 |
| PSDesiredStateConfiguration | 2.0.8 |
| Az.KeyVault | 6.4.2 |
| PSResourceGet (bootstrap) | 1.2.0 |
| Microsoft.Graph.Authentication | 2.41.1 |
| Microsoft.Graph.Applications | 2.41.1 |
| Microsoft.Graph.Identity.DirectoryManagement | 2.41.1 |
| Microsoft.Graph.Identity.Governance | 2.41.1 |
| Microsoft.Graph.Users | 2.41.1 |
| ExchangeOnlineManagement | 3.9.2 |
| MicrosoftTeams | 8.0.0 |
| PnP.PowerShell | 3.4.1 |
| Az.Accounts | 5.3.2 |
| DSCParser | 3.1.0.7 |
| ReverseDSC | 3.0.0.0 |
| M365DSC.mgx | 2.1.9 |
| M365DSC.PSDesiredStateConfiguration | 3.1.10 |

The comparison with the PSGallery latest versions, measured on 2026-08-05, was
dropped because the 2026-10-29 bump made it obsolete; measure again before
bumping anything on its own. The Graph, Exchange, Teams, PnP, Az, DSCParser,
ReverseDSC and `M365DSC.*` pins are dictated by the Microsoft365DSC dependency
manifest and must not be bumped on their own.

## Validation

- `.\build.ps1` — default `build` plus `pack` workflow; about five to six
  minutes with Microsoft365DSC 1.x (`1.26.729.2`: 5 min 31 s; `1.26.909.1`: 6 min
  5 s, of which `CompileRootConfiguration` is 4 min 18 s) and 6 min 27 s to
  6 min 43 s (clean clone and working tree) with 2.26.1021.1 and the DSC compile
  overrides (`PrepareDscCompile` 34.5 to 39.4 s, `CompileRootConfiguration` 4 min
  35 s to 4 min 55 s, `CompressModulesWithChecksum` 2.2 to 3.5 s).
  Without the overrides 2.26.1021.1 ran over an hour and then failed in
  `CompileRootConfiguration`: `Initialize-DscResourceMetaInfo` took about 48
  minutes and the "Preloading available resources" `Get-DscResource` another 21.
  A frozen-looking console is no hang (`debugging-insights.md`).
- `.\build.ps1 -ResolveDependency -Tasks noop` — restore dependencies only.
- `.\build.ps1 -Tasks rsop` — `TestConfigData` plus `CompileDatumRsop`, the
  cheapest guard for a configuration-data change.
- `build.yaml` defines no `test` workflow, so the VS Code task `test`
  (`build.ps1 -AutoRestore -Tasks test`) aborts with `Missing task 'test'`.
- Results land in `output/TestResults/*.xml`; transcripts in `output/Logs`.
- The last green full build, with Microsoft365DSC 1.26.729.2, was 21 tasks, 0
  errors, 0 warnings in 5 min 31 s with 129 configuration-data tests and 12
  acceptance tests, all passing. With 2.26.1021.1 and the overrides it is 22
  tasks, 0 errors, 0 warnings in 6 min 27 s with 199 configuration-data tests
  (`.\build.ps1 -Tasks rsop` reports them) and 12 acceptance tests, verified in
  the working tree on 2026-10-29. A run that
  reports far fewer configuration-data tests means a container, such as
  `CompositeResources.Tests.ps1`, failed during discovery.
