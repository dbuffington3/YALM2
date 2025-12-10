# PowerShell script to batch update MQ2LinkDB with Lucy questitem data
# This will process all 134,000+ Lucy JSON files and update the database

param(
    [int]$BatchSize = 5000,
    [string]$DbPath = "C:\MQ2\Resources\MQ2LinkDB.db",
    [string]$LucyDir = "D:\Lucy",
    [switch]$DryRun
)

# Import SQLite module
Import-Module PSSQLite -ErrorAction Stop

Write-Host "=== MQ2LinkDB Lucy Data Batch Update ===" -ForegroundColor Green
Write-Host "Database: $DbPath"
Write-Host "Lucy Directory: $LucyDir"
Write-Host "Batch Size: $BatchSize"
if ($DryRun) { Write-Host "DRY RUN MODE - No database changes will be made" -ForegroundColor Yellow }

# Get all Lucy JSON files
Write-Host "Scanning for Lucy JSON files..." -ForegroundColor Cyan
$lucyFiles = Get-ChildItem "$LucyDir\lucy_item_*.json" | Sort-Object Name
$totalFiles = $lucyFiles.Count
Write-Host "Found $totalFiles Lucy JSON files" -ForegroundColor Green

if ($totalFiles -eq 0) {
    Write-Error "No Lucy JSON files found in $LucyDir"
    exit 1
}

# Verify database exists
if (!(Test-Path $DbPath)) {
    Write-Error "Database not found at: $DbPath"
    exit 1
}

# Initialize counters
$processedCount = 0
$successCount = 0
$errorCount = 0
$skippedCount = 0
$batchCount = 0

# Function to process a batch of files
function Process-Batch {
    param($Files, $BatchNumber)
    
    Write-Host "Processing batch $BatchNumber ($($Files.Count) files)..." -ForegroundColor Cyan
    
    $updates = @()
    
    foreach ($file in $Files) {
        try {
            # Extract item ID from filename
            if ($file.Name -match "lucy_item_(\d+)\.json") {
                $itemId = [int]$matches[1]
                
                # Read and parse JSON
                $content = Get-Content $file.FullName -Raw -ErrorAction Stop
                $data = $content | ConvertFrom-Json -ErrorAction Stop
                
                # Get questitem value (default to 0 if not present)
                $questItemValue = if ($data.questitem -ne $null) { [int]$data.questitem } else { 0 }
                
                $updates += @{
                    ItemId = $itemId
                    QuestItem = $questItemValue
                }
                
            } else {
                Write-Warning "Could not extract item ID from filename: $($file.Name)"
                $script:skippedCount++
            }
        }
        catch {
            Write-Error "Error processing $($file.Name): $($_.Exception.Message)"
            $script:errorCount++
        }
        
        $script:processedCount++
        
        # Progress update
        if ($script:processedCount % 1000 -eq 0) {
            $percentComplete = [math]::Round(($script:processedCount / $totalFiles) * 100, 2)
            Write-Progress -Activity "Processing Lucy Files" -Status "$script:processedCount of $totalFiles processed ($percentComplete%)" -PercentComplete $percentComplete
        }
    }
    
    # Execute batch database update
    if ($updates.Count -gt 0 -and !$DryRun) {
        try {
            Write-Host "Updating database with $($updates.Count) items..." -ForegroundColor Yellow
            
            # Prepare batch update
            $sql = "UPDATE raw_item_data SET questitem = @questitem WHERE id = @id"
            
            foreach ($update in $updates) {
                $result = Invoke-SqliteQuery -DataSource $DbPath -Query $sql -SqlParameters @{
                    questitem = $update.QuestItem
                    id = $update.ItemId
                } -ErrorAction Stop
                
                $script:successCount++
            }
            
            Write-Host "Batch $BatchNumber completed successfully" -ForegroundColor Green
        }
        catch {
            Write-Error "Database update error in batch $BatchNumber : $($_.Exception.Message)"
            $script:errorCount += $updates.Count
        }
    }
    elseif ($DryRun) {
        Write-Host "DRY RUN: Would update $($updates.Count) items in database" -ForegroundColor Yellow
        $script:successCount += $updates.Count
        
        # Show sample of what would be updated
        $updates | Select-Object -First 5 | ForEach-Object {
            Write-Host "  Item $($_.ItemId): questitem = $($_.QuestItem)"
        }
    }
}

# Process files in batches
Write-Host "Starting batch processing..." -ForegroundColor Green
$startTime = Get-Date

for ($i = 0; $i -lt $totalFiles; $i += $BatchSize) {
    $batchCount++
    $endIndex = [math]::Min($i + $BatchSize - 1, $totalFiles - 1)
    $batchFiles = $lucyFiles[$i..$endIndex]
    
    Process-Batch -Files $batchFiles -BatchNumber $batchCount
    
    # Show progress
    $percentComplete = [math]::Round((($i + $batchFiles.Count) / $totalFiles) * 100, 2)
    Write-Host "Progress: $percentComplete% complete" -ForegroundColor Cyan
}

# Final results
$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host "`n=== Batch Update Complete ===" -ForegroundColor Green
Write-Host "Total files processed: $processedCount"
Write-Host "Successful updates: $successCount"
Write-Host "Errors: $errorCount"
Write-Host "Skipped: $skippedCount"
Write-Host "Duration: $($duration.TotalMinutes.ToString('F2')) minutes"

# Verify results in database
if (!$DryRun) {
    Write-Host "`nVerifying database updates..." -ForegroundColor Cyan
    
    $questItemStats = Invoke-SqliteQuery -DataSource $DbPath -Query "
        SELECT 
            questitem,
            COUNT(*) as count 
        FROM raw_item_data 
        WHERE questitem IS NOT NULL 
        GROUP BY questitem 
        ORDER BY questitem"
    
    Write-Host "Database questitem statistics:"
    $questItemStats | Format-Table -AutoSize
    
    # Show some examples
    Write-Host "`nSample quest items (questitem = 1):"
    Invoke-SqliteQuery -DataSource $DbPath -Query "
        SELECT id, name, questitem 
        FROM raw_item_data 
        WHERE questitem = 1 
        LIMIT 10" | Format-Table -AutoSize
}

Write-Host "`nBatch update completed!" -ForegroundColor Green