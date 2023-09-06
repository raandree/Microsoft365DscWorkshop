task FixMSCloudLoginAssistant {

    $oldLine = '                -Organization $Global:MSCloudLoginConnectionProfile.OrganizationName `'
    $newLine = '                -Organization $Global:MSCloudLoginConnectionProfile.ExchangeOnline.TenantId `'

    $p = Resolve-Path -Path "$RequiredModulesDirectory\MSCloudLoginAssistant\*\Workloads\ExchangeOnline.psm1"
    $c = Get-Content -Path $p

    $lineNumbers = foreach ($line in $c)
    {
        if ($line -eq $oldLine)
        {
            $line.ReadCount - 1
        }
    }

    foreach ($lineNumber in $lineNumbers)
    {
        $c[$lineNumber] = $newLine
    }
    
    $c -replace $oldLine, $newLine | Set-Content -Path $p

}
