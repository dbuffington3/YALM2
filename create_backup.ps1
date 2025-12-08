# YALM2 Quick Backup Script
# Run this before making changes to create a timestamped backup

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = "c:\MQ2\lua\yalm2_backup_$timestamp"

Write-Host "Creating backup at: $backupPath" -ForegroundColor Green

try {
    Copy-Item "c:\MQ2\lua\yalm2" $backupPath -Recurse -Force
    Write-Host "✓ Backup created successfully!" -ForegroundColor Green
    Write-Host "To restore: Copy-Item '$backupPath\*' 'c:\MQ2\lua\yalm2\' -Recurse -Force" -ForegroundColor Yellow
} catch {
    Write-Host "✗ Backup failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Also create git checkpoint if git is available
Set-Location "c:\MQ2\lua\yalm2"
try {
    git add .
    git commit -m "Auto-backup checkpoint - $timestamp"
    Write-Host "✓ Git checkpoint created" -ForegroundColor Green
} catch {
    Write-Host "⚠ Git checkpoint skipped (git not available or no changes)" -ForegroundColor Yellow
}