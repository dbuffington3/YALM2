// lucy_scraper.js (CommonJS) with puppeteer-cluster

const fs = require('fs');
const path = require('path');
const { Cluster } = require('puppeteer-cluster');

// === CONFIG ===
const successDir = 'D:\\lucy';
const debugDir = 'D:\\lucy\\debug';
const failedListPath = path.join(debugDir, 'failed_items.txt');
const runLogPath = path.join(debugDir, 'run_log.txt');
const maxRetries = 5;
const minDelayMs = 50;
const maxDelayMs = 200;
const backoffMs = 5000;
const concurrency = 30; // Tune for your hardware/network
const taskTimeout = 10000; // 10 seconds max per item
const hangCheckInterval = 5000; // Check for hangs every 5 seconds

// === HELPERS ===

// === ITEMTYPE DECODER ===
function decodeItemType(itemTypeValue) {
  const itemTypeMap = {
    0: "1H Slashing",
    1: "2H Slashing",
    2: "1H Piercing",
    3: "1H Blunt",
    4: "2H Blunt",
    5: "Archery",
    7: "Throwing",
    8: "Shield",
    10: "Armor",
    11: "Tradeskill Item",
    12: "Lockpicking Tool",
    14: "Food",
    15: "Drink",
    16: "Light Source",
    17: "Inventory Item",
    18: "Bind Wound Item",
    19: "Thrown Casting Item",
    20: "Spell / Song Sheet",
    21: "Potion",
    22: "Fletched Arrow",
    23: "Wind Instrument",
    24: "Stringed Instrument",
    25: "Brass Instrument",
    26: "Percussion Instrument",
    27: "Ammo",
    29: "Jewelry",
    31: "Readable Note / Scroll",
    32: "Readable Book",
    33: "Key",
    34: "Odd Item",
    35: "2H Piercing",
    36: "Fishing Pole",
    37: "Fishing Bait",
    38: "Alcoholic Beverage",
    39: "Key (Alt)",
    40: "Compass",
    42: "Poison",
    45: "Hand to Hand",
    52: "Charm",
    53: "Dye",
    54: "Augment",
    55: "Augment Solvent",
    56: "Augment Distiller",
    58: "Fellowship Banner Material",
    60: "Cultural Armor Manual",
    63: "Currency (e.g. Orum)"
  };
  return itemTypeMap.hasOwnProperty(itemTypeValue) ? itemTypeMap[itemTypeValue] : "Unknown";
}

// === CLASS BITFIELD DECODER ===
function decodeClasses(classValue) {
  const classMap = {
    0: 'WAR',
    1: 'CLR',
    2: 'PAL',
    3: 'RNG',
    4: 'SHD',
    5: 'DRU',
    6: 'MNK',
    7: 'BRD',
    8: 'ROG',
    9: 'SHM',
    10: 'NEC',
    11: 'WIZ',
    12: 'MAG',
    13: 'ENC',
    14: 'BST',
    15: 'BER'
  };

  const result = [];

  for (let bit = 0; bit <= 15; bit++) {
    if ((classValue & (1 << bit)) !== 0) {
      result.push(classMap[bit]);
    }
  }

  return result.join(' ');
}


function ensureDir(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

function saveSuccess(itemId, jsonData) {
  ensureDir(successDir);
  const jsonPath = path.join(successDir, `lucy_item_${itemId}.json`);
  fs.writeFileSync(jsonPath, JSON.stringify(jsonData, null, 2), 'utf8');
  console.log(`✅ Saved JSON for ${itemId} -> ${jsonPath}`);
}

function saveFailure(itemId, prewaitHtml, screenshotBuffer, attempt) {
  ensureDir(debugDir);
  const htmlPath = path.join(debugDir, `lucy_item_${itemId}_prewait_attempt${attempt}.html`);
  fs.writeFileSync(htmlPath, prewaitHtml || '', 'utf8');
  console.warn(`⚠️  Saved prewait HTML for ${itemId} (attempt ${attempt}) -> ${htmlPath}`);

  if (screenshotBuffer) {
    const shotPath = path.join(debugDir, `lucy_item_${itemId}_fail_attempt${attempt}.png`);
    fs.writeFileSync(shotPath, screenshotBuffer);
    console.warn(`📸 Saved screenshot for ${itemId} (attempt ${attempt}) -> ${shotPath}`);
  }
}

function delay(ms) {
  return new Promise((res) => setTimeout(res, ms));
}

async function scrapeItem(page, itemId, itemName, itemUrl) {
  let jsonData = null;
  let prewaitHtml = '';
  let screenshotBuffer = null;
  let success = false;

  try {
    await page.goto(itemUrl, { waitUntil: 'networkidle2', timeout: 8000 }); // Reduced to 8s to fit within task timeout
    prewaitHtml = await page.content();
    
    // Wait for table with shorter timeout, handle gracefully if not found
    try {
      await page.waitForSelector('table.spellview', { timeout: 3000 }); // Reduced to 3s
    } catch (selectorErr) {
      console.warn(`⚠️  No table.spellview found for ${itemId}, attempting scrape anyway...`);
      // Don't throw - try to scrape anyway in case data exists in different format
    }

    jsonData = await page.evaluate((inputName, itemId) => {
      const table = document.querySelector('table.spellview');
      if (!table) return null;

      // Collect ALL fields from the table (completely raw - no processing)
      const allFields = {};
      const rows = Array.from(table.querySelectorAll('tr'));
      
      for (const row of rows) {
        const cells = Array.from(row.querySelectorAll('td'));
        
        // Handle 2-column rows
        if (cells.length === 2) {
          const key = cells[0].innerText.trim();
          const value = cells[1].innerText.trim();
          if (key) allFields[key] = value;
        }
        
        // Handle 4-column rows (two key-value pairs)
        if (cells.length === 4) {
          const key1 = cells[0].innerText.trim();
          const value1 = cells[1].innerText.trim();
          const key2 = cells[2].innerText.trim();
          const value2 = cells[3].innerText.trim();
          if (key1) allFields[key1] = value1;
          if (key2) allFields[key2] = value2;
        }
      }

      // Return completely raw data - no decoding, no parsing
      return {
        id: itemId,
        name: inputName,
        ...allFields
      };
    }, itemName, itemId);

    // Only mark success if we actually got data
    if (jsonData && Object.keys(jsonData).length > 2) {
      success = true;
    } else {
      console.warn(`⚠️  No data extracted for ${itemId}`);
    }
  } catch (err) {
    console.error(`❌ Error scraping ${itemId}: ${err && err.message ? err.message : String(err)}`);
    try {
      screenshotBuffer = await page.screenshot();
    } catch {
      // ignore screenshot errors
    }
  }

  return { success, jsonData, prewaitHtml, screenshotBuffer };
}

function parseCsvList(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  return content
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .map((line) => {
      // Split on commas not inside quotes
      const parts = line.split(/,(?=(?:(?:[^"]*"){2})*[^"]*$)/).map((s) => s.trim());
      const id = parts[0] ? parts[0].replace(/^"|"$/g, '') : '';
      const name = parts[1] ? parts[1].replace(/^"|"$/g, '') : '';
      const url = parts[2] ? parts[2].replace(/^"|"$/g, '') : '';
      return { id, name, url };
    });
}

function appendRunLog(summaryText) {
  ensureDir(debugDir);
  const timestamp = new Date().toISOString();
  const logEntry = `\n[${timestamp}]\n${summaryText}\n`;
  fs.appendFileSync(runLogPath, logEntry, 'utf8');
}


// === MAIN ===
(async () => {
  const listFile = process.argv[2];
  if (!listFile) {
    console.error('❌ Usage: node lucy_scraper.js <itemlist.txt>');
    process.exit(1);
  }

  ensureDir(successDir);
  ensureDir(debugDir);

  // Prefer previously failed items if present
  let items = [];
  if (fs.existsSync(failedListPath)) {
    console.log('📂 Detected previous failed_items.txt — processing those first...');
    items = parseCsvList(failedListPath);
  } else {
    items = parseCsvList(listFile);
  }

  // Append main list after failed list (avoid duplicates by ID)
  const mainItems = parseCsvList(listFile);
  const seenIds = new Set(items.map((i) => i.id));
  for (const mi of mainItems) {
    if (!seenIds.has(mi.id)) {
      items.push(mi);
    }
  }

  // Skip items that already have JSON files
  const filteredItems = items.filter((item) => {
    const jsonPath = path.join(successDir, `lucy_item_${item.id}.json`);
    return !fs.existsSync(jsonPath);
  });
  const skippedCount = items.length - filteredItems.length;

  console.log(`📊 Total items: ${items.length}`);
  console.log(`⏭️  Skipped (already exist): ${skippedCount}`);
  console.log(`🔄 To process: ${filteredItems.length}`);

  // Clear failed_items before run; collect new failures in-memory
  if (fs.existsSync(failedListPath)) {
    fs.unlinkSync(failedListPath);
  }
  const failedItems = [];

  // Counters
  let processedCount = 0;
  let failedCount = 0;
  let lastActivityTime = Date.now();
  let isProcessing = false;

  // Hang detection - if no activity for 15 seconds, something is wrong
  const hangChecker = setInterval(() => {
    if (isProcessing && (Date.now() - lastActivityTime > 15000)) {
      console.error('🚨 HANG DETECTED - No activity for 15 seconds! Forcing shutdown...');
      clearInterval(hangChecker);
      cluster.close().then(() => {
        console.error('❌ Cluster forcefully closed due to hang. Restart the script.');
        process.exit(1);
      }).catch(() => {
        console.error('❌ Failed to close cluster gracefully. Force exiting...');
        process.exit(1);
      });
    }
  }, hangCheckInterval);

  // Launch puppeteer-cluster
  const cluster = await Cluster.launch({
    concurrency: Cluster.CONCURRENCY_PAGE,
    maxConcurrency: concurrency,
    puppeteerOptions: { 
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--no-first-run',
        '--no-zygote',
        '--disable-gpu'
      ]
    },
    timeout: taskTimeout, // 10 seconds per task
    retryLimit: 0, // We'll handle retries manually
    monitor: false,
  });

  // Block unnecessary resources for speed
  await cluster.task(async ({ page, data }) => {
    lastActivityTime = Date.now(); // Update activity timestamp
    isProcessing = true;

    try {
      await page.setRequestInterception(true);
      page.on('request', (req) => {
        if (['image', 'stylesheet', 'font'].includes(req.resourceType())) {
          req.abort();
        } else {
          req.continue();
        }
      });

      const { id, name, url } = data;

      let attempt = 0;
      let done = false;

      while (attempt < maxRetries && !done) {
        attempt++;
        console.log(`🔍 Processing ${id} - ${name} (attempt ${attempt})...`);
        lastActivityTime = Date.now(); // Update activity timestamp

        try {
          const { success, jsonData, prewaitHtml, screenshotBuffer } = await scrapeItem(
            page,
            id,
            name,
            url
          );

          lastActivityTime = Date.now(); // Update activity timestamp after scrape

          if (success && jsonData) {
            saveSuccess(id, jsonData);
            processedCount++;
            done = true;
            console.log(`✅ Success: ${processedCount} items completed`);
          } else {
            saveFailure(id, prewaitHtml, screenshotBuffer, attempt);
            if (attempt < maxRetries) {
              console.log(`⏳ Retrying ${id} after backoff...`);
              await delay(backoffMs);
              lastActivityTime = Date.now(); // Update activity timestamp after delay
            }
          }
        } catch (scrapeErr) {
          console.error(`❌ Scrape attempt ${attempt} failed for ${id}: ${scrapeErr.message}`);
          lastActivityTime = Date.now(); // Update even on error
          
          if (attempt < maxRetries) {
            await delay(backoffMs);
            lastActivityTime = Date.now();
          }
        }
      }

      if (!done) {
        console.error(`❌ All ${maxRetries} attempts failed for ${id}`);
        failedItems.push({ id, name, url });
        failedCount++;
      }

      lastActivityTime = Date.now(); // Update activity timestamp

    } catch (err) {
      console.error(`❌ Task error for ${data.id}: ${err.message}`);
      failedItems.push({ id: data.id, name: data.name, url: data.url });
      failedCount++;
      lastActivityTime = Date.now(); // Update activity timestamp even on error
    }
  });

  // Queue only filtered items
  for (const item of filteredItems) {
    // Force the URL to use itemraw.html
    item.url = `https://lucy.allakhazam.com/itemraw.html?id=${item.id}`;
    cluster.queue(item);
  }

  console.log('⏳ Waiting for all tasks to complete...');
  await cluster.idle();
  await cluster.close();
  
  clearInterval(hangChecker); // Stop hang detection
  isProcessing = false;

  // Write failed_items.txt
  if (failedItems.length > 0) {
    const lines = failedItems.map((f) => `${f.id},"${f.name}",${f.url}`);
    fs.writeFileSync(failedListPath, lines.join('\n'), 'utf8');
    console.warn(`⚠️  ${failedItems.length} items failed. See: ${failedListPath}`);
  } else {
    console.log('🎉 No failures — all items processed successfully.');
  }

  // Summary table
  const summaryText = [
    '===== Run Summary =====',
    `Processed: ${processedCount}`,
    `Skipped:   ${skippedCount}`,
    `Failed:    ${failedCount}`,
    '=======================',
  ].join('\n');

  console.log('\n' + summaryText + '\n');

  // Append to run_log.txt
  appendRunLog(summaryText);

  console.log(`📄 Run summary appended to: ${runLogPath}`);
  console.log('🏁 All items processed.');
})().catch((err) => {
  console.error('❌ Fatal error:', err && err.stack ? err.stack : String(err));
  process.exit(1);
});