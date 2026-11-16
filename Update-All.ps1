# Update-All.ps1 - check, back up and (optionally) release Data in one go.
#   .\Update-All.ps1
Set-Location $PSScriptRoot
Clear-Host
$ErrorActionPreference = 'Stop'
$pdf = 'Data v1 - User Manual.pdf'
$todo = New-Object 'System.Collections.Generic.List[string]'

function Step([string]$t) { Write-Host ''; Write-Host ('== ' + $t) -ForegroundColor Cyan }
function Ok([string]$t)   { Write-Host ('   OK  ' + $t) -ForegroundColor Green }
function Warn([string]$t) { Write-Host ('   !!  ' + $t) -ForegroundColor Yellow }
function Bad([string]$t)  { Write-Host ('   XX  ' + $t) -ForegroundColor Red }
function Ask([string]$q, [bool]$defaultYes = $false) {
    $hint = if ($defaultYes) { 'Y/n' } else { 'y/N' }
    $a = (Read-Host ($q + ' [' + $hint + ']')).Trim().ToLower()
    if (-not $a) { return $defaultYes }
    return $a.StartsWith('y')
}
function Check-Zip([string]$zip) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $za = [IO.Compression.ZipFile]::OpenRead($zip)
    try { $names = @($za.Entries | ForEach-Object { $_.FullName }) } finally { $za.Dispose() }
    $hasExe = @($names | Where-Object { $_ -like '*Data.exe' }).Count -gt 0
    $hasApp = @($names | Where-Object { $_ -like '*src?App.ps1' }).Count -gt 0
    $junk = @($names | Where-Object { $_ -like '*.bak*' -or $_ -like '*.pod' -or $_ -like '*\tools\*' -or $_ -like '*\docs\*' }).Count
    $mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
    if ($hasExe -and $hasApp -and $junk -eq 0) { Ok ("Zip checked: {0} files, {1} MB ({2})" -f $names.Count, $mb, (Split-Path $zip -Leaf)) }
    else { Bad ("Zip problem: Data.exe={0} App.ps1={1} junk files={2}" -f $hasExe, $hasApp, $junk); $todo.Add('Check the zip contents') }
}

# ---------- 0. Safety ----------
$top = ((& git.exe rev-parse --show-toplevel) -join '').Trim().Replace('/', '\')
if ($top -ne $PSScriptRoot) { Bad "Git top level is '$top' - stopping."; return }
$branch = ((& git.exe rev-parse --abbrev-ref HEAD) -join '').Trim()
if ($branch -ne 'main') { Bad "On branch '$branch', expected main - stopping."; return }
if (Get-Process -Name Data -ErrorAction SilentlyContinue) {
    Warn 'Data is running. Close it so your latest settings are saved before they are backed up.'
    if (-not (Ask 'Carry on anyway?')) { return }
}

# ---------- 1. Code checks ----------
Step 'Checking the code'
$broken = $false
foreach ($f in 'src\App.ps1', 'Package.ps1', 'Release.ps1', 'Backup.ps1') {
    $p = Join-Path $PSScriptRoot $f
    if (-not (Test-Path $p)) { continue }
    $tk = $null; $er = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$tk, [ref]$er)
    if ($er.Count -gt 0) { Bad ("$f has a syntax error: " + $er[0].Message); $broken = $true } else { Ok "$f parses" }
}
try { [xml]$xx = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'src\MainWindow.xaml')); Ok 'MainWindow.xaml is valid' } catch { Bad 'MainWindow.xaml is not valid XML'; $broken = $true }
if ($broken) { Bad 'Fix the errors above first - nothing was committed.'; return }
$oldName = 'Metadata' + 'Editor'
$old = @(git.exe grep -i -I -l $oldName -- . ':!exiftool')
if ($old.Count -gt 0) { Warn ("Old name '$oldName' still appears in: " + ($old -join ', ')); $todo.Add('Remove the old name from: ' + ($old -join ', ')) }
else { Ok 'Old app name not found in tracked files' }

# ---------- 2. Manual ----------
Step 'Manual'
$manualNote = 'up to date'
if (@(git.exe status --porcelain -- $pdf).Count -gt 0) {
    Ok 'A new manual PDF is waiting - it will be backed up.'
} else {
    $pdfHash = ((& git.exe log -1 --format=%H -- $pdf) -join '').Trim()
    if (-not $pdfHash) { Warn 'The manual PDF is not in git yet.'; $manualNote = 'not in git'; $todo.Add('Add the manual PDF') }
    else {
        $since = @(git.exe log --format='%h  %ad  %s' --date=short "$pdfHash..HEAD" -- src)
        $dirtySrc = @(git.exe status --porcelain -- src)
        if ($since.Count -gt 0 -or $dirtySrc.Count -gt 0) {
            Warn ("The app changed since the manual PDF was last updated ({0} commit(s)):" -f $since.Count)
            $since | Select-Object -First 8 | ForEach-Object { Write-Host ('       ' + $_) }
            if ($dirtySrc.Count -gt 0) { Write-Host '       (plus changes not committed yet)' }
            if (-not (Ask 'Is the manual still correct for these changes?')) {
                Write-Host ''
                Write-Host 'Ask Claude to update the manual Doc, accept the suggestions, then export the PDF over:' -ForegroundColor Yellow
                Write-Host ('   ' + $pdf) -ForegroundColor Yellow
                Write-Host 'and run .\Update-All.ps1 again. Nothing was committed.' -ForegroundColor Yellow
                return
            }
            $manualNote = 'you confirmed it is still correct'
        } else { Ok 'Manual PDF is newer than the last app change' }
    }
}

# ---------- 3. Git backup ----------
Step 'Backing up to git'
$changes = @(git.exe status --porcelain)
if ($changes.Count -gt 0) {
    Write-Host ("   {0} changed file(s):" -f $changes.Count)
    $changes | Select-Object -First 10 | ForEach-Object { Write-Host ('       ' + $_) }
    git.exe add -A
    [void](git.exe commit -m ('Backup ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')))
    Ok 'Committed'
} else { Ok 'Nothing new to commit' }
git.exe fetch origin --tags
$ab = ((& git.exe rev-list --left-right --count 'HEAD...origin/main') -join '') -split '\s+'
if ([int]$ab[1] -gt 0) { Bad 'GitHub has newer commits than this PC - pull first. Stopping.'; return }
if ([int]$ab[0] -gt 0) {
    git.exe push origin main
    if ($LASTEXITCODE -ne 0) { Bad 'Push failed - stopping.'; return }
    Ok 'Pushed to GitHub'
} else { Ok 'GitHub is already up to date' }

# ---------- 4. Settings backup ----------
Step 'Backing up your settings'
$bk = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Data-backups'
$dest = Join-Path $bk (Get-Date -Format 'yyyy-MM-dd_HHmm')
$copied = 0
foreach ($f in 'settings.json', 'config.json') {
    $p = Join-Path $PSScriptRoot $f
    if (Test-Path $p) {
        if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
        Copy-Item $p $dest -Force; $copied++
    }
}
if ($copied -gt 0) {
    Ok "Copied $copied file(s) to $dest"
    Get-ChildItem $bk -Directory | Sort-Object Name -Descending | Select-Object -Skip 10 | Remove-Item -Recurse -Force
} else { Warn 'No settings.json or config.json found' }

# ---------- 5. Release ----------
Step 'GitHub release'
$tags = @(git.exe tag -l 'v*' --sort=-v:refname)
$tag = if ($tags.Count -gt 0) { $tags[0] } else { '' }
$aheadOfTag = 0
if ($tag) { $aheadOfTag = [int]((& git.exe rev-list --count "$tag..HEAD") -join '') }
$relTag = ''
if ($tag -and $aheadOfTag -eq 0) {
    Ok "Release $tag already points at the latest code."
} else {
    if ($tag) {
        Warn ("{0} commit(s) since release {1}:" -f $aheadOfTag, $tag)
        git.exe log --format='       %h  %s' "$tag..HEAD" | Select-Object -First 8
    } else { Warn 'There is no release tag yet.' }
    $prompt = if ($tag) { "Update the GitHub release? Enter = move $tag to the latest code, a new tag (for example v1.1) = new release, n = skip" } else { 'Create the first release? Type a tag (for example v1.0), or n to skip' }
    $a = (Read-Host $prompt).Trim()
    $relParams = $null
    if ($a -match '^(n|no)$') { $relParams = $null }
    elseif ($a -match '^v\d') { $relParams = @{ Tag = $a }; $relTag = $a }
    elseif ($a -eq '' -and $tag) { $relParams = @{ Tag = $tag; MoveTag = $true }; $relTag = $tag }
    if ($relParams) {
        & (Join-Path $PSScriptRoot 'Release.ps1') @relParams
        Set-Location $PSScriptRoot
    } else { Warn 'Release not updated.'; $todo.Add('The GitHub release does not have the latest code yet') }
}

# ---------- 6. Zip ----------
Step 'Zip'
$zipPath = ''
if ($relTag -and (Test-Path (Join-Path $PSScriptRoot "dist\Data-$relTag-portable.zip"))) {
    $zipPath = Join-Path $PSScriptRoot "dist\Data-$relTag-portable.zip"
} else {
    & (Join-Path $PSScriptRoot 'Package.ps1') -NoClear
    Set-Location $PSScriptRoot
    $zipPath = Join-Path $PSScriptRoot 'dist\Data-portable.zip'
}
if (Test-Path $zipPath) { Check-Zip $zipPath } else { Bad 'No zip was built'; $todo.Add('Build the zip') }

# ---------- 7. Final check ----------
Step 'Final check'
if (@(git.exe status --porcelain).Count -eq 0) { Ok 'Everything is committed' } else { Warn 'Some changes are not committed'; $todo.Add('Commit the remaining changes') }
git.exe fetch origin --tags
$ab = ((& git.exe rev-list --left-right --count 'HEAD...origin/main') -join '') -split '\s+'
if ([int]$ab[0] -eq 0 -and [int]$ab[1] -eq 0) { Ok 'GitHub matches this PC' } else { Warn ("GitHub differs: ahead {0}, behind {1}" -f $ab[0], $ab[1]); $todo.Add('Push to GitHub') }
$tags = @(git.exe tag -l 'v*' --sort=-v:refname)
if ($tags.Count -gt 0) {
    $n = [int]((& git.exe rev-list --count ($tags[0] + '..HEAD')) -join '')
    if ($n -eq 0) { Ok ("Release tag {0} = latest code" -f $tags[0]) } else { Warn ("Release tag {0} is {1} commit(s) behind" -f $tags[0], $n) }
}
Ok ('Manual: ' + $manualNote)
if ($zipPath) { Write-Host ('   Zip: ' + $zipPath) }
if ($copied -gt 0) { Write-Host ('   Settings backup: ' + $dest) }
if ($relTag) { $todo.Add("On the Releases page, swap in dist\Data-$relTag-portable.zip and update the SHA256") }
Write-Host ''
if ($todo.Count -eq 0) { Write-Host 'All up to date and backed up.' -ForegroundColor Green }
else { Write-Host 'Still to do:' -ForegroundColor Yellow; $todo | ForEach-Object { Write-Host ('   - ' + $_) -ForegroundColor Yellow } }