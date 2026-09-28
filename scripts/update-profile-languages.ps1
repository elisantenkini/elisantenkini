param([string]$Username = 'elisantenkini')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent $PSScriptRoot
$headers = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'profile-language-refresh' }
if (-not $env:GH_TOKEN) { throw 'Set GH_TOKEN with read access to your public and private repositories before refreshing combined totals.' }
$headers.Authorization = "Bearer $env:GH_TOKEN"
$viewer = Invoke-RestMethod 'https://api.github.com/user' -Headers $headers
if ($viewer.login -ne $Username) { throw 'The authenticated account must match Username.' }

# Read owned repositories; publish private languages only in combined totals.
$repos = @()
for ($page = 1; ; $page++) {
    $response = Invoke-RestMethod "https://api.github.com/user/repos?affiliation=owner&per_page=100&page=$page" -Headers $headers
    $batch = @($response)
    $repos += @($batch | Where-Object { $_.owner.login -eq $Username })
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
    if ($repo.private) { continue }
    $names = ($properties | Sort-Object { [long]$_.Value } -Descending | ForEach-Object { $_.Name }) -join ', '
    if (-not $names) { $names = 'No language detected' }
    $kind = if ($repo.fork) { 'Fork' } else { 'Original' }
    "| [$($repo.name)]($($repo.html_url)) | $kind | $names |"
}
$publicRepos = @($repos | Where-Object { -not $_.private })
$publicOriginalCount = @($publicRepos | Where-Object { -not $_.fork }).Count
$forkCount = @($publicRepos | Where-Object { $_.fork }).Count
$date = [DateTime]::UtcNow.ToString('yyyy-MM-dd')
$year = [DateTime]::UtcNow.ToString('yyyy')
$totalBytes = ($totals.Values | Measure-Object -Sum).Sum
$table = @('| Language | Share of code bytes |', '|---|---:|')
if ($totalBytes -gt 0) {
    foreach ($entry in ($totals.GetEnumerator() | Sort-Object Value -Descending)) {
        $percentage = (100 * $entry.Value / $totalBytes).ToString('F1', [Globalization.CultureInfo]::InvariantCulture)
        $table += "| $($entry.Key) | $percentage% |"
    }
} else {
    $table = @('GitHub currently reports no language data for the accessible original repositories.')
}
$block = @(
    '<!-- repository-languages:start -->'
    "**$year**"
    ''
    $table
    ''
    "Forks are excluded because they include upstream code. The [public repository inventory](docs/public-repositories.md) lists public projects separately. Repositories without detected code contribute no bytes."
    ''
    '> These figures measure code bytes on default branches, not proficiency or recent activity. Private repositories contribute only to combined language totals; their names and files are not published. Coverage is limited to repositories accessible to the account used for the refresh.'
    '<!-- repository-languages:end -->'
) -join "`n"
$readmePath = Join-Path $repoRoot 'README.md'
$readme = [IO.File]::ReadAllText($readmePath)
$pattern = '(?s)<!-- repository-languages:start -->.*?<!-- repository-languages:end -->'
if ([regex]::Matches($readme, $pattern).Count -ne 1) { throw 'Expected exactly one repository language block.' }
$updated = [regex]::Replace($readme, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $block })
$inventory = @(
    '# Public repository inventory'
    ''
    "Reviewed $date (UTC): $($publicRepos.Count) public repositories, including $publicOriginalCount originals and $forkCount forks."
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
Write-Output "Updated combined language totals and inventory of $($publicRepos.Count) public repositories."
