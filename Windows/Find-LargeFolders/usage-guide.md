# Find-LargeFolders — Usage Guide

`Find-LargeFolders.ps1` scans a drive or folder and lists the top N largest immediate subfolders
(size in GB and item count), followed by the top 10 largest individual files — handy for reclaiming
disk space. See the root [`README.md`](../../README.md) for where this fits in the repository.

---

## Prerequisites

| Requirement | Notes |
| --- | --- |
| **Windows with PowerShell 5.1+** | Ships with Windows 10/11. |
| **Administrator rights** *(recommended)* | Run as Administrator for full access to system folders; otherwise inaccessible paths are skipped with a warning. |

---

## Running

```powershell
.\Find-LargeFolders.ps1                          # scan C:\, show top 20
.\Find-LargeFolders.ps1 -Path "D:\" -Top 30      # scan D:\, show top 30
.\Find-LargeFolders.ps1 -Path "C:\" -MinSizeGB 5 # only folders larger than 5 GB
```

If PowerShell blocks the script, allow it for the current session only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

---

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `-Path` | `C:\` | Root path to analyze. |
| `-Top` | `20` | Number of largest folders to display. |
| `-MinSizeGB` | `0` | Only show folders larger than this size (GB). |

---

## Output

1. A table of the top N largest immediate subfolders under `-Path`, showing **Size (GB)**, the
   folder path, and its recursive **item count**.
2. A **Top 10 Largest Files** table (size in GB + full path) to spot single large files worth
   removing.

> **Note:** Scanning a large drive can take several minutes because folder sizes are computed
> recursively. Inaccessible folders (permission denied) are skipped and reported as warnings rather
> than aborting the scan.
