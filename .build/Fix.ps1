task FixMSCloudLoginAssistant {

    $missingLine = '$accessToken = $accessToken | ConvertTo-SecureString -AsPlainText -Force'
    $p = Resolve-Path -Path "$RequiredModulesDirectory\MSCloudLoginAssistant\*\Workloads\MicrosoftGraph.psm1"
    $c = Get-Content -Path $p

    if ($c -like "*$missingLine*") {
        return
    }

    $c[84] = $missingLine
    $c | Set-Content -Path $p
    
}
