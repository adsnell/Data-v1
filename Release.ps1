# Release.ps1 - one command to publish a Data release.
#   .\Release.ps1               uses the version in src\App.ps1 (for example v1.0)
#   .\Release.ps1 -Tag v1.1     a specific tag
#   .\Release.ps1 -MoveTag      re-point an existing tag at the current commit
# It commits the manual PDF if that is the only change, pushes, builds the zip,
# tags the commit, prints the checksum and opens the GitHub Releases page.
param([string]$Tag = '', [switch]$MoveTag)
Set-Location $PSScriptRoot
Clear-Host
$ErrorActionPreference = 'Stop'

$top = ((& git.exe rev-parse --show-toplevel) -join '').Trim().Replace('/', '\')
if ($top -ne $PSScriptRoot) { Write-Host "Git top level is '$top' - stopping." -ForegroundColor Red; return }

$appText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'src\App.ps1'))
$m = [regex]::Match($appText, 'appVersion\s*=\s*\x27([^\x27]+)\x27')
if (-not $m.Success) { Write-Host 'Could not read appVersion from src\App.ps1 - stopping.' -ForegroundColor Red; return }
$ver = $m.Groups[1].Value
if (-not $Tag) { $Tag = if ($ver -match '\.') { "v$ver" } else { "v$ver.0" } }
if ($Tag -notmatch ('^v' + [regex]::Escape($ver) + '(\.\d+)*$')) { Write-Host "Tag $Tag does not match the app version ($ver) - stopping." -ForegroundColor Red; return }

git.exe fetch origin --tags
$ab = (git.exe rev-list --left-right --count 'HEAD...origin/main') -split '\s+'
if ([int]$ab[1] -gt 0) { Write-Host 'GitHub has newer commits - pull first. Stopping.' -ForegroundColor Red; return }

$changed = @(git.exe status --porcelain)
if ($changed.Count -eq 1 -and $changed[0] -like '*User Manual.pdf*') {
    git.exe add -A
    git.exe commit -m 'Update User Manual PDF'
} elseif ($changed.Count -gt 0) {
    Write-Host 'Uncommitted changes other than the manual PDF - stopping.' -ForegroundColor Red
    git.exe status --short
    return
}

$localTag = [bool](git.exe tag -l $Tag)
$remoteTag = [bool](git.exe ls-remote --tags origin "refs/tags/$Tag")
if (($localTag -or $remoteTag) -and -not $MoveTag) {
    Write-Host "Tag $Tag already exists. Use a new tag (-Tag v1.1) or add -MoveTag to re-point it." -ForegroundColor Yellow
    return
}

git.exe push origin main
if ($LASTEXITCODE -ne 0) { Write-Host 'Push failed - stopping.' -ForegroundColor Red; return }

& (Join-Path $PSScriptRoot 'Package.ps1') -NoClear
Set-Location $PSScriptRoot
$zip = Join-Path $PSScriptRoot 'dist\Data-portable.zip'
if (-not (Test-Path $zip)) { Write-Host 'Zip was not created - stopping.' -ForegroundColor Red; return }
$out = Join-Path $PSScriptRoot "dist\Data-$Tag-portable.zip"
Copy-Item $zip $out -Force
$sha = (Get-FileHash $out -Algorithm SHA256).Hash

if ($localTag) { git.exe tag -d $Tag }
git.exe tag -a $Tag -m "Data $Tag"
if ($MoveTag) { git.exe push origin $Tag --force } else { git.exe push origin $Tag }
if ($LASTEXITCODE -ne 0) { Write-Host 'Tag push failed.' -ForegroundColor Red; return }

Write-Host '=== Tag on GitHub ===' -ForegroundColor Cyan
git.exe ls-remote --tags origin
Write-Host ("$Tag points to: " + ((git.exe log -1 --format='%h  %s' $Tag) -join ''))
git.exe status -sb
Write-Host ''
Write-Host ('Release file : ' + $out) -ForegroundColor Green
Write-Host ('Size         : {0} MB' -f [math]::Round((Get-Item $out).Length / 1MB, 1)) -ForegroundColor Green
Write-Host ('SHA256       : ' + $sha) -ForegroundColor Green
Start-Process explorer.exe "/select,`"$out`""
Start-Process 'https://github.com/adsnell/Data-v1/releases'