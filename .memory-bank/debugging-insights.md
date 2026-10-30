---
status: current
last-verified: 2026-10-29
owner: software-engineer
source: current task evidence
---

# Debugging insights

Failures of this build that recur or mislead, with the cheapest check that
tells them apart. Newest first.

## The build "hangs" at `Reading DSC Resource metadata` with Microsoft365DSC 2.x

- Symptom: after `CompileDatumRsop` and `Set_PSModulePath` the console shows
  `Reading DSC Resource metadata for supporting CIM based DSC parameters...`
  and three progress bars (`Loading default CIM keywords`, `Getting module
  list`, `Creating resource list`) that do not change for an hour.
- It is not a hang. The process computes at 100% of one core with 2 to 5 GB of
  working set, and nothing completes the progress records, so the screen stays
  frozen. A clean run failed after 70 min: 48 min in
  `Initialize-DscResourceMetaInfo` and 21 min in the `Preloading available
  resources` call of the pipeline's `Scripts\CompileRootConfiguration.ps1`.
- Cause: Microsoft365DSC 2.x defines its 541 resources as PowerShell classes
  in 10 MB of `Classes\*.psm1`, and the engine caches nothing for them. Every
  `Import-DscResource -ModuleName Microsoft365DSC` parses all of it again, 3.4
  to 7.9 s per statement, with `-Name` and when repeated. Each of the 179
  DscConfig.M365 composites carries that statement (the 26 DscConfig.Demo
  composites import MOF-based modules instead), and an
  unfiltered `Get-DscResource` imports every composite (about 4 to 8 s each), so
  one pass takes about 21 min. `Initialize-DscResourceMetaInfo` also runs
  `Get-DscResourceProperty` (1.4 to 2.2 s, `ClearCache` each time) for each of
  roughly 1,400 resources. The project uses 8 of the 205 composites. With 1.x the
  MOF schemas are cached per file, and the whole build took 5.5 to 6 minutes.
- Measured: `Get-DscResource -Module Microsoft365DSC` alone takes 25 s (fork)
  or 30 s (2.0.8) and returns 1,066 resources, so the class-based module is not
  the cost, the repetition is. A full parse of the class files takes about 10 s.
- The engine's fast host is no way out: `FastHost.ps1` rejects modules with
  composite resources (`contains composite resources, which the fast host does
  not support yet`) and falls back to the standard path.
- Check in seconds, not an hour: time `Import-DscResource -ModuleName
  Microsoft365DSC` inside a `configuration` block with 2.0.8 loaded.
- Known good: Microsoft365DSC `1.26.909.1`, the last 1.x release, builds green
  in 6 min 5 s in a clean clone (21 tasks, 0 errors, 0 warnings, 170 and 12
  tests). Its dependency block differs from `1.26.729.2` only in `DSCParser`
  `3.1.0.3`, `MSCloudLoginAssistant` `1.2.4` and `ReverseDSC` `2.0.0.36`.
- Fixed in this repository on 2026-10-29 (Decision 28 in `systemPatterns.md`):
  the build no longer scans all resources, and `PrepareDscCompile` takes 33 to
  48 s. Its log tells whether the shortcut still works: `The nodes use N
  configurations, N of them are composite resources` and `Resource metadata: 4
  entries from 11 resources and types in 33 seconds`. If the step `Reading DSC
  Resource metadata` takes minutes again, DscBuildHelpers no longer reads the
  private table that the seeding fills; `PrepareDscCompile` then also warns
  about a newer DscBuildHelpers or Sampler.DscPipeline.

## `The term 'PSDesiredStateConfiguration PSDesiredStateConfiguration' is not recognized`

- Symptom: `CompileRootConfiguration` fails after the metadata steps. The stack
  names `Configuration` in
  `M365DSC.PSDesiredStateConfiguration\3.1.10\M365DSC.PSDesiredStateConfiguration.psm1`.
- Cause: two modules named `PSDesiredStateConfiguration` are loaded, 2.0.8 and
  the inner 3.1.10 module that `M365DSC.PSDesiredStateConfiguration` registers.
  `RootConfiguration.ps1` of Sampler.DscPipeline runs `& $module { ... }` on the
  `Get-Module -Name PSDesiredStateConfiguration` result, and PowerShell reads an
  array there as the command name `PSDesiredStateConfiguration
  PSDesiredStateConfiguration`.
- How both get loaded: nothing imports 2.0.8 before the first `Get-DscResource`
  call, which `Initialize-DscResourceMetaInfo` makes. With the build's
  `PSModulePath` that command resolves by module auto-loading to
  `M365DSC.PSDesiredStateConfiguration`. Module auto-loading takes the first
  module on the module path that exports the command: both engines export
  `Get-DscResource`, and in `output\RequiredModules` they share one folder where
  the fork's name sorts first. With the 2.0.8 folder first on the path, the
  command resolves to 2.0.8 (measured 2026-10-29). `Import-DscResource -ModuleName
  PSDesiredStateConfiguration` in the configuration then loads 2.0.8 as a second
  module. Importing 2.0.8 with `-Global` first leaves one module, and the fork
  never loads.
- Check in seconds, not 70 minutes: build a scratch folder of junctions to
  `DscBuildHelpers`, `xDSCResourceDesigner`, `PSDesiredStateConfiguration`,
  `M365DSC.PSDesiredStateConfiguration` and one small DSC module, set it as
  `PSModulePath` next to the Windows PowerShell path, import `DscBuildHelpers`,
  call `Initialize-DscResourceMetaInfo -ModulePath <folder>` and list the loaded
  `*DesiredState*` modules. Then define a `configuration` that imports
  `PSDesiredStateConfiguration` and calls `Get-Module -Name
  PSDesiredStateConfiguration`; it returns 2 and fails without the explicit
  import, and returns 1 and compiles with it.
- Microsoft365DSC 2.x adds that module to its dependency block. A full build
  takes over an hour to reach this failure, so reproduce in isolation.
- Fixed in this repository: `Initialize-StandardDscEngine`, called by
  `PrepareDscCompile`, removes the fork and imports the pinned 2.0.8 with
  `-Global`, and throws unless exactly one module of that name remains.

## Which modules the pack step zips with class-based modules

- The original `CompressModulesWithChecksum` lists every resource with
  `Get-DscResourceFromModuleInFolder`, an unfiltered `Get-DscResource`. That took
  24 min on 2026-10-29 with Microsoft365DSC 2.26.1021.1, to select 9 modules.
- `Get-DscResource` of PSDesiredStateConfiguration 2.0.8 considers a module when
  its `DscResources` folder (or `<version>\DscResources`) has content, or when its
  manifest has an uncommented line that mentions `DscResourcesToExport`. It
  imports class-based resources only when `Get-Module -ListAvailable` reports
  `ExportedDscResources.Count -gt 0`, and every folder under `DscResources` as a
  MOF-based or composite resource.
- In the current restore `ExportedDscResources` is non-zero only for
  Microsoft365DSC (541). JeaDsc 0.7.2 lists two resources in its manifest and
  still reports 0, so neither the original selection nor the override zips JeaDsc.
- `Get-ModuleWithDscResource` applies the same two rules without loading
  anything, and the task zips every version of a selected module name, as the
  original does. Both select the same 9 modules: ComputerManagementDsc,
  DscConfig.Demo, DscConfig.M365, FileSystemDsc, Microsoft365DSC, NetworkingDsc,
  SecurityPolicyDsc, WebAdministrationDsc and xPSDesiredStateConfiguration. A
  different list after a restore means a module gained or lost `DscResources`
  content or exports.

## Validating a build pipeline change

- Use a clean clone under `%TEMP%` with a copy of `output\RequiredModules`; the
  user's own `output\` is locked by their PowerShell session, and a copy is
  faster than the restore (about 110 s).
- `.\build.ps1 -Tasks pack` alone fails in `TestBuildAcceptance`, because only
  the `build` workflow runs `ConfigDataPreparation`, which fills the
  `<ProjectName>` placeholder. Validate `pack` through the default workflow.
- A task in `.build/` with the name of a pipeline task overrides it, and the
  functions of a `.build/*.ps1` file are visible to every task. Run builds
  detached with a log in `%TEMP%`, never in the foreground.

## 26 tests of `AzHelpers.Tests.ps1` report `should run but it did not`

- Symptom: `TestConfigData` fails with `Tests Passed: 140, Failed: 26`, or 166
  total with 26 failures in `IntegrationTestResults.xml`.
- Cause: `Import-Module` in the top-level `BeforeAll` throws `FileLoadException
  ... Assembly with same name is already loaded`. Seen twice: the build session
  already held `Az.Accounts` and `Az.Resources` (2026-08-17), and
  `output\RequiredModules` held two versions of `Microsoft.Graph.Authentication`
  because a Graph sub-module pin differed from the Authentication pin
  (2026-10-29).
- The real error is easy to lose. Pester 6.1.0 replaces it with `A 'break' or
  'continue' statement ... escaped from your code`, and Pester 5.7.1 reports it
  correctly. Run the failing `Import-Module` in a fresh `pwsh -NoProfile` with
  `output\RequiredModules` prepended to `PSModulePath`.
- Check: `output\RequiredModules\Microsoft.Graph.Authentication` must hold one
  version folder, and `tests/ConfigData/RequiredModules.Tests.ps1` must pass.

## A restore or delete of `output\` fails with `Access to the path ... is denied`

- Cause: the VS Code PowerShell console that ran an earlier build still has
  modules from `output\RequiredModules` loaded. A failed `Remove-Item -Recurse`
  has already removed files by then.
- Check: list `Get-Process` modules under `output\` per process, and restart the
  PowerShell session first. Verify a damaged module against its Gallery package
  before trusting it. A clean clone under `%TEMP%` avoids the lock.

## Checking configuration data against a new Microsoft365DSC schema

- `source/**/c*.yml` keys under `Items` are splatted onto the resource, so a key
  the new schema dropped only fails at compile time. DscBuildHelpers'
  `Get-DscResourceProperty` returns a resource's properties, `Values` and
  `TypeConstraint` in about 2 s, which lets a script compare every key, value
  and type up front.
- For all resources at once, parse the class files with the PowerShell AST
  (`Classes\*.psm1`, 8 s for 541 resources): the `DscProperty` members of each
  class with the `DscResource` attribute, without `NotConfigurable`, are the
  properties. Compared with the composite resources of DscConfig.M365 it gave
  the same removed and added properties as the generator for all 88 composites
  that the generator had written (`docs/upstream-changes-composite-drift.md`).
  Embedded types keep the `MSFT_` prefix in 2.26.1021.1, for example
  `MSFT_DefaultUserRolePermissions`.

## The M365DSC engine and PSDesiredStateConfiguration 2.0.8 in one session

- The M365DSC engine claims the module name `PSDesiredStateConfiguration` on
  purpose, with a compatibility module of its own (`Compat\...`, 3.1.10) that
  forwards `Configuration`, `Get-DscResource` and the other commands, and it
  claims the global function `PSDesiredStateConfiguration\Configuration`. That is
  why two modules of the name exist as soon as 2.0.8 is imported as well.
- `Get-Command Get-DscResource` resolves by module path order, not by version
  or manifest: 2.0.8 first on the path gives 2.0.8, the M365DSC folder first
  gives the M365DSC engine, and both in one folder, as Sampler restores them,
  gives the M365DSC engine because `M365DSC...` sorts before `PSDesired...`.
- Using the M365DSC engine as the only engine is no faster: three invocations of
  a configuration that imports `Microsoft365DSC` took 8.1, 5.7 and 5.2 s with it
  and 9.2, 7.0 and 4.7 s with 2.0.8, with the same MOF. `DscSchemaCache.json` in
  the module folder (3.8 MB, 1,066 keywords) did not change that.

## Running a Sampler task alone can write outside the repository

- The generator tasks of DscConfig.M365 use `$SourcePath` and `$ProjectName`
  without defining them. Run alone with `.\build.ps1 -Tasks <task>`, they wrote
  `\DSCResources.yml` and `\DSCResources\...` to the root of the current drive
  (`C:\`) and then failed on the empty `$ProjectName`. Make the task dot-source
  `. Set-SamplerTaskVariable -AsNewBuild`, or run the full workflow, and check
  the drive root afterwards. The generator against 2.x also needs more than 30
  minutes and grew to 11.9 GB for 89 of 176 composites; stop it by literal PID.

## ``Nullable`1`` and `Missing '=' operator` for an embedded property (DBH-4)

- Symptom: `CompileRootConfiguration` fails for a node whose data sets an
  embedded property of a 2.x resource, for example `DefaultUserRolePermissions`
  of `cAADAuthorizationPolicy`, with `An attribute name for resource
  'MSFT_DefaultUserRolePermissions' was found that is not valid` and `Missing
  '=' operator after key in property assignment`, raised from
  `Get-DscSplattedResource`.
- Cause: the 2.x embedded classes declare their properties as
  `System.Nullable[System.Boolean]`. `Write-CimPropertyValue` of DscBuildHelpers
  compares `PropertyType.FullName` with the standard types without unwrapping
  `Nullable`, so it treats each property as an embedded instance and writes
  ``AllowedToCreateApps = Nullable`1 { }``. Call `Get-DscSplattedResource`
  alone with the resource, the properties and the values to see the generated
  block before the compile parses it.
- Fix and proof: `[System.Nullable]::GetUnderlyingType($property.PropertyType)`
  in `Write-CimPropertyValue`. Applied to a copy of the installed module and
  junctioned into a scratch clone, it let the 3 nodes compile, and the MOFs
  contain `instance of MSFT_DefaultUserRolePermissions` with the three values
  (`docs/upstream-changes.md`, DBH-4). The real tree does not set the property
  yet, because the 1.x composite resources do not have it.
