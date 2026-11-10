$root = $PSScriptRoot
$exe = Join-Path $root 'Data.exe'
$ico = Join-Path $root 'Data.ico'
$desktop = [Environment]::GetFolderPath('Desktop')
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path $desktop 'Data v1.lnk'))
$lnk.TargetPath = $exe
$lnk.WorkingDirectory = $root
$lnk.Description = 'Data - XMP metadata editor'
if (Test-Path $ico) { $lnk.IconLocation = ($ico + ',0') } else { $lnk.IconLocation = $exe }
$lnk.Save()
Write-Host "Desktop shortcut created: $(Join-Path $desktop 'Data v1.lnk')" -ForegroundColor Green