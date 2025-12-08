# YALM2 Quick Restore Script
# Restores to the stable v1.0 version

param(
    [string]$BackupPath = "",
    [switch]$ToStable = $false,
    [switch]$ListVersions = $false
)

Set-Location "c:\MQ2\lua\yalm2"

if ($ListVersions) {
    Write-Host "Available Git Versions:" -ForegroundColor Cyan
    git tag -l
    Write-Host "`nAvailable Backups:" -ForegroundColor Cyan
    Get-ChildItem "c:\MQ2\lua\yalm2_backup_*" -Directory | Select-Object Name, CreationTime
    return
}

if ($ToStable) {
    Write-Host "Restoring to stable version (v1.0-stable)..." -ForegroundColor Yellow
    
    # Create safety backup first
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Write-Host "Creating safety backup before restore..." -ForegroundColor Green
    git add .
    git commit -m "Safety backup before restore to stable - $timestamp"
    
    # Restore to stable
    git checkout v1.0-stable --force
    Write-Host "✓ Restored to stable version!" -ForegroundColor Green
    Write-Host "Reload in-game with: /lua reload yalm2" -ForegroundColor Yellow
    return
}

if ($BackupPath -ne "") {
    if (Test-Path $BackupPath) {
        Write-Host "Restoring from backup: $BackupPath" -ForegroundColor Yellow
        
        # Create current backup before restore
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $safetyBackup = "c:\MQ2\lua\yalm2_safety_$timestamp"
        Copy-Item "c:\MQ2\lua\yalm2" $safetyBackup -Recurse -Force
        Write-Host "Safety backup created at: $safetyBackup" -ForegroundColor Green
        
        # Restore from specified backup
        Copy-Item "$BackupPath\*" "c:\MQ2\lua\yalm2\" -Recurse -Force
        Write-Host "✓ Restored from backup!" -ForegroundColor Green
        Write-Host "Reload in-game with: /lua reload yalm2" -ForegroundColor Yellow
    } else {
        Write-Host "✗ Backup path not found: $BackupPath" -ForegroundColor Red
    }
    return
}

# Show usage if no parameters
Write-Host "YALM2 Restore Options:" -ForegroundColor Cyan
Write-Host "  .\restore_yalm2.ps1 -ToStable          # Restore to stable v1.0" -ForegroundColor White  
Write-Host "  .\restore_yalm2.ps1 -ListVersions      # Show available versions" -ForegroundColor White
Write-Host "  .\restore_yalm2.ps1 -BackupPath 'path' # Restore from specific backup" -ForegroundColor White
Write-Host ""
Write-Host "Emergency restore to stable:" -ForegroundColor Yellow
Write-Host "  git checkout v1.0-stable --force" -ForegroundColor White