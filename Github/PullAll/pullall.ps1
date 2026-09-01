<#
.SYNOPSIS
    Sync every sibling git repo's `main` branch (mirrors the /pullall Cursor command).

.DESCRIPTION
    For each immediate child folder of -Root that is a git repository:
      1. Records the current branch.
      2. Fetches with --prune (so branches deleted upstream are detected).
      3. Checks out `main` (if not already on it).
      4. Pulls `main` with --ff-only (fast-forward only -- never rebases, never
         creates a merge commit).
      5. Switches back to the original branch ONLY if that branch still exists
         upstream (origin/<branch>). If the branch is not on origin, it stays on
         `main` (no switch-back), per requirement.

    Never runs destructive commands (no reset --hard, checkout -f, or clean).
    If a repo has a dirty tree / conflict / diverged history, it is reported as
    "Needs attention" and the script keeps going with the rest.

.PARAMETER Root
    Folder whose child directories are scanned. Defaults to the folder this
    script lives in.

.PARAMETER MainBranch
    Name of the primary branch to pull. Defaults to 'main'.

.PARAMETER Parallel
    Process repos in parallel (requires PowerShell 7+; falls back to sequential
    on Windows PowerShell 5.1).

.EXAMPLE
    .\pullall.ps1

.EXAMPLE
    .\pullall.ps1 -Parallel
#>
[CmdletBinding()]
param(
    [string]$Root = $PSScriptRoot,
    [string]$MainBranch = 'main',
    [switch]$Parallel
)

# --- Core per-repo sync logic (kept as a scriptblock so it can run in both the
#     sequential path and the parallel runspaces) ---------------------------------
$repoScript = {
    param([string]$Path, [string]$MainBranch)

    $name = Split-Path $Path -Leaf
    $sw   = [System.Diagnostics.Stopwatch]::StartNew()

    # Progress logger: timestamp + repo name, written to the host (does not pollute
    # the object output stream that builds the summary table).
    function Log($msg, $color = 'Gray') {
        Write-Host ("[{0}] {1,-15} {2}" -f (Get-Date).ToString('HH:mm:ss'), $name, $msg) -ForegroundColor $color
    }
    function New-Result($status, $detail) {
        $color = switch ($status) {
            'Updated'            { 'Green' }
            'Already up to date' { 'DarkGray' }
            'Needs attention'    { 'Red' }
            default              { 'Gray' }
        }
        Log ("DONE ({0:n1}s): {1} - {2}" -f $sw.Elapsed.TotalSeconds, $status, $detail) $color
        [pscustomobject]@{ Repo = $name; Status = $status; Detail = $detail }
    }

    # Is this actually a git work tree?
    git -C $Path rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Log "skipped (not a git repo)" 'DarkGray'; return }

    $orig = git -C $Path rev-parse --abbrev-ref HEAD 2>$null
    if (-not $orig) { return New-Result 'Needs attention' 'Could not read current branch' }
    $orig = $orig.Trim()
    if ($orig -eq 'HEAD') { return New-Result 'Needs attention' 'Detached HEAD - skipped' }

    Log ("START - current branch '{0}'" -f $orig) 'Cyan'

    # Fetch first (prune) so we can tell whether the original branch still exists upstream.
    Log "fetching (--prune)..."
    $fetchOut = git -C $Path fetch --prune 2>&1
    if ($LASTEXITCODE -ne 0) {
        return New-Result 'Needs attention' ("fetch failed: {0}" -f ($fetchOut -join ' '))
    }

    # Switch to main if we're not already there.
    $switched = $false
    if ($orig -ne $MainBranch) {
        Log ("on '{0}' -> checking out '{1}'..." -f $orig, $MainBranch)
        git -C $Path checkout $MainBranch 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            return New-Result 'Needs attention' ("cannot checkout {0} (uncommitted changes/conflict); left on '{1}'" -f $MainBranch, $orig)
        }
        $switched = $true
    }
    else {
        Log "already on '$MainBranch'"
    }

    # Fast-forward-only pull of main.
    Log ("pulling '{0}' (--ff-only)..." -f $MainBranch)
    $before  = (git -C $Path rev-parse HEAD).Trim()
    $pullOut = git -C $Path pull --ff-only 2>&1
    $pullOk  = ($LASTEXITCODE -eq 0)
    $after   = (git -C $Path rev-parse HEAD).Trim()
    if ($pullOk) {
        if ($before -eq $after) { Log "  main already up to date" }
        else { Log ("  main advanced {0}..{1}" -f $before.Substring(0,7), $after.Substring(0,7)) 'Green' }
    }

    # Decide whether to switch back to the original branch.
    $backNote = ''
    if ($switched) {
        git -C $Path show-ref --verify --quiet "refs/remotes/origin/$orig"
        $upstreamExists = ($LASTEXITCODE -eq 0)
        if ($upstreamExists) {
            Log ("switching back to '{0}'..." -f $orig)
            git -C $Path checkout $orig 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                return New-Result 'Needs attention' ("pulled {0} but could not switch back to '{1}'" -f $MainBranch, $orig)
            }
            $backNote = "; restored to '$orig'"
        }
        else {
            Log ("'{0}' not on origin -> staying on '{1}'" -f $orig, $MainBranch) 'Yellow'
            $backNote = "; '$orig' not on origin, staying on $MainBranch"
        }
    }

    if (-not $pullOk) {
        return New-Result 'Needs attention' ("pull --ff-only failed on {0}: {1}{2}" -f $MainBranch, ($pullOut -join ' '), $backNote)
    }

    if ($before -eq $after) {
        return New-Result 'Already up to date' ("on $MainBranch" + $backNote)
    }
    else {
        $files = (git -C $Path diff --name-only $before $after | Measure-Object).Count
        $range = "{0}..{1}" -f $before.Substring(0, 7), $after.Substring(0, 7)
        return New-Result 'Updated' ("$range, $files file(s)$backNote")
    }
}

# --- Discover sibling repos --------------------------------------------------------
if (-not $Root) { $Root = (Get-Location).Path }
$Root = (Resolve-Path $Root).Path

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git was not found on PATH."
    exit 1
}

$repoDirs = Get-ChildItem -LiteralPath $Root -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName '.git') }

if (-not $repoDirs) {
    Write-Host "No git repositories found under $Root" -ForegroundColor Yellow
    exit 0
}

$mode = if ($Parallel -and $PSVersionTable.PSVersion.Major -ge 7) { 'parallel' }
        elseif ($Parallel) { 'sequential (PS 5.1 - -Parallel needs PS7+)' }
        else { 'sequential' }

$overall = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host ''
Write-Host ("=== pullall: {0} repo(s) under {1}  [{2}]  main='{3}' ===" -f $repoDirs.Count, $Root, $mode, $MainBranch) -ForegroundColor Cyan
Write-Host ("Repos: {0}" -f (($repoDirs | Select-Object -ExpandProperty Name) -join ', ')) -ForegroundColor DarkGray
Write-Host ''

# --- Run ---------------------------------------------------------------------------
if ($Parallel -and $PSVersionTable.PSVersion.Major -ge 7) {
    $repoScriptText = $repoScript.ToString()
    $total = $repoDirs.Count
    $results = $repoDirs | ForEach-Object -ThrottleLimit 8 -Parallel {
        $sb = [ScriptBlock]::Create($using:repoScriptText)
        & $sb $_.FullName $using:MainBranch
    }
}
else {
    $total = $repoDirs.Count
    $i = 0
    $results = foreach ($dir in $repoDirs) {
        $i++
        Write-Host ("--- ({0}/{1}) {2} ---" -f $i, $total, $dir.Name) -ForegroundColor White
        & $repoScript $dir.FullName $MainBranch
        Write-Host ("    ...{0}/{1} repos processed" -f $i, $total) -ForegroundColor DarkGray
    }
}

# --- Report ------------------------------------------------------------------------
$results = $results | Sort-Object Repo
Write-Host ''
$results | Format-Table Repo, Status, Detail -AutoSize -Wrap

$attention = @($results | Where-Object Status -eq 'Needs attention')
$overall.Stop()
Write-Host ''
Write-Host ("Done in {0:n1}s. Updated: {1} | Up to date: {2} | Needs attention: {3}" -f `
    $overall.Elapsed.TotalSeconds,
    @($results | Where-Object Status -eq 'Updated').Count,
    @($results | Where-Object Status -eq 'Already up to date').Count,
    $attention.Count) -ForegroundColor Cyan

if ($attention.Count -gt 0) { exit 1 } else { exit 0 }
