# productivity-tools

A small collection of utility scripts and tools for quick system and database management tasks.
Items are grouped by domain: MongoDB maintenance helpers and Windows desktop/disk tooling.

## Repository layout

```
MongoDb/
  db-usage.js       # Inspect MongoDB namespace/collection usage (Node.js)
  db-migration.txt  # Cheat sheet for migrating a database between clusters
  md-to-html.mjs    # Convert a Markdown file to a styled, print-ready HTML page
  usage-guide.md    # How to use the MongoDb helpers
Windows/
  Find-LargeFolders/
    Find-LargeFolders.ps1  # Report the largest folders and files on a drive (PowerShell)
    usage-guide.md         # How to run Find-LargeFolders
  PresentationNarrator/
    usage-guide.md         # Turn slide decks into narrated, subtitled videos
  ScreenRecorder/
    usage-guide.md         # Tray-based Windows screen recorder
```

---

## MongoDb

> Full walkthrough: [`MongoDb/usage-guide.md`](MongoDb/usage-guide.md).

### `db-usage.js`

Scans every non-system database on a MongoDB/Atlas cluster and reports namespace usage. This is aimed at the Atlas shared-tier limit of **500 namespaces** (each collection *plus* each index counts as one namespace), which surfaces as the error `cannot create a new collection -- already using 501 collections of 500`.

For every collection it reports document count, data size, index count, total index size, last write activity, and whether the collection is **EMPTY** (0 docs) or **STALE** (no writes within `--stale-days`). It then prints cluster-wide namespace usage against the 500 cap so you can see how much room can be reclaimed.

**Read-only by default.** The `--drop-empty` flag can DROP zero-document collections to reclaim namespaces; because that is destructive it lists the targets and only proceeds when `--yes` is also passed.

Requires a project-local connection helper at `src/infrastructure/mongodb/connection.js` (exporting `connectMongo`, `disconnectMongo`, and `mongoose`). The script is intended to run from a project's `scripts/` directory.

**Usage**

```bash
node scripts/db-usage.js                    # report only (all databases)
node scripts/db-usage.js --stale-days=30    # flag collections idle > 30 days
node scripts/db-usage.js --json             # machine-readable output
node scripts/db-usage.js --drop-empty       # preview which empty collections would be dropped
node scripts/db-usage.js --drop-empty --yes # actually drop empty collections (destructive)
```

**Options**

| Flag | Default | Description |
| --- | --- | --- |
| `--stale-days=N` | `90` | Number of idle days after which a non-empty collection is flagged STALE. |
| `--json` | off | Emit machine-readable JSON instead of formatted tables. |
| `--drop-empty` | off | Target zero-document collections for dropping (preview unless `--yes`). |
| `--yes` | off | Confirm and actually perform the drop. |

### `db-migration.txt`

A command cheat sheet for migrating a database (example db name `lmsdb`) from one cluster to another using `mongodump`/`mongorestore`, then re-pointing the app, recreating indexes, and redeploying. Replace `<OLD_MONGODB_URI>` and `<NEW_MONGODB_URI>` before running.

### `md-to-html.mjs`

Converts a Markdown file into a single, self-contained HTML document with embedded print-friendly (A4) styling — useful for generating clean PDFs from Markdown via a browser's Print dialog. Uses the [`marked`](https://www.npmjs.com/package/marked) library with GitHub-Flavored Markdown enabled.

**Prerequisite**

```bash
npm install marked
```

**Usage**

```bash
node md-to-html.mjs <input.md> <output.html>
```

The document `<title>` is derived from the input file name.

---

## Windows

### `Find-LargeFolders`

> Full walkthrough: [`Windows/Find-LargeFolders/usage-guide.md`](Windows/Find-LargeFolders/usage-guide.md).

Scans a drive or folder and lists the top N largest immediate subfolders (size in GB and item count), followed by the top 10 largest individual files — handy for reclaiming disk space. Run as Administrator for full access to system folders.

**Usage**

```powershell
.\Find-LargeFolders.ps1                          # scan C:\, show top 20
.\Find-LargeFolders.ps1 -Path "D:\" -Top 30      # scan D:\, show top 30
.\Find-LargeFolders.ps1 -Path "C:\" -MinSizeGB 5 # only folders larger than 5 GB
```

**Parameters**

| Parameter | Default | Description |
| --- | --- | --- |
| `-Path` | `C:\` | Root path to analyze. |
| `-Top` | `20` | Number of largest folders to display. |
| `-MinSizeGB` | `0` | Only show folders larger than this size (GB). |

> Scanning a large drive can take several minutes. If PowerShell blocks the script, allow it for the current session with:
> ```powershell
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> ```

### `PresentationNarrator`

> Full walkthrough: [`Windows/PresentationNarrator/usage-guide.md`](Windows/PresentationNarrator/usage-guide.md).

A Windows (WinForms) app that turns a slide deck (PowerPoint / PDF / HTML) into a narrated,
subtitled MP4. It imports slides, prefills narration from PPTX speaker notes, synthesizes speech
(offline Windows voice or cloud providers: OpenAI / ElevenLabs / Amazon Polly), burns in synced
subtitles, and exports a stitched video. Requires FFmpeg (a full/GPL build with libass).

### `ScreenRecorder`

> Full walkthrough: [`Windows/ScreenRecorder/usage-guide.md`](Windows/ScreenRecorder/usage-guide.md).

A lightweight, tray-based Windows screen recorder. Capture the full screen, a region, or a specific
window with optional system and/or microphone audio, take screenshots, and losslessly stitch
segments into a single video. Controlled from the system tray and global hotkeys; requires FFmpeg
(a full/GPL build recommended).

---

## Requirements

- **Node.js** (for `db-usage.js` and `md-to-html.mjs`) — ES modules are used, so Node 14+.
- **MongoDB Database Tools** (`mongodump`, `mongorestore`) for the migration steps.
- **PowerShell 5.1+** on Windows for `Find-LargeFolders.ps1`.
- **Windows 10/11 + FFmpeg** (full/GPL build) for `PresentationNarrator` and `ScreenRecorder`.
