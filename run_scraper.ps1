# PowerShell wrapper to auto-restart lucy_scraper.js on failures/hangs

$maxRestarts = 1000
$restartCount = 0
$restartDelay = 5

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Lucy Scraper - Auto-Restart Wrapper" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Max restarts: $maxRestarts" -ForegroundColor Gray
Write-Host "Restart delay: $restartDelay seconds" -ForegroundColor Gray
Write-Host ""

while ($restartCount -lt $maxRestarts) {
    $attemptNum = $restartCount + 1
    Write-Host "🚀 Starting scraper (attempt $attemptNum/$maxRestarts)..." -ForegroundColor Cyan
    Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
    
    # Run the node script
    node lucy_scraper.js itemlist.txt
    
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host "✅ Scraper completed successfully!" -ForegroundColor Green
        Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
        break
    } else {
        $restartCount++
        Write-Host ""
        Write-Host "⚠️  Scraper exited with code $exitCode" -ForegroundColor Yellow
        
        if ($restartCount -lt $maxRestarts) {
            Write-Host "🔄 Restarting in $restartDelay seconds..." -ForegroundColor Yellow
            Write-Host ""
            Start-Sleep -Seconds $restartDelay
        }
    }
}

if ($restartCount -ge $maxRestarts) {
    Write-Host ""
    Write-Host "❌ Max restarts ($maxRestarts) reached. Exiting." -ForegroundColor Red
    Write-Host "Check the debug logs at D:\lucy\debug\ for details." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Scraper wrapper finished." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan