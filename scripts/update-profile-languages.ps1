param([string]$Username = 'elisantenkini')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
$headers = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'profile-language-refresh' }
if ($env:GH_TOKEN) { $headers.Authorization = "Bearer $env:GH_TOKEN" }

# Use the public user endpoint even when authenticated; never publish private data.
$repos = @()
for ($page = 1; ; $page++) {
    $response = Invoke-RestMethod "https://api.github.com/users/$Username/repos?type=owner&per_page=100&page=$page" -Headers $headers
    $batch = @($response)
    $repos += @($batch | Where-Object { -not $_.private })
    if ($batch.Count -lt 100) { break }
}
$totals = @{}
$rows = foreach ($repo in ($repos | Sort-Object name)) {
    $languages = Invoke-RestMethod $repo.languages_url -Headers $headers
    $properties = @($languages.PSObject.Properties | Where-Object { $_.Value -is [ValueType] })
    if (-not $repo.fork) {
        foreach ($language in $properties) {
            $totals[$language.Name] += [long]$language.Value
        }
    }
    $names = ($properties | Sort-Object { [long]$_.Value } -Descending | ForEach-Object { $_.Name }) -join ', '
    if (-not $names) { $names = 'No language detected' }
    $kind = if ($repo.fork) { 'Fork' } else { 'Original' }
    "| [$($repo.name)]($($repo.html_url)) | $kind | $names |"
}
$originalCount = @($repos | Where-Object { -not $_.fork }).Count
$forkCount = $repos.Count - $originalCount
$date = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
$totalBytes = ($totals.Values | Measure-Object -Sum).Sum
$table = @('| Language | Share of code bytes |', '|---|---:|')
if ($totalBytes -gt 0) {
    foreach ($entry in ($totals.GetEnumerator() | Sort-Object Value -Descending)) {
        $percentage = (100 * $entry.Value / $totalBytes).ToString('F1', [Globalization.CultureInfo]::InvariantCulture)
        $table += "| $($entry.Key) | $percentage% |"
    }
} else {
    $table = @('GitHub currently reports no language data for original public repositories.')
}
$block = @(
    '<!-- public-languages:start -->'
    "Updated **$date (UTC)** from GitHub's language data across **$originalCount original public repositories**."
    ''
    $table
    ''
    "The **$forkCount public forks** are listed in the [repository inventory](docs/public-repositories.md) and excluded from these percentages because they include upstream code. Repositories without detected code contribute no bytes."
    ''
    '> These figures measure code bytes on default branches, not proficiency or recent activity. Private repositories are excluded; the recent-work summary above also covers private projects.'
    '<!-- public-languages:end -->'
) -join "`n"
$readmePath = Join-Path $repoRoot 'README.md'
$readme = [IO.File]::ReadAllText($readmePath)
$pattern = '(?s)<!-- public-languages:start -->.*?<!-- public-languages:end -->'
if ([regex]::Matches($readme, $pattern).Count -ne 1) { throw 'Expected exactly one public language block.' }
$updated = [regex]::Replace($readme, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $block })
$inventory = @(
    '# Public repository inventory'
    ''
    "Reviewed $date (UTC): $($repos.Count) public repositories, including $originalCount originals and $forkCount forks."
    ''
    'Source: GitHub REST public repository listings and each repository''s languages endpoint. Languages are ordered by detected code bytes. A fork listing does not imply authorship of its upstream code.'
    ''
    '| Repository | Type | Detected languages |'
    '|---|---|---|'
    $rows
    ''
    'Refresh this inventory and the profile language table with `pwsh -NoProfile -File scripts/update-profile-languages.ps1`.'
) -join "`n"
# Finish all API reads before changing either output file.
[IO.Directory]::CreateDirectory((Join-Path $repoRoot 'docs')) | Out-Null
[IO.File]::WriteAllText((Join-Path $repoRoot 'docs/public-repositories.md'), "$inventory`n")
[IO.File]::WriteAllText($readmePath, $updated.Replace("`r`n", "`n"))
Write-Output "Updated profile and inventory from $($repos.Count) public repositories."
