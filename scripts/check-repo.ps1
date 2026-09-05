$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    $trackedFiles = @(git -c core.quotepath=false ls-files)
    if ($LASTEXITCODE -ne 0) { throw 'Could not list tracked files.' }
    $failures = [Collections.Generic.List[string]]::new()
    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    foreach ($file in $trackedFiles) {
        if ($file -match '(?i)\.docx$|resume.*\.pdf$|(^|/)~\$') {
            $failures.Add("${file}: personal document must remain local.")
        }
        if ($file -notmatch '\.(md|yml|yaml|ps1)$|(^|/)(\.editorconfig|\.gitattributes|\.gitignore|CODEOWNERS)$') {
            continue
        }
        try { $content = [IO.File]::ReadAllText((Join-Path $repoRoot $file), $utf8) }
        catch { $failures.Add("${file}: cannot read as UTF-8."); continue }
        if ($content.Contains("`r")) { $failures.Add("${file}: use LF line endings.") }
        if ($content.Length -gt 0 -and -not $content.EndsWith("`n")) {
            $failures.Add("${file}: missing final newline.")
        }
        $lineNumber = 0
        foreach ($line in ($content -split "`n")) {
            $lineNumber++
            if ($line -match '[\t ]+$') { $failures.Add("${file}:${lineNumber}: trailing whitespace.") }
            if ($line -match '^(<{7}|={7}|>{7}|\|{7})(\s|$)') {
                $failures.Add("${file}:${lineNumber}: unresolved merge marker.")
            }
        }
    }
    if ($failures.Count -gt 0) { throw ($failures -join "`n") }
    Write-Output "Repository checks passed ($($trackedFiles.Count) tracked files)."
}
finally { Pop-Location }
