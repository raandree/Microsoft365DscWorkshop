BeforeAll {
    $repositoryRoot = Convert-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\..')
    $registerPath = Join-Path -Path $repositoryRoot -ChildPath 'docs\upstream-changes.md'

    # The marker is built from two parts, so that this file does not contain it.
    $idPattern = '[A-Z][A-Z0-9]*-\d+'
    $markerPattern = 'UPSTREAM' + ":\s*(?<ids>$idPattern(?:\s*,\s*$idPattern)*)"

    $registerExists = Test-Path -Path $registerPath

    # Every '### <ID>: <title>' heading of the register is an entry. Its line '- **Local workaround:** ...' (with the indented
    # lines that continue it) names the files of this repository that exist only until the dependency has changed, or says 'none'.
    $entry = [System.Collections.Generic.List[hashtable]]::new()

    if ($registerExists)
    {
        $continues = $false

        foreach ($line in Get-Content -Path $registerPath)
        {
            if ($line -match "^###\s+(?<id>$idPattern):")
            {
                $entry.Add(@{ Id = $Matches['id']; Workaround = $null })
                $continues = $false
            }
            elseif ($entry.Count -gt 0 -and $line -match '^- \*\*Local workaround:\*\*\s*(?<text>.*)$')
            {
                $entry[$entry.Count - 1].Workaround = $Matches['text'].Trim()
                $continues = $true
            }
            elseif ($continues -and $line -match '^\s{2,}\S')
            {
                $entry[$entry.Count - 1].Workaround = ($entry[$entry.Count - 1].Workaround + ' ' + $line.Trim()).Trim()
            }
            else
            {
                $continues = $false
            }
        }
    }

    $registeredId = @($entry | ForEach-Object -Process { $_.Id })

    $searchPath = foreach ($folder in '.build', 'source', 'tests', 'lab')
    {
        $path = Join-Path -Path $repositoryRoot -ChildPath $folder

        if (Test-Path -Path $path)
        {
            $path
        }
    }

    $file = @(Get-ChildItem -Path $searchPath -Recurse -File -Include *.ps1, *.psm1, *.psd1, *.yml, *.yaml) +
    @(Get-Item -Path (Join-Path -Path $repositoryRoot -ChildPath 'RequiredModules.psd1'), (Join-Path -Path $repositoryRoot -ChildPath 'build.yaml'))

    $markedId = [System.Collections.Generic.HashSet[System.String]]::new()
    $undefinedMarker = [System.Collections.Generic.List[System.String]]::new()

    foreach ($item in $file)
    {
        $relativePath = $item.FullName.Substring($repositoryRoot.Length).TrimStart('\').Replace('\', '/')

        foreach ($match in [System.Text.RegularExpressions.Regex]::Matches((Get-Content -Path $item.FullName -Raw), $markerPattern))
        {
            foreach ($id in ($match.Groups['ids'].Value -split '\s*,\s*'))
            {
                $null = $markedId.Add($id)

                if ($id -notin $registeredId -and "$id in $relativePath" -notin $undefinedMarker)
                {
                    $undefinedMarker.Add("$id in $relativePath")
                }
            }
        }
    }

    $entryWithoutWorkaround = @($entry | Where-Object -FilterScript { -not $_.Workaround } | ForEach-Object -Process { $_.Id })

    $workaroundWithoutMarker = @($entry |
            Where-Object -FilterScript { $_.Workaround -and $_.Workaround -notmatch '^none\b' -and -not $markedId.Contains($_.Id) } |
                ForEach-Object -Process { $_.Id })

    # Backticked names in the workaround line that look like a path must exist.
    $missingPath = foreach ($item in $entry)
    {
        if (-not $item.Workaround)
        {
            continue
        }

        foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($item.Workaround, '`(?<path>[^`]+)`'))
        {
            $path = $match.Groups['path'].Value

            if (($path -match '[\\/]' -or $path -match '\.(ps1|psm1|psd1|yml|yaml)$') -and -not (Test-Path -Path (Join-Path -Path $repositoryRoot -ChildPath $path)))
            {
                "$($item.Id): $path"
            }
        }
    }
}

Describe 'Upstream change register' -Tag Integration {
    It 'Should exist at docs/upstream-changes.md' {
        $registerExists | Should -BeTrue -Because 'every workaround for a dependency must be tracked in the register'
    }

    It "Should have the line 'Local workaround' in every entry" {
        $entryWithoutWorkaround | Should -BeNullOrEmpty -Because "an entry '### <ID>: ...' needs the line '- **Local workaround:** ...' with the files or 'none'"
    }

    It 'Should have a marker in the code for every workaround that is not none' {
        $workaroundWithoutMarker | Should -BeNullOrEmpty -Because 'the files named in the local workaround must carry the marker comment, or the line must say none'
    }

    It 'Should name only files that exist in the local workarounds' {
        $missingPath | Should -BeNullOrEmpty -Because 'a workaround that was deleted must also leave the register'
    }

    It 'Should define every ID that a marker in the code refers to' {
        $undefinedMarker | Should -BeNullOrEmpty -Because "docs/upstream-changes.md needs the entry '### <ID>: ...' for each marker"
    }
}
