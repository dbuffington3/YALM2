#!/usr/bin/env powershell

<#
.SYNOPSIS
Import items from C:\Temp\itemcollect\items.txt into the production database
Only imports items that don't already exist (based on item ID)
Maps source columns to database columns by name
#>

$ErrorActionPreference = 'Stop'
$sqlite = 'c:\mq2\lua\yalm2\sqlite3.exe'
$db = 'C:\MQ2\resources\MQ2LinkDB.db'
$sourceFile = 'C:\Temp\itemcollect\items.txt'

Write-Host "=== Item Import Script ===" -ForegroundColor Cyan
Write-Host "Source: $sourceFile"
Write-Host "Target: $db"
Write-Host ""

# Read the source file header
$lines = @(Get-Content $sourceFile)
$sourceHeaders = $lines[0] -split '\|'

Write-Host "Source file has $($sourceHeaders.Count) columns"
Write-Host "Source file has $($lines.Count - 1) data rows"
Write-Host ""

# Get database columns
Write-Host "Reading database schema..." -ForegroundColor Yellow
$dbColumnsOutput = & $sqlite "$db" "PRAGMA table_info(raw_item_data);"
$dbColumns = @{}
foreach ($line in $dbColumnsOutput) {
    if ($line -match '^(\d+)\|([^|]+)\|') {
        $colIndex = [int]$matches[1]
        $colName = $matches[2]
        $dbColumns[$colName] = $colIndex
    }
}

Write-Host "Database has $($dbColumns.Count) columns"
Write-Host ""

# Find matching columns between source and database
$matchingColumns = @()
$matchingIndices = @()
for ($i = 0; $i -lt $sourceHeaders.Count; $i++) {
    $header = $sourceHeaders[$i]
    if ($dbColumns.ContainsKey($header)) {
        $matchingColumns += $header
        $matchingIndices += $i
    }
}

Write-Host "Found $($matchingColumns.Count) matching columns between source and database"
Write-Host ""

# Get existing IDs from database
Write-Host "Reading existing item IDs from database..." -ForegroundColor Yellow
$existingIds = & $sqlite "$db" "SELECT id FROM raw_item_data WHERE id > 0;"
$existingIdSet = @{}
foreach ($id in $existingIds) {
    if ($id -match '^\d+$') {
        $existingIdSet[$id] = $true
    }
}

Write-Host "Database contains $($existingIdSet.Count) items"
Write-Host ""

# Process data rows
$importCount = 0
$skipCount = 0
$errorCount = 0
$batchSize = 50
$batch = @()

Write-Host "Processing items..." -ForegroundColor Yellow

for ($i = 1; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    
    $fields = $line -split '\|', ($sourceHeaders.Count + 1)
    
    if ($fields.Count -lt $sourceHeaders.Count) {
        $skipCount++
        continue
    }
    
    # Column 'id' is at index 5 in the source file
    $itemId = if ($fields[5]) { $fields[5] } else { "" }
    
    # Skip if ID is empty or already exists
    if ([string]::IsNullOrWhiteSpace($itemId) -or $itemId -eq '0') {
        $skipCount++
        continue
    }
    
    if ($existingIdSet.ContainsKey($itemId)) {
        $skipCount++
        continue
    }
    
    # Build INSERT statement with proper escaping, using only matching columns
    $values = @()
    $cols = @()
    foreach ($idx in $matchingIndices) {
        $value = if ($idx -lt $fields.Count) { $fields[$idx] } else { "" }
        $cols += $sourceHeaders[$idx]
        
        # Escape single quotes by doubling them
        $value = $value -replace "'", "''"
        
        if ([string]::IsNullOrWhiteSpace($value)) {
            $values += "NULL"
        } else {
            $values += "'$value'"
        }
    }
    
    $columnNames = $cols -join ','
    $valueSql = $values -join ','
    
    $batch += @{
        id = $itemId
        name = if ([string]::IsNullOrWhiteSpace($fields[1])) { "Unknown" } else { $fields[1] }
        sql = "INSERT INTO raw_item_data ($columnNames) VALUES ($valueSql);"
    }
    
    $importCount++
    
    # Execute batch
    if ($batch.Count -ge $batchSize -or $i -eq $lines.Count - 1) {
        Write-Host "  Batch $([math]::Floor($i / $batchSize) + 1): Importing $($batch.Count) items..." -ForegroundColor Cyan
        
        foreach ($item in $batch) {
            try {
                & $sqlite "$db" $item.sql 2>&1 | Out-Null
                Write-Host "    ✓ ID:$($item.id) - $($item.name)" -ForegroundColor Green
            } catch {
                Write-Host "    ✗ Error ID:$($item.id) - $($item.name): $_" -ForegroundColor Red
                $errorCount++
            }
        }
        
        $batch = @()
    }
    
    if ($i % 1000 -eq 0) {
        Write-Host "  ... processed $i rows ($importCount to import)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "=== Import Complete ===" -ForegroundColor Cyan
Write-Host "To Import: $importCount items"
Write-Host "Skipped:   $skipCount items (already in DB or empty ID)"
Write-Host "Errors:    $errorCount items"
Write-Host ""

# Verify some imported items
Write-Host "Verifying import..." -ForegroundColor Yellow
$totalItems = & $sqlite "$db" "SELECT COUNT(*) FROM raw_item_data;"
Write-Host "Total items in database: $totalItems"

$newItems = & $sqlite "$db" "SELECT COUNT(*) FROM raw_item_data WHERE created IS NOT NULL AND created != '';"
Write-Host "Items imported from source: $newItems"

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
