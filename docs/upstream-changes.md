# Upstream changes

This project compiles Microsoft365DSC 2.x with a build pipeline that was written
for MOF-based resources. Until the dependencies change, the project carries
workarounds. This register lists every change that the dependencies need, in
the repository that owns it, so that each change can be proposed there and the
workaround deleted afterwards.

## How to use this register

- Every entry has an ID such as `SDP-1`. The prefix names the repository.
- A workaround in this repository carries the comment `UPSTREAM: <ID>`. List
  them with:

  ```powershell
  Get-ChildItem -Path .build, source, tests, lab -Recurse -File |
      Select-String -Pattern 'UPSTREAM:'
  Select-String -Path build.yaml, RequiredModules.psd1 -Pattern 'UPSTREAM:'
  ```

- The test `tests/ConfigData/UpstreamChanges.Tests.ps1` fails when a marker
  names an ID that this file does not define, when an entry names a workaround
  that no marker carries, and when the workaround line names a file that does
  not exist. It keeps the register and the code from drifting apart.
- An entry is *required* when the build fails or takes hours without a
  workaround, and *optional* when it improves speed or robustness.
- Each entry has the line `Local workaround`. It names the files that can be
  deleted once the change is released, or says `none`.

## Baseline

The workarounds were written for these versions. `PrepareDscCompile` warns when
`Sampler.DscPipeline` or `DscBuildHelpers` is newer, because the project then
shadows code that has changed.

| Module | Version | Repository | State on 2026-10-29 |
|---|---|---|---|
| Sampler.DscPipeline | 0.3.0 | [SynEdgy/Sampler.DscPipeline](https://github.com/SynEdgy/Sampler.DscPipeline) | `main` at 2ded4e7 (2026-02-03). The four files named in SDP-1 to SDP-4 are identical to 0.3.0. |
| DscBuildHelpers | 0.4.0-preview0001 | [gaelcolas/DscBuildHelpers](https://github.com/gaelcolas/DscBuildHelpers) | `main` at 84eb1b6 (2026-03-07). The files named in DBH-1 to DBH-4 are identical to the release. |
| DscConfig.M365 | 0.8.0-preview0001 | [raandree/DscConfig.M365](https://github.com/raandree/DscConfig.M365) | `main` at 6256025 (2026-10-29). Generates for Microsoft365DSC 1.26.819.1. The manifest names `dsccommunity/DscConfig.M365`, which does not exist (404). |
| Microsoft365DSC | 2.26.1021.1 | [microsoft365dsc/Microsoft365DSC](https://github.com/microsoft365dsc/Microsoft365DSC) | Class-based. 541 resources and 525 embedded types in 26 class files of 10.1 MB. |
| M365DSC.PSDesiredStateConfiguration | 3.1.10 | [Microsoft365DSC/PSDesiredStateConfiguration](https://github.com/Microsoft365DSC/PSDesiredStateConfiguration) | A second DSC engine that Microsoft365DSC 2.x requires. Default branch `dev` at eede99f (2026-10-09). |
| PSDesiredStateConfiguration | 2.0.8 | [PowerShell/PSDesiredStateConfiguration](https://github.com/PowerShell/PSDesiredStateConfiguration) | The engine that the build pins. |

## Summary

| ID | Repository | Change | Needed |
|---|---|---|---|
| SDP-1 | Sampler.DscPipeline | Resolve the used composite resources without `Get-DscResource` | required |
| SDP-2 | Sampler.DscPipeline | Initialize the resource metadata for the used resources only | required |
| SDP-3 | Sampler.DscPipeline | Select the modules to compress without listing every resource | required |
| SDP-4 | Sampler.DscPipeline | Import one DSC engine first and expect exactly one | required |
| DBH-1 | DscBuildHelpers | Add a resource filter to `Initialize-DscResourceMetaInfo` | required |
| DBH-2 | DscBuildHelpers | Keep the DSC class cache between property lookups | optional |
| DBH-3 | DscBuildHelpers | Use the parameter in `Get-CimType` | optional (bug) |
| DBH-4 | DscBuildHelpers | Treat nullable value types of embedded class-based types as standard types | required for embedded properties |
| DC365-1 | DscConfig.M365 | Generate the composite resources for Microsoft365DSC 2.x and release them | required |
| DC365-2 | DscConfig.M365 | Make the generator tasks safe to run alone | optional |
| DC365-3 | DscConfig.M365 | Reduce the cost of the generator with class-based modules | optional |
| M365PSDSC-1 | M365DSC.PSDesiredStateConfiguration | Document or soften the claim of the module name | optional (alternative to SDP-4) |
| M365PSDSC-2 | M365DSC.PSDesiredStateConfiguration | Cache imported class-based keywords for the session | optional |
| M365PSDSC-3 | M365DSC.PSDesiredStateConfiguration | Support composite resources in the fast host | optional |

## Why the build needs them

Microsoft365DSC 2.x defines its resources as PowerShell classes. The DSC engine
caches nothing for them, so every `Import-DscResource -ModuleName
Microsoft365DSC` parses the 10.1 MB of classes again. It costs 3.4 to 7.9
seconds per statement in isolated sessions, with or without `-Name`, and a
repetition is not cheaper. Each of the 179 composite resources of DscConfig.M365
carries such a statement. The 26 composite resources of DscConfig.Demo import
MOF-based modules instead. With the MOF schemas of Microsoft365DSC 1.x the whole
build took 5.5 to 6 minutes, because the engine caches MOF schemas per file.

The unchanged pipeline touches every resource of every module more than once.
A clean run of `.\build.ps1` with Microsoft365DSC 2.26.1021.1 spent about 48
minutes in `Initialize-DscResourceMetaInfo` and another 21 minutes in the
preload of `CompileRootConfiguration.ps1`, then failed after 1 h 10 min with
`The term 'PSDesiredStateConfiguration PSDesiredStateConfiguration' is not
recognized`. With the workarounds of this project the default workflow
(`build` and `pack`) takes 6 min 32 s to 7 min 54 s.

Sampler.DscPipeline, DscBuildHelpers and DscConfig.M365 form one chain: the
generator of DscConfig.M365 writes the composite resources, DscBuildHelpers
turns their properties into DSC resource blocks, and Sampler.DscPipeline
compiles the MOF files. A change in one of them often needs a change in the
next, which is why the entries refer to each other.

## Sampler.DscPipeline

### SDP-1: Resolve the used composite resources without Get-DscResource

- **Repository:** [SynEdgy/Sampler.DscPipeline](https://github.com/SynEdgy/Sampler.DscPipeline)
- **Needed:** required
- **Where:** `source/Scripts/CompileRootConfiguration.ps1` line 73,
  `$availableResources = Get-DscResource`, under "Preloading available
  resources".
- **Problem:** The script needs, for each configuration that a node uses, the
  module name and version, to write `Import-DscResource -ModuleName <module>
  -ModuleVersion <version> -Name <name>`. It gets them from an unfiltered
  `Get-DscResource`. In PSDesiredStateConfiguration 2.0.8 that cmdlet imports
  every DSC resource of every module on the module path before it filters: its
  `begin` block loops over all modules that `Get-DSCResourceModules` returns,
  imports the class-based resources of each, and imports every folder below
  `DscResources` as a keyword, which runs the schema file of each composite
  resource. `-Name` does not narrow that, `-Module` narrows it to one module.
  See the cost described under "Why the build needs them".
- **Evidence:** 21 minutes for this step in the clean build of 2026-10-29. With
  the replacement the used composite resources are found in 0.3 seconds.
- **Proposed change:** Look the used configurations up by the folder layout of
  the module path, without loading a module. A composite resource is the folder
  `DscResources\<name>` that holds `<name>.schema.psm1`, in
  `<module>\<version>`. Return the same properties that the loop below uses
  (`Name`, `ModuleName`, `Version`). Fall back to `Get-DscResource -Name` only
  for names that the lookup does not find, for example MOF-based or
  class-based resources that a node configures directly.
- **Reference implementation:** `Resolve-DscCompositeResource` in
  `.build/DscCompileHelpers.ps1`, used by `source/CompileRootConfiguration.ps1`.
  Validated by the default workflow in a clean clone and in the working tree.
- **Tests to add:** Sampler.DscPipeline tests public functions only
  (`tests/Integration/Public`). Put the lookup in a public function, or in
  DscBuildHelpers next to `Get-ModuleFromFolder`, and test it on a fake module
  tree: a composite is found by name, two versions give two results, a folder
  without a schema file is ignored, an unknown name gives nothing. This
  project's `tests/ConfigData/DscCompile.Tests.ps1` has these cases.
- **Issue title:** `CompileRootConfiguration.ps1` runs `Get-DscResource`
  without a filter, which takes 21 minutes with class-based modules
- **Local workaround:** `source/CompileRootConfiguration.ps1` together with the
  verbatim copy `source/RootConfiguration.ps1` (the pipeline uses the first
  only when the second exists), and `Resolve-DscCompositeResource` in
  `.build/DscCompileHelpers.ps1`
- **Remove when:** a Sampler.DscPipeline release contains the lookup. Delete
  the two files in `source/`.
- **Status:** not filed. No matching issue found on 2026-10-29 (issues 43 and
  52 of the repository are closed and unrelated).

### SDP-2: Initialize the resource metadata for the used resources only

- **Repository:** [SynEdgy/Sampler.DscPipeline](https://github.com/SynEdgy/Sampler.DscPipeline)
- **Needed:** required, together with DBH-1
- **Where:** `source/Tasks/CompileRootConfiguration.build.ps1` line 52,
  `Initialize-DscResourceMetaInfo -ModulePath $RequiredModulesDirectory`.
- **Problem:** The call reads every resource of every module in
  `output\RequiredModules`. It runs `Get-DscResourceFromModuleInFolder` (an
  unfiltered `Get-DscResource`) and then `Get-DscResourceProperty` for every
  resource and embedded type, about 1,400 calls of 1.4 to 2.2 seconds each with
  Microsoft365DSC 2.x. The compile of this project needs 4 table entries from
  11 resources and embedded types.
- **Evidence:** about 48 minutes in the clean build of 2026-10-29. The split
  into roughly 24 minutes for the unfiltered `Get-DscResource` and 25 for the
  property lookups is an estimate. The replacement needs 34.5 to 47.6 seconds.
- **Proposed change:** Read the used configurations from the RSOP cache, which
  the task can reach with `Get-DatumRsopCache`, resolve them as in SDP-1, name
  the resources that they wrap, and pass those names to the filtered
  initialization of DBH-1. Skip the call when no composite resource is used.
- **Reference implementation:** `PrepareDscCompile` in
  `.build/DscCompileTasks.ps1`.
- **Issue title:** `Initialize-DscResourceMetaInfo` runs over every module of
  `output\RequiredModules`, which takes 48 minutes with class-based modules
- **Local workaround:** `PrepareDscCompile` in `.build/DscCompileTasks.ps1`
  (listed in `build.yaml` between `TestDscResources` and
  `CompileRootConfiguration`) and `Initialize-DscResourceMetaInfoForComposite`
  in `.build/DscCompileHelpers.ps1`
- **Remove when:** Sampler.DscPipeline passes the used resources itself.
- **Status:** not filed.

### SDP-3: Select the modules to compress without listing every resource

- **Repository:** [SynEdgy/Sampler.DscPipeline](https://github.com/SynEdgy/Sampler.DscPipeline)
- **Needed:** required (the step works, but takes 24 minutes)
- **Where:** `source/Tasks/CompressModulesWithChecksum.build.ps1` line 67,
  `Get-DscResourceFromModuleInFolder -ModuleFolder ... -Modules $allModules`.
- **Problem:** The task zips the modules that contain DSC resources and finds
  them by listing every DSC resource of every module, which is an unfiltered
  `Get-DscResource` again.
- **Evidence:** 24.3 minutes for the original selection in a separate run on
  2026-10-29, which selected 9 of 64 module entries (it ran next to other
  builds). The replacement needs 2.3 to 2.5 seconds and selects the same 9:
  ComputerManagementDsc, DscConfig.Demo, DscConfig.M365, FileSystemDsc,
  Microsoft365DSC, NetworkingDsc, SecurityPolicyDsc, WebAdministrationDsc and
  xPSDesiredStateConfiguration, with the same archive names.
- **Proposed change:** Apply the rule by which PSDesiredStateConfiguration
  2.0.8 yields resources, without loading them: a module has DSC resources when
  `Get-Module -ListAvailable` reports exported resources for it (class-based),
  or when its `DscResources` folder contains a resource folder (MOF-based and
  composite). Keep every version of a selected module name, as the original
  does. A manifest that lists `DscResourcesToExport` is not enough: JeaDsc
  0.7.2 lists two resources and the engine reports none, so neither the
  original nor the replacement selects it.
- **Reference implementation:** `Get-ModuleWithDscResource` in
  `.build/DscCompileHelpers.ps1`, used by the override in
  `.build/DscCompileTasks.ps1`.
- **Issue title:** `CompressModulesWithChecksum` lists every DSC resource to
  select modules, which takes 24 minutes with class-based modules
- **Local workaround:** the task `CompressModulesWithChecksum` in
  `.build/DscCompileTasks.ps1` and `Get-ModuleWithDscResource` in
  `.build/DscCompileHelpers.ps1`
- **Remove when:** a Sampler.DscPipeline release contains the selection. Then
  the `.build` task of the same name must go, because it overrides the
  pipeline's task.
- **Status:** not filed.

### SDP-4: Import one DSC engine first and expect exactly one

- **Repository:** [SynEdgy/Sampler.DscPipeline](https://github.com/SynEdgy/Sampler.DscPipeline)
- **Needed:** required, unless M365PSDSC-1 removes the cause
- **Where:** `source/Tasks/CompileRootConfiguration.build.ps1` before line 52,
  and `source/Scripts/RootConfiguration.ps1` line 11,
  `$module = Get-Module -Name PSDesiredStateConfiguration`, followed by
  `& $module { ... }`.
- **Problem:** Microsoft365DSC 2.x requires M365DSC.PSDesiredStateConfiguration,
  which claims the module name `PSDesiredStateConfiguration` on purpose (see
  M365PSDSC-1). Nothing in the pipeline imports `PSDesiredStateConfiguration`
  before the first `Get-DscResource`. Module auto-loading takes the first
  module on the module path that exports the command. Both engines export it,
  and in `output\RequiredModules` they share one folder, where the name
  `M365DSC.PSDesiredStateConfiguration` sorts first. The M365DSC engine is
  loaded. Later `Import-DscResource -ModuleName PSDesiredStateConfiguration`
  loads 2.0.8 as a second module. `Get-Module -Name PSDesiredStateConfiguration`
  then returns an array, `& $module { ... }` becomes a call of the command named
  `PSDesiredStateConfiguration PSDesiredStateConfiguration`, and the compile
  fails after the long metadata steps.
- **Evidence:** reproduced in seconds in a scratch folder with the two engines.
  Importing 2.0.8 with `-Global` first leaves one module, and the M365DSC
  engine never loads. Which engine `Get-Command Get-DscResource` resolves to
  depends on the order of the module path, not on the version: with the folder
  of 2.0.8 first it resolves to 2.0.8, with the folder of the M365DSC engine
  first it resolves to the M365DSC engine, and with both in one folder it
  resolves to the M365DSC engine (measured on 2026-10-29).
- **Proposed change:** In the task, before anything calls `Get-DscResource`,
  run `Import-Module -Name PSDesiredStateConfiguration -Global`, with the
  version of the `DscCompositeResourceModules` entry in `build.yaml` when it
  names one. In `RootConfiguration.ps1`, replace the single-module assumption
  by a check that throws a readable message unless exactly one module of that
  name is loaded. This is the diff against `main` (2ded4e7) without the
  version handling:

  ```diff
  --- a/source/Tasks/CompileRootConfiguration.build.ps1
  +++ b/source/Tasks/CompileRootConfiguration.build.ps1
  @@ -48,6 +48,11 @@ task CompileRootConfiguration {
       $RequiredModulesDirectory = Get-SamplerAbsolutePath -Path $RequiredModulesDirectory -RelativeTo $OutputDirectory

       $previousPSModulePath = $env:PSModulePath
  +    # Import the DSC engine before anything calls Get-DscResource. Module auto-loading otherwise takes the first module on the
  +    # module path that exports it, which can be the engine of Microsoft365DSC 2.x, and the session ends up with two modules
  +    # named PSDesiredStateConfiguration.
  +    Import-Module -Name PSDesiredStateConfiguration -Global
  +
       Write-Build DarkGray 'Reading DSC Resource metadata for supporting CIM based DSC parameters...'
       Initialize-DscResourceMetaInfo -ModulePath $RequiredModulesDirectory
       Write-Build DarkGray 'Done'
  --- a/source/Scripts/RootConfiguration.ps1
  +++ b/source/Scripts/RootConfiguration.ps1
  @@ -8,7 +8,13 @@ configuration RootConfiguration
       #Compiling MOF from RSOP cache
       $rsopCache = Get-DatumRsopCache

  -    $module = Get-Module -Name PSDesiredStateConfiguration
  +    $loadedModule = @(Get-Module -Name PSDesiredStateConfiguration)
  +    if ($loadedModule.Count -ne 1)
  +    {
  +        throw "Expected exactly one loaded module named 'PSDesiredStateConfiguration' but found $($loadedModule.Count): $(($loadedModule | ForEach-Object -Process { "$($_.Name) $($_.Version)" }) -join ', '). Import the DSC engine of the build before the compilation."
  +    }
  +
  +    $module = $loadedModule[0]
       & $module {
           param (
               [string]$BuildVersion,
  ```
- **Not a way out:** using the M365DSC engine as the only engine. Measured on
  2026-10-29 in sessions with one engine each, with the other one off the
  module path, `Import-DscResource -ModuleName Microsoft365DSC` costs the same
  with both: 9.2, 7.0 and 4.7 seconds for three consecutive invocations with
  2.0.8, and 8.1, 5.7 and 5.2 seconds with the M365DSC engine, which writes the
  same MOF. The run had another job on the CPU, so compare the two series, not
  the single values.
- **Reference implementation:** `Initialize-StandardDscEngine` in
  `.build/DscCompileHelpers.ps1`. It also removes an already loaded M365DSC
  engine and reads the version from `RequiredModules.psd1`.
- **Issue title:** `RootConfiguration.ps1` fails when two modules named
  PSDesiredStateConfiguration are loaded (Microsoft365DSC 2.x)
- **Local workaround:** `Initialize-StandardDscEngine` in
  `.build/DscCompileHelpers.ps1`, called by `PrepareDscCompile` in
  `.build/DscCompileTasks.ps1`
- **Remove when:** the pipeline imports the engine itself.
- **Status:** not filed.

## DscBuildHelpers

### DBH-1: Add a resource filter to Initialize-DscResourceMetaInfo

- **Repository:** [gaelcolas/DscBuildHelpers](https://github.com/gaelcolas/DscBuildHelpers)
- **Needed:** required, together with SDP-2
- **Where:** `source/Public/Initialize-DscResourceMetaInfo.ps1`. Its result is
  read from the module variables `allDscResourcePropertiesTable`,
  `allDscSchemaClasses` and `standardCimTypes` by `Get-CimType`,
  `Get-DscCimInstanceReference` and `Write-CimPropertyValue`.
- **Problem:** The function cannot be limited to the resources a build uses.
  The only way to avoid the scan is to write its private variables from
  outside, as this project does, which breaks with any internal change.
- **Proposed change:** Add `-ResourceName <string[]>`. For each name, find the
  module in the result of `Get-ModuleFromFolder` without `Get-DscResource`
  (class-based: `ExportedDscResources`; MOF-based and composite: the folders of
  `DscResources`), read the properties with `Get-DscResourceProperty`, follow
  every property whose type constraint is not a standard CIM type into its
  embedded type, import the `schema.mof` classes of MOF-based resources as
  today, and merge into the existing table instead of replacing it.
- **How the caller knows the wrapped resource:** Option A, used by the
  reference implementation: read `$dscResourceName = '<resource>'` from the
  schema file of the composite resource, which is the convention of the
  DscConfig.M365 generator (see DC365-1). Option B, an idea that nobody has
  prototyped: let `Get-DscSplattedResource` fill the entries of a resource the
  first time it sees it. The composite resource has imported the keyword by
  then, and no pre-pass and no knowledge of composite internals is needed.
- **Limits of the reference implementation:** it supports class-based resources
  only, because it leaves `allDscSchemaClasses` empty. It depends on the
  generator convention. It writes three private variables of DscBuildHelpers
  0.4.0. A composite resource without `$dscResourceName` gets a warning and no
  metadata.
- **Tests to add:** in
  `tests/Integration/Initialize-DscResourceMetaInfo.Integration.Tests.ps1`,
  which has the `ClassBased` and `MofBased` assets. A filtered call must return
  the entries that the full call returns for the named resources. For the two
  test modules the full call gives 11 properties, 11 table entries and 9 schema
  classes.
- **Issue title:** `Initialize-DscResourceMetaInfo` needs a resource filter
- **Local workaround:** `Initialize-DscResourceMetaInfoForComposite` and
  `Get-DscCompositeResourceDetail` in `.build/DscCompileHelpers.ps1`
- **Remove when:** a DscBuildHelpers release has the filter and SDP-2 uses it.
- **Status:** not filed. No matching issue found on 2026-10-29.

### DBH-2: Keep the DSC class cache between property lookups

- **Repository:** [gaelcolas/DscBuildHelpers](https://github.com/gaelcolas/DscBuildHelpers)
- **Needed:** optional
- **Where:** `source/Private/Get-DscResourceProperty.ps1`. Every call runs
  `DscClassCache::ClearCache()` and `LoadDefaultCimKeywords`, then imports the
  resource with `ImportCimKeywordsFromModule` or
  `ImportClassResourcesFromModule`.
- **Evidence:** 1.4 to 1.9 seconds per call with Microsoft365DSC 2.x in an
  isolated session (7.4 seconds for the first call, 12 resources, up to 302
  properties, memory flat at about 800 MB), and 1.4 to 2.2 seconds in the
  build. The full initialization makes about 1,400 calls, and the generator
  of DscConfig.M365 makes one per composite resource (DC365-3). Whether the
  cache clearing is what makes each call cost that much is not measured.
- **Idea:** Do not clear the cache when the next lookup is in the same module
  and version, and prove with a test that two modules with the same resource
  name still resolve to the right one. Not prototyped.
- **Local workaround:** none
- **Status:** not filed.

### DBH-3: Use the parameter in Get-CimType

- **Repository:** [gaelcolas/DscBuildHelpers](https://github.com/gaelcolas/DscBuildHelpers)
- **Needed:** optional (bug, not triggered by the build)
- **Where:** `source/Private/Get-CimType.ps1` line 42,
  `$allDscResourcePropertiesTable."$ResourceName-$PropertyName"`. The parameter
  of the function is `$DscResourceName`.
- **Problem:** `$ResourceName` is not defined in the function. It works only
  because the single caller, `Get-DscSplattedResource`, has a variable of that
  name and dynamic scoping exposes it.
- **Proposed change:** Use `$DscResourceName`. Test it with `InModuleScope`,
  calling `Get-CimType` from a scope that has no `$ResourceName`. The diff
  against `main` (84eb1b6):

  ```diff
  --- a/source/Private/Get-CimType.ps1
  +++ b/source/Private/Get-CimType.ps1
  @@ -39,7 +39,7 @@ function Get-CimType
           $PropertyName
       )

  -    $cimType = $allDscResourcePropertiesTable."$ResourceName-$PropertyName"
  +    $cimType = $allDscResourcePropertiesTable."$DscResourceName-$PropertyName"

       if ($null -eq $cimType)
       {
  ```
- **Local workaround:** none
- **Status:** not filed. Found by reading the code on 2026-10-29.

### DBH-4: Treat nullable value types of embedded class-based types as standard types

- **Repository:** [gaelcolas/DscBuildHelpers](https://github.com/gaelcolas/DscBuildHelpers)
- **Needed:** required to set an embedded property of a Microsoft365DSC 2.x
  resource, for example `DefaultUserRolePermissions` (DC365-1). The current
  build sets none.
- **Where:** `source/Private/Write-CimPropertyValue.ps1` line 105,
  `$property.PropertyType.FullName -notin $script:standardCimTypes.DotNetType
  -and $property.PropertyType.BaseType -ne [System.Enum]`.
- **Problem:** The embedded classes of Microsoft365DSC 2.x declare their
  properties as nullable value types, for example
  `MSFT_DefaultUserRolePermissions.AllowedToCreateApps` is
  `System.Nullable[System.Boolean]`. The name of that type is not in
  `standardCimTypes.DotNetType`, so the function takes the property for an
  embedded instance of its own and writes ``AllowedToCreateApps = Nullable`1``
  with an empty block. The generated resource block does not parse. The compile
  of the node fails with `An attribute name for resource
  'MSFT_DefaultUserRolePermissions' was found that is not valid` and `Missing
  '=' operator after key in property assignment`, raised from
  `Get-DscSplattedResource`.
- **Evidence:** reproduced on 2026-10-29 in a scratch build with regenerated
  composite resources (DC365-1) and the three settings of
  `cAADAuthorizationPolicy` written as `DefaultUserRolePermissions`. In
  isolation, `Get-DscSplattedResource` generated this block for the embedded
  type, and with the change below it generates one assignment per property:

  ```text
  DefaultUserRolePermissions = MSFT_DefaultUserRolePermissions
  {
  AllowedToCreateApps = Nullable`1
  {
  }
  AllowedToCreateSecurityGroups = Nullable`1
  {
  }
  AllowedToReadOtherUsers = Nullable`1
  {
  }
  }
  ```

  ```text
  DefaultUserRolePermissions = MSFT_DefaultUserRolePermissions
  {
  AllowedToCreateApps = $Parameters['DefaultUserRolePermissions']['AllowedToCreateApps']
  AllowedToCreateSecurityGroups = $Parameters['DefaultUserRolePermissions']['AllowedToCreateSecurityGroups']
  AllowedToReadOtherUsers = $Parameters['DefaultUserRolePermissions']['AllowedToReadOtherUsers']
  }
  ```

  With the change applied to a copy of the installed module, the `build`
  workflow of the scratch clone succeeded (`Build succeeded. 16 tasks, 0
  errors, 0 warnings 00:06:47`, `CompileRootConfiguration` 4 min 52 s). It
  compiled 3 MOF and 3 meta MOF files. The MOF of each of the three nodes
  contains this embedded instance, and `AADAuthorizationPolicy` references it
  with `DefaultUserRolePermissions = $MSFT_DefaultUserRolePermissions1ref;`:

  ```text
  instance of MSFT_DefaultUserRolePermissions as $MSFT_DefaultUserRolePermissions1ref
  {
  AllowedToCreateApps = True;
   AllowedToReadOtherUsers = True;
   AllowedToCreateSecurityGroups = True;

  };
  ```

  The scratch clone used the regenerated composite resources of DC365-1 and
  set the three keys under `DefaultUserRolePermissions`. The LCM has not
  applied this MOF, so how it handles the embedded class is not verified.
- **Proposed change:** Unwrap the nullable type before the comparison. The
  diff against `main` (84eb1b6):

  ```diff
  --- a/source/Private/Write-CimPropertyValue.ps1
  +++ b/source/Private/Write-CimPropertyValue.ps1
  @@ -102,7 +102,14 @@ function Write-CimPropertyValue
           }
           else
           {
  -            $property.PropertyType.FullName -notin $script:standardCimTypes.DotNetType -and $property.PropertyType.BaseType -ne [System.Enum]
  +            # A nullable value type, such as [System.Nullable[System.Boolean]], is the standard type that it wraps.
  +            $propertyType = [System.Nullable]::GetUnderlyingType($property.PropertyType)
  +            if ($null -eq $propertyType)
  +            {
  +                $propertyType = $property.PropertyType
  +            }
  +
  +            $propertyType.FullName -notin $script:standardCimTypes.DotNetType -and $propertyType.BaseType -ne [System.Enum]
           }

           $pathValue = Get-PropertiesData -Path ($Path + $property.Name)
  ```

- **Tests to add:** The `ClassBased` asset
  `tests/Integration/Assets/DscResources/ClassBased/0.1.0/ClassBased.psm1` has
  embedded classes (`CustomObject1`, `CustomObject2`) but no nullable
  property. Add a `[Nullable[bool]]` and a `[Nullable[int]]` property to one of
  them, a matching hashtable to the configuration asset, and let
  `Get-DscSplattedResource.Integration.Tests.ps1` compile it.
- **Issue title:** `Write-CimPropertyValue` writes an empty block for nullable
  properties of embedded class-based types
- **Local workaround:** none
- **Status:** not filed. No matching issue found on 2026-10-29.

## DscConfig.M365

### DC365-1: Generate the composite resources for Microsoft365DSC 2.x and release them

- **Repository:** [raandree/DscConfig.M365](https://github.com/raandree/DscConfig.M365)
- **Needed:** required
- **Where:** `RequiredModules.psd1` pins `Microsoft365DSC = '1.26.819.1'`, and
  the generator tasks `.build/CreateDscResourceYamlFile.ps1` and
  `.build/CreateDscCompositeResources.ps1` write `source/DSCResources` from it.
  Release 0.8.0-preview0001 contains the result for 1.26.819.1.
- **Problem:** The composite resources of a scalar (single instance) resource
  declare one parameter for each property of the resource, so they break when
  the resource changes. The composite resources of an array resource take
  `Items` and only show the change in the syntax comment and in the injection
  of `Ensure`. Microsoft365DSC 2.26.1021.1 changed many resources.
- **Evidence:** compared with the classes of 2.26.1021.1 on 2026-10-29 (method
  and complete lists in
  [upstream-changes-composite-drift.md](upstream-changes-composite-drift.md)):
  of the 179 composite resources of 0.8.0-preview0001, 111 are unchanged, 64
  changed and 4 wrap a resource that 2.x does not have. The resource list of
  the generator for 2.x has 176 entries and one new composite resource. 22 of
  the 64 lose properties, 7 scalar and 15 array composite resources. Four
  scalar ones lose `Ensure`: `cAADSecurityDefaults`,
  `cSPOAccessControlSettings`, `cSPOSharingSettings` and `cSPOTenantSettings`.
  42 only gain properties. Four composite resources that this project's nodes
  use changed: `cAADAuthorizationPolicy` loses five properties and gains
  `DefaultUserRolePermissions` and `EnabledPreviewFeatures`,
  `cAADSecurityDefaults` loses `Ensure`, `cAADGroup` and `cAADTenantDetails`
  only gain properties. Of this project's configuration data exactly five keys
  named removed properties: three on `cAADAuthorizationPolicy` and `Ensure` on
  two SharePoint layers.
- **Proposed change:** Pin `Microsoft365DSC` to the 2.x release in
  `RequiredModules.psd1`, run the generator, review the changes of the
  composite resources, update the test assets in
  `tests/Unit/DSCResources/Assets/Config` that name removed properties or
  resources (four assets have no resource any more), run the unit tests and
  release. The generator wrote 89 composite resources against 2.26.1021.1
  without an error before I stopped it (see DC365-3), and all parameter types
  of those are plain PowerShell types (`string`, `bool`, `pscredential`,
  `string[]`, `hashtable[]`, `hashtable`, `System.UInt32`, `int`). The
  embedded type `MSFT_DefaultUserRolePermissions` of `cAADAuthorizationPolicy`
  became a `hashtable` parameter.
- **Tests and CI (read on 2026-10-30):** The unit test
  `tests/Unit/DSCResources/DscResources.Tests.ps1` calls
  `Initialize-DscResourceMetaInfo -ModulePath $RequiredModulesDirectory` in
  `BeforeDiscovery`. With Microsoft365DSC 2.x that is the step that took about
  48 minutes in this project, so the tests of 2.x need DBH-1 and must pass the
  names of the wrapped resources. The assets in
  `tests/Unit/DSCResources/Assets/Config` select the generated set (185 files);
  `cIntuneDeviceCleanupRule` needs a new one. The Azure Pipelines test jobs run
  under Windows PowerShell 5.1 and PowerShell 7, and the Build job sets no
  timeout. Whether the 2.x composite resources compile under Windows
  PowerShell 5.1 is not verified. The manifest names
  `dsccommunity/DscConfig.M365`, which does not exist.
- **Effect on this project:** After the release, and after DBH-4, restore the
  three settings of `cAADAuthorizationPolicy` as the new embedded property:

  ```yaml
  DefaultUserRolePermissions:
    AllowedToCreateApps: true
    AllowedToCreateSecurityGroups: true
    AllowedToReadOtherUsers: true
  ```

  The embedded class is `MSFT_DefaultUserRolePermissions` in 2.26.1021.1. Set
  `Ensure` in the two SharePoint layers only where the regenerated composite
  still has it. Until then the tenant policy does not assert those three
  settings. A scratch build with the regenerated composite resources, these
  keys and the change of DBH-4 compiled all three nodes.
- **Issue title:** Generate the composite resources for Microsoft365DSC 2.x
- **Local workaround:**
  `source/1-AllTenantsConfig/AzureAd/cAADAuthorizationPolicy.yml`,
  `source/1-AllTenantsConfig/SharePoint/cSPOTenantSettings.yml` and
  `source/1-AllTenantsConfig/SharePoint/cSPOAccessControlSettings.yml` (the
  keys are commented out)
- **Remove when:** a DscConfig.M365 release is generated for 2.x, DBH-4 is
  released, and this project uses both.
- **Status:** not filed. The changelog of `main` has no entry for 2.x on
  2026-10-29.

### DC365-2: Make the generator tasks safe to run alone

- **Repository:** [raandree/DscConfig.M365](https://github.com/raandree/DscConfig.M365)
- **Needed:** optional
- **Where:** `.build/CreateDscResourceYamlFile.ps1` and
  `.build/CreateDscCompositeResources.ps1` use `$SourcePath` and `$ProjectName`
  without defining them. Variables of earlier Sampler tasks are expected to
  provide them.
- **Problem:** `.\build.ps1 -Tasks Create_Dsc_Resource_Yaml_File,
  Create_Dsc_Composite_Resources` alone wrote `DSCResources.yml` and a
  `DSCResources` folder to the root of the current drive, and then failed with
  `Cannot bind argument to parameter 'CompositeResourceModuleName' because it
  is an empty string`. It was observed on 2026-10-29 and cleaned up by hand.
- **Proposed change:** Start both tasks with
  `. Set-SamplerTaskVariable -AsNewBuild`. This was used in the experiment and
  the generation then ran. The manifest `ProjectUri` should name the
  repository that exists.
- **Local workaround:** none
- **Status:** not filed.

### DC365-3: Reduce the cost of the generator with class-based modules

- **Repository:** [raandree/DscConfig.M365](https://github.com/raandree/DscConfig.M365)
- **Needed:** optional (a practical obstacle to DC365-1)
- **Where:** `New-DscCompositeResourceCode` in
  `.build/CreateDscCompositeResources.ps1`. For every composite resource it
  runs `Get-Module -Name <module> -ListAvailable` and
  `Get-DscResourceProperty`.
- **Evidence:** the generator against Microsoft365DSC 2.26.1021.1 on a 16 GB
  machine wrote 89 of 176 composite resources in 31 minutes. It needed about
  10 seconds per composite resource at first and about 50 seconds later, wrote
  nothing for more than 5 minutes at the end, and had a working set of 11.9 GB
  when I stopped it. The module listing costs 1.4 to 2.6 seconds per call and
  `Get-DscResourceProperty` 1.4 to 1.9 seconds, so the 176 composite resources
  need about 10 to 15 minutes in these two calls alone. In isolated tests
  neither call grew the memory (12 calls of `Get-DscResourceProperty`: 540 to
  810 MB; 8 module listings: 310 to 460 MB), and the re-import of
  `DscBuildHelpers` with `-Force` costs 0.01 seconds. The cause of the growth
  is not isolated. The generator session had no pinned engine, so it loaded
  the M365DSC engine (SDP-4), which the isolated tests did not.
- **Proposed change:** List the module once per run instead of once per
  composite resource. Run the generator with one DSC engine, and check whether
  the memory then stays flat. Neither is verified.
- **Local workaround:** none
- **Status:** not filed.

## M365DSC.PSDesiredStateConfiguration

### M365PSDSC-1: Document or soften the claim of the module name

- **Repository:** [Microsoft365DSC/PSDesiredStateConfiguration](https://github.com/Microsoft365DSC/PSDesiredStateConfiguration)
- **Needed:** optional (an alternative to SDP-4)
- **Where:** the section "Module name claim" of
  `M365DSC.PSDesiredStateConfiguration.psm1` (from line 4917) and the module
  `Compat/PSDesiredStateConfiguration`. The manifest lists `Configuration`,
  `Get-DscResource` and the other commands in `FunctionsToExport`, as the
  manifest of PSDesiredStateConfiguration 2.0.8 does for its four commands.
- **Problem:** The engine ships a compatibility module that is named
  `PSDesiredStateConfiguration` (version 3.1.10) and claims the global function
  `PSDesiredStateConfiguration\Configuration`, so that the engine of a
  configuration resolves to it. That is by design. In a session that also has
  PSDesiredStateConfiguration 2.0.8, for example because a build pins it, two
  modules of that name exist, and code that expects one fails (SDP-4). Which of
  the two engines a session gets by auto-loading depends on the order of the
  module path, so a restore into one folder, as Sampler does, gives the
  M365DSC engine.
- **Existing documentation (read on 2026-10-30):** The README ("How the name
  is claimed"), `docs/Architecture.md` ("The module name claim") and
  `docs/FastHostContract.md` explain the claim, and
  `test/ModuleNameClaim.Tests.ps1` guards it: a consumer imports the engine by
  path and nothing else, so that the inbox 1.1 or the gallery 2.x module never
  owns `Configuration`. The claim is deliberate. What the documents do not say
  is what a build must do that also needs the gallery module, here for
  `Get-DscResource` through DscBuildHelpers and for a pinned 2.0.8. Narrow the
  issue to that case.
- **Proposed change:** State in the README that one of the two engines must be
  imported first and that the other must not be loaded in the same session, or
  let the module refuse to claim the name, with a readable message, when another
  module of that name is already loaded.
- **Issue title:** Coexistence with PSDesiredStateConfiguration 2.0.8 in one
  session
- **Local workaround:** `Initialize-StandardDscEngine` in
  `.build/DscCompileHelpers.ps1`
- **Status:** not filed. [Issue 7524 of Microsoft365DSC](https://github.com/Microsoft365DSC/Microsoft365DSC/issues/7524)
  (closed) confirms that composite resources and the modules that declare them
  keep working with 2.x.

### M365PSDSC-2: Cache imported class-based keywords for the session

- **Repository:** [Microsoft365DSC/PSDesiredStateConfiguration](https://github.com/Microsoft365DSC/PSDesiredStateConfiguration)
- **Needed:** optional
- **Where:** the import of class-based resources behind
  `Import-DscResource -ModuleName Microsoft365DSC`, next to `SchemaCache.ps1`.
- **Evidence:** with the M365DSC engine as the only engine and
  `DscSchemaCache.json` in the module folder, three consecutive invocations of
  a configuration that imports `Microsoft365DSC` cost 8.1, 5.7 and 5.2 seconds.
  `CompileRootConfiguration` of this project, which imports each used
  composite resource once for each of three nodes, takes 4 min 39 s to 5 min 40
  s.
- **Idea:** Keep the keywords of a class-based module and version for the
  session, so that a repeated import costs almost nothing. Not prototyped.
- **Local workaround:** none
- **Status:** not filed.

### M365PSDSC-3: Support composite resources in the fast host

- **Repository:** [Microsoft365DSC/PSDesiredStateConfiguration](https://github.com/Microsoft365DSC/PSDesiredStateConfiguration)
- **Needed:** optional
- **Where:** `FastHost.ps1` line 810: `Module '...' contains composite
  resources, which the fast host does not support yet.`
- **Problem:** Pipelines that compile Datum data through composite resources,
  like this one, cannot use the fast compile path.
- **Design note (read on 2026-10-30):** The fallback is by design.
  `docs/FastHostContract.md` lists the composite resources of a module among
  the cases that fall back to standard compilation with a warning. Frame the
  issue as a feature request, with the measured cost of the standard path.
- **Local workaround:** none
- **Status:** not filed.

## Findings that need no change

- `TestDscResources` of Sampler.DscPipeline is a no-op ("Not implemented yet"),
  so its `Get-DscResource -Module` calls never run.
- Sampler runs a task in `.build` instead of a task of the same name from a
  module, and the functions of a `.build` script are visible to every task. The
  workarounds rely on both and need no change in Sampler.

## Removal checklist

When the upstream releases contain the changes:

1. Update the pins in `RequiredModules.psd1`, and the reviewed versions in
   `PrepareDscCompile`.
2. Delete `.build/DscCompileHelpers.ps1`, `.build/DscCompileTasks.ps1`,
   `source/CompileRootConfiguration.ps1`, `source/RootConfiguration.ps1` and
   `tests/ConfigData/DscCompile.Tests.ps1`, and remove `PrepareDscCompile` from
   `build.yaml`.
3. Restore the commented-out keys named in DC365-1.
4. Set the `Local workaround` line of each finished entry to `none` and its
   status to the release that contains the change.
5. Run `.\build.ps1` and confirm that the build time stays in minutes.

## See also

- [CHANGELOG.md](../CHANGELOG.md)
- [Getting started](GettingStarted.md)
