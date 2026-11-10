# make-release.ps1 - builds CleanTemp.zip in the repo root for a GitHub release.
# Run from anywhere:  powershell -ExecutionPolicy Bypass -File tools\make-release.ps1

$root  = Split-Path -Parent $PSScriptRoot
$out   = Join-Path $root 'CleanTemp.zip'
$files = 'CleanTemp.ps1', '007.ico', 'install.ps1', 'Install.bat', 'Run CleanTemp.bat', 'Uninstall.bat', 'README.md', 'LICENSE'

if (Select-String -Path (Join-Path $root 'CleanTemp.ps1') -Pattern 'YOUR-SUBDOMAIN' -Quiet) {
    Write-Host 'Warning: $PingUrl in CleanTemp.ps1 still has YOUR-SUBDOMAIN. The usage count will not work.' -ForegroundColor Yellow
}
Remove-Item -LiteralPath $out -ErrorAction SilentlyContinue
Compress-Archive -Path ($files | ForEach-Object { Join-Path $root $_ }) -DestinationPath $out
Write-Host "Built $out" -ForegroundColor Green
