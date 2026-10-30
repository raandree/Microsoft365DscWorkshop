---
status: current
last-verified: 2026-10-30
owner: active-agent
source: repository evidence
---

# Progress

## Current status

On `update/2610` the default workflow (`build` plus `pack`) is green on the
October 2026 dependency set with Microsoft365DSC `2.26.1021.1`, verified in a
clean clone (22 tasks, 6 min 32 s) and, finally, in the working tree itself (22
tasks, 0 errors, 0 warnings in 6 min 27 s), with 199 configuration-data and 12
acceptance tests passing. It needs the project-level DSC compile overrides
(Decision 28 in `systemPatterns.md`) and the fix of 5 configuration keys that
2.x dropped. Every change that the dependencies need is tracked in
`docs/upstream-changes.md` (Decision 29). Nothing is committed or pushed. Before
that the last known green builds were the `feature/update2608` set with
Microsoft365DSC `1.26.729.2` and, verified on 2026-10-29, `1.26.909.1` (6 min
5 s). Not verified: the LCM's handling of the class-based MOFs and any live
tenant effect.

## Recent milestones

- 2026-10-30 Wrote one handoff prompt per repository for the upstream work, in
  dependency order: DscBuildHelpers, Sampler.DscPipeline, DscConfig.M365, the
  Microsoft365DSC engine (issues only) and then this repository, which consumes
  the releases and deletes the workarounds. Each prompt names its register
  entries, the proof and a result file that feeds the next step; a
  scratch-blueprint toolset proves a change with a full build without touching
  `output\` (default build green in a scratch copy: 22 tasks, 9 min under load).
  The prompts live on the user's desktop. Two register findings are new: the
  DscConfig.M365 unit tests need DBH-1, because they call
  `Initialize-DscResourceMetaInfo` over the whole module path, and M365PSDSC-1
  is re-scoped. Nothing was pushed.
- 2026-10-29 Wrote a handoff prompt for the planning and tracking of the
  cross-repository upstream work outside this repository; it lives in the
  session files folder and summarizes the evidence and the 13 register entries.
- 2026-10-29 Tracked every change that the dependencies need, for upstream pull
  requests later. `docs/upstream-changes.md` registers 13 changes in
  Sampler.DscPipeline, DscBuildHelpers, DscConfig.M365 and the Microsoft365DSC
  engine, each with evidence, the proposed change, the reference implementation
  and the workaround it makes obsolete; the workarounds carry `UPSTREAM: <ID>`
  markers and `tests/ConfigData/UpstreamChanges.Tests.ps1` keeps markers and
  register consistent. `docs/upstream-changes-composite-drift.md` lists the 64
  of 179 composites of DscConfig.M365 0.8.0 that differ from Microsoft365DSC
  2.26.1021.1. A scratch build with regenerated composites found DBH-4:
  DscBuildHelpers writes an empty block for nullable properties of embedded
  types, so `DefaultUserRolePermissions` cannot be set. The final default
  workflow in the working tree was green (22 tasks, 0 errors, 0 warnings, 6 min
  27 s), and so were two runs in a session that already held the M365DSC engine.
- 2026-10-29 Made `.\build.ps1` build Microsoft365DSC `2.26.1021.1` in about 6
  to 8 minutes instead of failing after more than an hour; the user chose to
  keep 2.x and to implement the pipeline changes here. `PrepareDscCompile`
  makes `PSDesiredStateConfiguration` 2.0.8 the only DSC engine and fills the
  DscBuildHelpers metadata table for the 11 resources and types that the 8 used
  composites wrap (33 to 48 s). `source/CompileRootConfiguration.ps1` finds the
  composites by folder layout (0.3 s, was 21 min), and an override of
  `CompressModulesWithChecksum` selects the modules to zip without listing
  their resources (2.3 s, was about 21 min). `source/` lost 5 keys that 2.x no
  longer has; 3 are a functional change, because the
  `DefaultUserRoleAllowedTo*` settings of `cAADAuthorizationPolicy` are no
  longer asserted. `tests/ConfigData/DscCompile.Tests.ps1` adds 24 tests.
- 2026-10-29 Investigated the build that "hangs for an hour" at `Reading DSC
  Resource metadata...` with Microsoft365DSC `2.26.1021.1`. It computes, it does
  not hang: Microsoft365DSC 2.x defines its 541 resources as classes in 10 MB of
  PowerShell, the engine caches nothing for them, and every `Import-DscResource
  -ModuleName Microsoft365DSC` re-parses all of it (3.4 to 7.9 s). The pipeline
  imports all 205 composites of DscConfig.M365 and DscConfig.Demo twice (179 of
  them import Microsoft365DSC), and `Initialize-DscResourceMetaInfo` adds about
  1,400 `Get-DscResourceProperty` calls, while the project uses 8 composites.
  The second failure, two modules named `PSDesiredStateConfiguration`, comes
  from the first `Get-DscResource` auto-loading
  `M365DSC.PSDesiredStateConfiguration`. Microsoft365DSC `1.26.909.1` builds
  green in 6 min 5 s. Details in `debugging-insights.md`.
- 2026-10-29 Fixed `.\build.ps1` failing in `TestConfigData` after the bump to
  Microsoft365DSC `2.26.1021.1`. The four hand-kept `Microsoft.Graph.*` pins
  stayed at `2.35.1` while the generated `Microsoft.Graph.Authentication` pin
  moved to `2.41.1`, so the restore saved a second Authentication copy and 26
  `AzHelpers.Tests.ps1` tests did not run (`Assembly with same name is already
  loaded`). The pins now follow the Authentication pin and
  `tests/ConfigData/RequiredModules.Tests.ps1` guards the equality;
  `TestConfigData` passes with 170 tests. The next failure, in
  `CompileRootConfiguration` after 1 h 10 min, was `The term
  'PSDesiredStateConfiguration PSDesiredStateConfiguration' is not recognized`:
  Microsoft365DSC 2.x ships its own DSC engine,
  `M365DSC.PSDesiredStateConfiguration`, whose inner module is also named
  `PSDesiredStateConfiguration`; that breaks `RootConfiguration.ps1` of
  Sampler.DscPipeline. The entry above resolves it.
- 2026-08-04 to 2026-08-17 Updated the dependencies to Microsoft365DSC
  `1.26.729.2` (the regenerated 14-entry dependency block,
  PSDesiredStateConfiguration `2.0.8`, PSResourceGet `1.2.0`) and fixed the
  `lab/` scripts, the Azure DevOps pipelines and the build on top of it. The
  detail is in `CHANGELOG.md` and in the git history of this file; what still
  matters:
  - `HasExchangeOnline` and `HasSharePointOnline` per environment are the
    switches for tenants without those workloads. `source/Datum.yml` swaps the
    Exchange or SharePoint layers for an empty `ExchangeDisabled` or
    `SharePointDisabled` layer, the export skips the `EXO*` or `SPO*`
    components, and the `lab/` scripts skip their Exchange Online work.
  - `Connect-M365DscAzure` forwards the configured subscription, and
    `Disconnect-M365Dsc` falls back to `Clear-AzContext -Scope Process` for the
    MSAL `MsalCacheHelper.RegisterCache` mismatch.
  - `RequiredModules.psd1` declares the four `Microsoft.Graph.*` modules that
    the `lab/` scripts call, because Microsoft365DSC stopped pinning them.
  - `lab/00 Prep.ps1` guards against shadowed `Az.Accounts` copies, restores
    the default module path and pins Pester `5.7.1` for `AutomatedLabTest`;
    `lab/31 Agent Setup.ps1` installs its software with Chocolatey.
  - `pipelines/buildTemplate.yml` calls `./build.ps1` from an inline `script`,
    because `Enable shell tasks arguments validation` rejects the filter script
    block in the `arguments` input of `PowerShell@2`.
  - Pester 6.1.0 words any terminating error of user code as `A 'break' or
    'continue' statement ... escaped from your code` (`debugging-insights.md`).
  - The Dev tenant's lapsed subscription (`AADSTS500014`) and its missing
    SharePoint Online are tenant conditions, not code defects.
- 2026-08-04 Created the Memory Bank base and verified the full build green (21
  tasks, 0 errors, 0 warnings); `017fc2a` fixed `TestConfigData` for Pester 6.
- 2025-08-04 `3df7af7`, the last commit before the dormant period.
- 2025-08-02 Export guidance for Azure DevOps added; `-UseModuleFast` disabled
  across the pipeline definitions.

## Stable capabilities

- Datum hierarchy loads, and RSOP compiles for the Dev, Test and Prod nodes.
- Root configuration and meta-MOF compile for all three environments.
- Artifact packing produces checksums, compressed modules and artifact
  collections.
- Configuration-data (129) and acceptance (12) Pester suites pass.
- Tenant export tooling and AutomatedLab provisioning scripts are present, but
  are unverified since the dormant period.

## Open work

### Tenant-readiness findings, 2026-08-04

- The compiled Dev MOF carries 23 Microsoft365DSC instances built from demo
  data, including `MSFT_AADSecurityDefaults`, `MSFT_AADAuthorizationPolicy`,
  `MSFT_SPOTenantSettings`, `MSFT_SPOAccessControlSettings`, two
  `MSFT_EXOTransportRule`, both EXO connectors and two `MSFT_EXORemoteDomain`
  pointing at `contoso.com`. Trim `Configurations.yml` before the first enact.
  Superseded for Dev on 2026-08-07: `HasExchangeOnline: false` and
  `HasSharePointOnline: false` reduce the Dev MOF to the six AAD and tagging
  instances. Test and Prod are untouched.
- Unresolved placeholders compile into the MOF without failing the build:
  `TenantId = "<TenantFQDN>"` 22 times and `<AutoGeneratedLater>` for one
  `ApplicationId` and one `CertificateThumbprint`. No test guards against this.
- The three `cAADRoleSetting.yml` files hardcode
  `ApplicationId: a86901b1-da9c-4abd-8f53-b90977ab9493`, an app ID from a
  foreign tenant. `cAADRoleSetting` is enacted in Test and Prod.
- `source/Datum.yml` protects the app secret with `PlainTextPassword:
  SomeSecret`, committed to the repo. `docs/temp/EncryptingSecrets.md` explains
  the certificate alternative but imports `lab/Helpers.psm1`, which does not
  exist; the real modules are `AzHelpers.psm1`, `CertHelpers.psm1` and
  `M365DscHelpers.psm1`.
- `lab/10 Setup App Registrations.ps1` prints the generated secret to the
  console, then commits and pushes `source/Global/Azure.yml` to `origin`.
  `source/Global/ProjectSettings.yml` holds a plaintext Azure DevOps PAT and a
  build-agent password.
- `Add-M365DscIdentityPermission` grants the permission set compiled from every
  Microsoft365DSC resource, adds `M365DscSetupApplication` to Global
  Administrator and assigns subscription Owner.
- 20 of the 23 M365 instances set `ManagedIdentity = True`, so enactment only
  authenticates on an Azure VM that carries the identity.
- `pipelines/push.yml` applies through `startDscTemplate` before
  `testDscTemplate` runs; `pipelines/test.yml` is the dry-run entry point.

### Carried over

- Decide the Microsoft365DSC direction: return to `1.26.x`, or keep `2.x` with a
  pipeline that tolerates `M365DSC.PSDesiredStateConfiguration`, a composite
  build made for 2.x and `source/` changes for 5 removed keys.
- Decide whether to move `DscConfig.Demo` forward to its preview release.
- Settle the Pester policy: 6.0.1 is resolved and 5.7.1 sits disabled as
  `_5.7.1` in `output/RequiredModules`.
- Re-verify the Azure DevOps pipelines and the `lab/` scripts against current
  Azure and Microsoft 365 APIs.
