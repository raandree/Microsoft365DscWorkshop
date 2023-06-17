$azDoOrg = '<Link to you Azure DevOps organization>'
$azDoPat = 'Azure DevOps PAT'
$azDoAgentPoolName = 'DSC'

#------------------------------------------------------------------------------------------------------------

$labName = Get-Lab -List | Where-Object { $_ -like 'M365DscWorkshopWorker*' }

$vsCodeDownloadUrl = 'https://go.microsoft.com/fwlink/?Linkid=852157'
$gitDownloadUrl = 'https://github.com/git-for-windows/git/releases/download/v2.39.2.windows.1/Git-2.39.2-64-bit.exe'
$vscodePowerShellExtensionDownloadUrl = 'https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-vscode/vsextensions/PowerShell/2023.1.0/vspackage'
$notepadPlusPlusDownloadUrl = 'https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.4.9/npp.8.4.9.Installer.x64.exe'
$vstsAgentUrl = 'https://vstsagentpackage.azureedge.net/agent/3.218.0/vsts-agent-win-x64-3.218.0.zip'
$pwshUrl = 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.3/PowerShell-7.3.3-win-x64.msi'
$dotnetSdkUrl = 'https://download.visualstudio.microsoft.com/download/pr/c6ad374b-9b66-49ed-a140-588348d0c29a/78084d635f2a4011ccd65dc7fd9e83ce/dotnet-sdk-7.0.202-win-x64.exe'

$labs = Get-Lab -List | Where-Object { $_ -Like 'M365DscWorkshopWorker*' }

foreach ($lab in $labs)
{
    $lab = Import-Lab -Name $lab -NoValidation -PassThru
    Set-AzContext -SubscriptionId $lab.AzureSettings.DefaultSubscription.SubscriptionId -Tenant $lab.AzureSettings.DefaultSubscription.TenantId

    $vms = Get-LabVM

    $vscodeInstaller = Get-LabInternetFile -Uri $vscodeDownloadUrl -Path $labSources\SoftwarePackages -PassThru
    $gitInstaller = Get-LabInternetFile -Uri $gitDownloadUrl -Path $labSources\SoftwarePackages -PassThru
    Get-LabInternetFile -Uri $vscodePowerShellExtensionDownloadUrl -Path $labSources\SoftwarePackages\VSCodeExtensions\ps.vsix
    $notepadPlusPlusInstaller = Get-LabInternetFile -Uri $notepadPlusPlusDownloadUrl -Path $labSources\SoftwarePackages -PassThru
    $vstsAgenZip = Get-LabInternetFile -Uri $vstsAgentUrl -Path $labSources\SoftwarePackages -PassThru
    $pwshInstaller = Get-LabInternetFile -Uri $pwshUrl -Path $labSources\SoftwarePackages -PassThru
    $dotnetInstaller = Get-LabInternetFile -Uri $dotnetSdkUrl -Path $labSources\SoftwarePackages -PassThru

    Install-LabSoftwarePackage -Path $vscodeInstaller.FullName -CommandLine /SILENT -ComputerName $vms
    Install-LabSoftwarePackage -Path $gitInstaller.FullName -CommandLine /SILENT -ComputerName $vms
    Install-LabSoftwarePackage -Path $notepadPlusPlusInstaller.FullName -CommandLine /S -ComputerName $vms
    Install-LabSoftwarePackage -LocalPath ($pwshInstaller.FullName -replace '(\\\\automatedlabsources)([a-z]{1,6})\.file\.core\.windows\.net\\labsources', 'Z:') -CommandLine /quiet -ComputerName $vms
    Install-LabSoftwarePackage -Path $dotnetInstaller.FullName -CommandLine '/install /quiet /norestart' -ComputerName $vms

    Invoke-LabCommand -Activity 'Setup AzDo Build Agent' -ScriptBlock {

        Expand-Archive -Path $vstsAgenZip.FullName -DestinationPath C:\Agent -Force
        "C:\Agent\config.cmd --unattended --url $azDoOrg --auth pat --token $azDoPat --pool $azDoAgentPoolName --agent $env:COMPUTERNAME --runAsService --windowsLogonAccount 'NT AUTHORITY\SYSTEM' --acceptTeeEula" | Out-File C:\DeployDebug\AzDoAgentSetup.cmd -Force
        C:\Agent\config.cmd --unattended --url $azDoOrg --auth pat --token $azDoPat --pool $azDoAgentPoolName --agent $env:COMPUTERNAME --runAsService --windowsLogonAccount 'NT AUTHORITY\SYSTEM' --acceptTeeEula

    } -ComputerName $vms -Variable (Get-Variable -Name vstsAgenZip, azDoOrg, azDoPat, azDoAgentPoolName)

    Invoke-LabCommand -Activity 'Installing NuGet and PowerShellGet' -ScriptBlock {

        Install-PackageProvider -Name NuGet -Force
        Install-Module -Name PowerShellGet -Force

    } -ComputerName $vms

    Invoke-LabCommand -Activity 'Setting environment variable for build environment' -ScriptBlock {

        [System.Environment]::SetEnvironmentVariable('BuildEnvironment', $args[0], 'Machine')

    } -ComputerName $vms -ArgumentList $lab.Notes.Environment

    Restart-LabVM -ComputerName $vms -Wait
}
