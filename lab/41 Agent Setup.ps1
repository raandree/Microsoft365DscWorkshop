$here = $PSScriptRoot
$azureData = Get-Content $here\..\source\Global\Azure.yml | ConvertFrom-Yaml
$azDoData = Get-Content $here\..\source\Global\AzureDevOps.yml | ConvertFrom-Yaml
$labs = Get-Lab -List | Where-Object { $_ -Like 'M365DscWorkshopWorker*' }

if (-not (Test-LabAzureModuleAvailability -ErrorAction SilentlyContinue)) {
    Write-Error "PowerShell modules for AutomateLab Azure integration not found or could not be loaded. Please run 'Install-LabAzureRequiredModule' to install them. If this fails, please restart the PowerShell session and try again."
    return
}

$vsCodeDownloadUrl = 'https://go.microsoft.com/fwlink/?Linkid=852157'
$gitDownloadUrl = 'https://github.com/git-for-windows/git/releases/download/v2.39.2.windows.1/Git-2.39.2-64-bit.exe'
$vscodePowerShellExtensionDownloadUrl = 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-vscode/vsextensions/PowerShell/2023.1.0/vspackage'
$notepadPlusPlusDownloadUrl = 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.4.9/npp.8.4.9.Installer.x64.exe'
$vstsAgentUrl = 'https://vstsagentpackage.azureedge.net/agent/3.218.0/vsts-agent-win-x64-3.218.0.zip'

$vscodeInstaller = Get-LabInternetFile -Uri $vscodeDownloadUrl -Path $labSources\SoftwarePackages -PassThru
$gitInstaller = Get-LabInternetFile -Uri $gitDownloadUrl -Path $labSources\SoftwarePackages -PassThru
Get-LabInternetFile -Uri $vscodePowerShellExtensionDownloadUrl -Path $labSources\SoftwarePackages\VSCodeExtensions\ps.vsix
$notepadPlusPlusInstaller = Get-LabInternetFile -Uri $notepadPlusPlusDownloadUrl -Path $labSources\SoftwarePackages -PassThru
$vstsAgenZip = Get-LabInternetFile -Uri $vstsAgentUrl -Path $labSources\SoftwarePackages -PassThru

foreach ($lab in $labs) {
    $lab -match '(?:M365DscWorkshopWorker)(?<Environment>\w+)(?:\d{1,4})' | Out-Null
    $environmentName = $Matches.Environment
    $environment = $azureData.Environments.$environmentName
    Write-Host "Working in environment '$environmentName'" -ForegroundColor Magenta
    
    $lab = Import-Lab -Name $lab -NoValidation -PassThru
    Write-Host "Imported lab '$($lab.Name)' with $($lab.Machines.Count) machines"

    $cred = New-Object pscredential($environment.AzApplicationId, ($environment.AzApplicationSecret | ConvertTo-SecureString -AsPlainText -Force))
    $subscription = Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $environment.AzTenantId -ErrorAction Stop
    Write-Host "Successfully connected to Azure subscription '$($subscription.Context.Subscription.Name) ($($subscription.Context.Subscription.Id))' with account '$($subscription.Context.Account.Id)'"

    $vms = Get-LabVM

    Write-Host "Installing software on $($vms.Count) machines"
    Install-LabSoftwarePackage -Path $vscodeInstaller.FullName -CommandLine /SILENT -ComputerName $vms
    Install-LabSoftwarePackage -Path $gitInstaller.FullName -CommandLine /SILENT -ComputerName $vms
    Install-LabSoftwarePackage -Path $notepadPlusPlusInstaller.FullName -CommandLine /S -ComputerName $vms
    
    Invoke-LabCommand -Activity 'Setup AzDo Build Agent' -ScriptBlock {

        Expand-Archive -Path $vstsAgenZip.FullName -DestinationPath C:\Agent -Force
        "C:\Agent\config.cmd --unattended --url https://dev.azure.com/$($azDoData.OrganizationName) --auth pat --token $($azDoData.PersonalAccessToken) --pool $($azDoData.AgentPoolName) --agent $env:COMPUTERNAME --runAsService --windowsLogonAccount 'NT AUTHORITY\SYSTEM' --acceptTeeEula" | Out-File C:\DeployDebug\AzDoAgentSetup.cmd -Force
        C:\Agent\config.cmd --unattended --url https://dev.azure.com/$($azDoData.OrganizationName) --auth pat --token $($azDoData.PersonalAccessToken) --pool $($azDoData.AgentPoolName) --agent $env:COMPUTERNAME --runAsService --windowsLogonAccount 'NT AUTHORITY\SYSTEM' --acceptTeeEula

    } -ComputerName $vms -Variable (Get-Variable -Name vstsAgenZip, azDoData)

    Invoke-LabCommand -Activity 'Installing NuGet and PowerShellGet' -ScriptBlock {

        Install-PackageProvider -Name NuGet -Force
        Install-Module -Name PowerShellGet -Force

    } -ComputerName $vms

    Invoke-LabCommand -Activity 'Setting environment variable for build environment' -ScriptBlock {

        [System.Environment]::SetEnvironmentVariable('BuildEnvironment', $args[0], 'Machine')

    } -ComputerName $vms -ArgumentList $lab.Notes.Environment

    Write-Host "Restarting $($vms.Count) machines"
    Restart-LabVM -ComputerName $vms -Wait

    Write-Host "Finished installing AzDo Build Agent on $($vms.Count) machines in environment '$environmentName'"
}
