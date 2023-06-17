# Microsoft365DSC project must be present in folder C:\GitHub\Microsoft365DSC

ipmo C:\GitHub\Microsoft365DSC\ResourceGenerator\M365DSCResourceGenerator.psm1
cd C:\GitHub\Microsoft365DSC\ResourceGenerator

$ResourcePath = "C:\GitHub\Microsoft365DSC\Modules\Microsoft365DSC\DSCResources"
$UnitTestPath = "C:\GitHub\Microsoft365DSC\Tests\Unit\Microsoft365DSC"
$ExamplePath = "C:\GitHub\Microsoft365DSC\Modules\Microsoft365DSC\Examples\Resources"
#$creds = Get-Credential

New-M365DSCResource -ResourceName AADDomain -Workload MicrosoftGraph -Path $ResourcePath -UnitTestPath $UnitTestPath -ExampleFilePath $ExamplePath -Credential $creds -CmdLetNoun MgDomain
