<#
.SYNOPSIS
    Finds the largest folders by size on Windows 11.

.DESCRIPTION
    Scans a drive/folder and shows the top N largest subfolders with their sizes in GB.
    Run as Administrator for best results (access to system folders).

.PARAMETER Path
    The root path to analyze (default: C:\)

.PARAMETER Top
    Number of largest folders to display (default: 20)

.PARAMETER MinSizeGB
    Only show folders larger than this size (default: 0)

.EXAMPLE
    .\Find-LargeFolders.ps1 -Path "C:\" -Top 30
#>

param(
    [string]$Path = "C:\",
    [int]$Top = 20,
    [double]$MinSizeGB = 0
)

# Function to calculate folder size recursively
function Get-FolderSize {
    param([string]$FolderPath)

    try {
        $size = (Get-ChildItem -Path $FolderPath -Recurse -File -Force -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum).Sum
        return [math]::Round($size / 1GB, 2)
    }
    catch {
        Write-Warning "Access denied or error accessing: $FolderPath"
        return 0
    }
}

Write-Host "Scanning $Path for large folders... This may take several minutes on a 1TB drive." -ForegroundColor Cyan

# Get immediate subfolders (top level under the chosen path)
$folders = Get-ChildItem -Path $Path -Directory -Force -ErrorAction SilentlyContinue

$folderSizes = @()

foreach ($folder in $folders) {
    $sizeGB = Get-FolderSize -FolderPath $folder.FullName

    if ($sizeGB -ge $MinSizeGB) {
        $folderSizes += [PSCustomObject]@{
            Folder    = $folder.FullName
            SizeGB    = $sizeGB
            ItemCount = (Get-ChildItem -Path $folder.FullName -Recurse -Force -ErrorAction SilentlyContinue).Count
        }
    }
}

# Sort and display top results
$topFolders = $folderSizes | Sort-Object SizeGB -Descending | Select-Object -First $Top

if ($topFolders.Count -eq 0) {
    Write-Host "No folders found matching criteria." -ForegroundColor Yellow
} else {
    Write-Host "`nTop $Top largest folders in $Path`n" -ForegroundColor Green
    $topFolders | Format-Table -AutoSize -Property @{
        Label = "Size (GB)"; Expression = { "{0:N2}" -f $_.SizeGB }; Alignment = "Right"
    }, Folder, ItemCount
}

# Bonus: Also show the largest individual files (very useful)
Write-Host "`n=== Top 10 Largest Files (helpful for cleanup) ===" -ForegroundColor Cyan
Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending |
    Select-Object -First 10 |
    Select-Object @{Name='Size(GB)';Expression={[math]::Round($_.Length/1GB,3)}}, FullName |
    Format-Table -AutoSize