[Managing Microsoft365 with Microsoft365DSC and Azure DevOps](https://techcommunity.microsoft.com/t5/azure-developer-community-blog/managing-microsoft365-with-microsoft365dsc-and-azure-devops/ba-p/3054333)

[Managing Microsoft 365 in true DevOps style with Microsoft365Dsc and Azure DevOps](https://office365dsc.azurewebsites.net/Pages/Resources/Whitepapers/Managing%20Microsoft%20365%20with%20Microsoft365Dsc%20and%20Azure%20DevOps.pdf)

[Diagrams with Azure icons](https://app.diagrams.net/?splash=0&clibs=Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Analytics.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Blockchain.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Compute.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Containers.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Databases.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-DevOps.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Favorites.xml.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-General.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Identity.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Integration.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Intune.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-IoT.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Machine-Learning.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Manage.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Migrate.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Miscellaneous.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Networking.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Security.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Stack.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Storage.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FAzure-Web.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FCommands.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FLogos.xml;Uhttps%3A%2F%2Fraw.githubusercontent.com%2Fpacodelacruz%2Fdiagrams-net-azure-libraries%2Fmaster%2FEnterprise.xml;)

[Mermaid ](https://mermaid-js.github.io/mermaid/#/)

---

# Lab setup

PowerShell Script to deploy LCMs in on Azure:

```powershell
New-LabDefinition -Name DbTest1 -DefaultVirtualizationEngine Azure
Add-LabAzureSubscription -SubscriptionName AL2
Add-LabMachineDefinition -Name DbLcm1 -Memory 4GB -OperatingSystem 'Windows Server 2019 Datacenter (Desktop Experience)'
Add-LabMachineDefinition -Name DbLcm2 -Memory 4GB -OperatingSystem 'Windows Server 2019 Datacenter (Desktop Experience)'

Install-Lab
```
