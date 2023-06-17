$env:m365Location = ' australiaeast '
$env:m365StorageAccountName = '4234234  '
$env:m365AutomationAccountName = '43535543'
$env:m365ResourceGroupName = ' fdgg'

$envVariables = [System.Environment]::GetEnvironmentVariables()

$envVariables.GetEnumerator() | Where-Object { $_.Key -like 'm365*' } | ForEach-Object {
    [System.Environment]::SetEnvironmentVariable($_.Key, $_.Value.Trim())
}

$envVariables = [System.Environment]::GetEnvironmentVariables()
$envVariables.GetEnumerator() | Where-Object { $_.Key -like 'm365*' }
