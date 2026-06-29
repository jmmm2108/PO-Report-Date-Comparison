# PO Report Comparison Tool

A browser-based tool that compares two **PO_ProjectHistoryReport** Excel files side-by-side and highlights every change — new POs, removed POs, and field-level differences — with no software installation required.

---

## What It Does

Upload an older and a newer `PO_ProjectHistoryReport .xlsx` export, click **Compare Files**, and instantly see:

- **New POs** added since the older report
- **Removed POs** no longer in the newer report
- **Changed POs** — every field that changed, shown as old → new values
- **Summary cards** with totals for each change type
- **Project-level breakdown** — changes grouped by project
- **Filter by project** to focus on a specific area
- **Export to Excel** — download the full comparison as a `.xlsx` file

Everything runs entirely in your browser. No data is uploaded to any server.

---

## Files

| File | Description |
|------|-------------|
| `index.html` | Main comparison tool — open this in your browser |
| `Download_PO_Files.bat` | Double-click to download the latest PO reports from SharePoint |
| `Download_PO_Files.ps1` | PowerShell script called by the .bat file |
| `PO_ProjectHistoryReport *.xlsx` | PO report exports (downloaded from SharePoint) |

---

## How to Use

### Option 1 — Load from OneDrive (Recommended)

If the SharePoint folder is synced to your computer via OneDrive:

1. Open `index.html` in your browser
2. Click **Choose folder…**
3. Navigate to your synced OneDrive folder:
   ```
   C:\Users\[you]\Retiina LLC\MARS (INTERNAL) - Procurement Project JM\PO Changes Analysis tool
   ```
4. Click **Select Folder**
5. The tool auto-populates both dropdowns — oldest file as **Older**, newest as **Newer**
6. Click **Compare Files**

### Option 2 — Download Files First (PowerShell Script)

If you don't have OneDrive sync set up:

1. Double-click **`Download_PO_Files.bat`**
2. Sign in with your Retiina Microsoft account when prompted (first time only)
3. The script downloads all `.xlsx` files from SharePoint to this folder
4. The tool opens automatically when the download completes
5. Click **Choose folder…**, select this folder, then **Compare Files**

### Option 3 — Manual Upload

1. Open `index.html` in your browser
2. Click **Click to choose file** under **Older File** and select the earlier report
3. Click **Click to choose file** under **Newer File** and select the later report
4. Click **Compare Files**

---

## Reading the Results

### Summary Cards

| Card | Meaning |
|------|---------|
| Changed | POs that exist in both files but have field differences |
| New | POs in the newer file that were not in the older file |
| Removed | POs in the older file that are no longer in the newer file |
| Unchanged | POs with no changes |

### Change Detail

Each changed PO shows exactly which fields changed:
- **Old value** highlighted in red
- **New value** highlighted in green

### Filter by Project

Use the **Filter by Project** dropdown at the top of the report to focus on a single project.

### Export to Excel

Click **Export to Excel** (top right of the report) to download a `.xlsx` file with the full comparison results.

---

## SharePoint Location

The PO report files and this tool are stored in:

```
MARS (INTERNAL) → Documents → SUPPLY CHAIN & PROCUREMENT
  → Procurement Project JM → PO Changes Analysis tool
```

**SharePoint URL:**
```
https://retiina.sharepoint.com/sites/MARS_INTERNAL/Shared%20Documents/
SUPPLY%20CHAIN%20%26%20PROCUREMENT/Procurement%20Project%20JM/PO%20Changes%20Analysis%20tool
```

---

## PowerShell Script Details (`Download_PO_Files.ps1`)

The script uses Microsoft's device code sign-in flow — no admin approval required.

**First run:**
1. A browser tab opens to `https://microsoft.com/devicelogin`
2. Enter the code shown in the terminal window
3. Sign in with your `@retiina.com` account
4. The script saves a token so you won't need to sign in again for ~90 days

**Subsequent runs:** Uses the cached token — no sign-in needed.

**What it downloads:** All `.xlsx` files in the SharePoint PO Changes Analysis tool folder.

---

## Supported File Format

The tool expects standard `PO_ProjectHistoryReport` exports with these key columns:

- `PurchaseOrderNo` — unique identifier used to match records between files
- `ItemCode` — used together with PO number as the comparison key

Any additional columns are automatically detected and compared.

> Files are matched using the `Query1` or `Sheet1` worksheet (whichever is present).

---

## Notes

- **No installation required** — the tool is a single `.html` file that runs in any modern browser (Chrome, Edge, Firefox)
- **No data leaves your computer** — all processing happens locally in the browser
- **File naming** — files with dates in the name (e.g. `06.16.26`) are auto-sorted oldest to newest in the dropdowns
