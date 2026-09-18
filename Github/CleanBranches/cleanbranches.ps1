<#
.SYNOPSIS
    Delete stale local branches in every sibling git repo (companion to pullall.ps1).

.DESCRIPTION
    For each immediate child folder of -Root that is a git repository:
      1. Fetches with --prune (so branches deleted upstream are detected).
      2. Classifies every local branch:
           - Protected           : main branch, current branch, or matches -Keep.
           - Merged              : already merged into origin/<main> (safe `git branch -d`).
           - Gone                : had an upstream that no longer exists on origin
                                   (typically squash-merged & deleted PR branches).
           - Active              : upstream still exists on origin -> kept.
           - Local-only unmerged : no upstream, unmerged work -> kept unless
                                   -IncludeUnmerged is given.
      3. Deletes the Merged + Gone branches (and local-only ones with
         -IncludeUnmerged).

    DRY RUN BY DEFAULT: nothing is deleted unless you pass -Apply.
    Deleted SHAs are printed so anything removed can be recovered with
    `git checkout -b <name> <sha>` (the commits stay in the reflog for ~90 days).

    Never touches the working tree (no reset, checkout -f, or clean). The current
    branch is never deleted; use -SwitchToMain to park the repo on main first so a
    stale current branch becomes eligible.

.PARAMETER Root
    Folder whose child directories are scanned. Defaults to the folder this
    script lives in.

.PARAMETER MainBranch
    Name of the primary branch used as the merge base. Defaults to 'main'.

.PARAMETER Keep
    Wildcard patterns for branches that must never be deleted.
    Defaults to master/develop/dev/release-*/hotfix-* style branches.

.PARAMETER IncludeUnmerged
    Also delete local-only branches (no upstream) that are NOT merged into main.
    This is the only option that can lose work that was never pushed.

.PARAMETER SwitchToMain
    Check out the main branch first (only if the tree is clean) so the branch you
    happen to be standing on can also be cleaned.

.PARAMETER Apply
    Actually delete. Without this the script only reports what it would do.

.PARAMETER Parallel
    Process repos in parallel (requires PowerShell 7+; falls back to sequential
    on Windows PowerShell 5.1).

.EXAMPLE
    .\cleanbranches.ps1
    Dry run - show what would be deleted in every repo.

.EXAMPLE
    .\cleanbranches.ps1 -Apply
    Delete merged and gone-upstream branches.

.EXAMPLE
    .\cleanbranches.ps1 -SwitchToMain -IncludeUnmerged -Apply
    Aggressive cleanup: park each repo on main and also drop unpushed local branches.
#>
[CmdletBinding()]
param(
    [string]$Root = $PSScriptRoot,
    [string]$MainBranch = 'main',
    [string[]]$Keep = @('master', 'develop', 'dev', 'release/*', 'release-*', 'hotfix/*', 'hotfix-*'),
    [switch]$IncludeUnmerged,
    [switch]$SwitchToMain,
    [switch]$Apply,
    [switch]$Parallel
)

# --- Core per-repo cleanup logic (scriptblock so it can run in both the
#     sequential path and the parallel runspaces) ---------------------------------
$repoScript = {
    param(
        [string]$Path,
        [string]$MainBranch,
        [string[]]$Keep,
        [bool]$IncludeUnmerged,
        [bool]$SwitchToMain,
        [bool]$Apply
    )

    $name = Split-Path $Path -Leaf
    $sw   = [System.Diagnostics.Stopwatch]::StartNew()

    function Log($msg, $color = 'Gray') {
        Write-Host ("[{0}] {1,-15} {2}" -f (Get-Date).ToString('HH:mm:ss'), $name, $msg) -ForegroundColor $color
    }
    function New-Result($status, $deleted, $kept, $detail) {
        $color = switch ($status) {
            'Deleted'          { 'Green' }
            'Would delete'     { 'Yellow' }
            'Nothing to clean' { 'DarkGray' }
            'Needs attention'  { 'Red' }
            default            { 'Gray' }
        }
        Log ("DONE ({0:n1}s): {1} - {2}" -f $sw.Elapsed.TotalSeconds, $status, $detail) $color
        [pscustomobject]@{ Repo = $name; Status = $status; Deleted = $deleted; Kept = $kept; Detail = $detail }
    }

    # Is this actually a git work tree?
    git -C $Path rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Log "skipped (not a git repo)" 'DarkGray'; return }

    $current = git -C $Path rev-parse --abbrev-ref HEAD 2>$null
    if (-not $current) { return New-Result 'Needs attention' 0 0 'Could not read current branch' }
    $current = $current.Trim()
    if ($current -eq 'HEAD') { return New-Result 'Needs attention' 0 0 'Detached HEAD - skipped' }

    Log ("START - current branch '{0}'" -f $current) 'Cyan'

    Log "fetching (--prune)..."
    $fetchOut = git -C $Path fetch --prune 2>&1
    if ($LASTEXITCODE -ne 0) {
        return New-Result 'Needs attention' 0 0 ("fetch failed: {0}" -f ($fetchOut -join ' '))
    }

    # Optionally park on main so the current branch becomes eligible for deletion.
    $parkNote = ''
    if ($SwitchToMain -and $current -ne $MainBranch) {
        $dirty = git -C $Path status --porcelain
        if ($dirty) {
            Log ("uncommitted changes -> staying on '{0}'" -f $current) 'Yellow'
            $parkNote = "; dirty tree, stayed on '$current'"
        }
        else {
            Log ("checking out '{0}'..." -f $MainBranch)
            git -C $Path checkout $MainBranch 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { $current = $MainBranch }
            else {
                Log ("cannot checkout '{0}' -> staying on '{1}'" -f $MainBranch, $current) 'Yellow'
                $parkNote = "; could not checkout $MainBranch"
            }
        }
    }

    # Merge base: prefer origin/<main> (freshly fetched) over the local copy.
    $baseRef = $null
    git -C $Path show-ref --verify --quiet "refs/remotes/origin/$MainBranch"
    if ($LASTEXITCODE -eq 0) { $baseRef = "origin/$MainBranch" }
    else {
        git -C $Path show-ref --verify --quiet "refs/heads/$MainBranch"
        if ($LASTEXITCODE -eq 0) { $baseRef = $MainBranch }
    }
    if (-not $baseRef) {
        return New-Result 'Needs attention' 0 0 ("no '{0}' branch locally or on origin{1}" -f $MainBranch, $parkNote)
    }

    # Branches already merged into the base.
    $merged = @{}
    foreach ($m in (git -C $Path branch --merged $baseRef --format='%(refname:short)')) {
        if ($m) { $merged[$m.Trim()] = $true }
    }

    $protectedPatterns = @($Keep) + @($MainBranch, $current)

    $toDelete = @()   # @{ Name; Sha; Reason; Force }
    $keptCount = 0

    foreach ($line in (git -C $Path for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)' refs/heads)) {
        if (-not $line) { continue }
        $parts    = $line -split '\|', 3
        $branch   = $parts[0]
        $upstream = if ($parts.Count -gt 1) { $parts[1] } else { '' }
        $track    = if ($parts.Count -gt 2) { $parts[2] } else { '' }

        $isProtected = $false
        foreach ($p in $protectedPatterns) { if ($branch -like $p) { $isProtected = $true; break } }
        if ($isProtected) { $keptCount++; continue }

        $sha    = (git -C $Path rev-parse --short $branch).Trim()
        $isGone = $track -match '\[gone\]'

        if ($merged.ContainsKey($branch)) {
            $toDelete += @{ Name = $branch; Sha = $sha; Reason = "merged into $baseRef"; Force = $false }
        }
        elseif ($isGone) {
            $toDelete += @{ Name = $branch; Sha = $sha; Reason = 'upstream gone'; Force = $true }
        }
        elseif (-not $upstream -and $IncludeUnmerged) {
            $toDelete += @{ Name = $branch; Sha = $sha; Reason = 'local-only, unmerged'; Force = $true }
        }
        else {
            $keptCount++
        }
    }

    if ($toDelete.Count -eq 0) {
        return New-Result 'Nothing to clean' 0 $keptCount ("{0} branch(es) kept{1}" -f $keptCount, $parkNote)
    }

    if (-not $Apply) {
        foreach ($b in $toDelete) {
            Log ("  would delete {0} ({1}, {2})" -f $b.Name, $b.Sha, $b.Reason) 'Yellow'
        }
        return New-Result 'Would delete' $toDelete.Count $keptCount `
            ("{0}{1}" -f (($toDelete | ForEach-Object { "$($_.Name) [$($_.Reason)]" }) -join ', '), $parkNote)
    }

    $done   = @()
    $failed = @()
    foreach ($b in $toDelete) {
        $flag = if ($b.Force) { '-D' } else { '-d' }
        $out  = git -C $Path branch $flag $b.Name 2>&1
        if ($LASTEXITCODE -eq 0) {
            Log ("  deleted {0} ({1}, {2}) - restore: git checkout -b {0} {1}" -f $b.Name, $b.Sha, $b.Reason) 'Green'
            $done += "$($b.Name)@$($b.Sha)"
        }
        else {
            Log ("  FAILED {0}: {1}" -f $b.Name, ($out -join ' ')) 'Red'
            $failed += $b.Name
            $keptCount++
        }
    }

    if ($failed.Count -gt 0) {
        return New-Result 'Needs attention' $done.Count $keptCount `
            ("deleted {0}; failed: {1}{2}" -f $done.Count, ($failed -join ', '), $parkNote)
    }

    return New-Result 'Deleted' $done.Count $keptCount ("{0}{1}" -f ($done -join ', '), $parkNote)
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

$runMode = if ($Apply) { 'APPLY (branches will be deleted)' } else { 'DRY RUN (use -Apply to delete)' }

$overall = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host ''
Write-Host ("=== cleanbranches: {0} repo(s) under {1}  [{2}]  main='{3}' ===" -f $repoDirs.Count, $Root, $mode, $MainBranch) -ForegroundColor Cyan
Write-Host ("Mode: {0}" -f $runMode) -ForegroundColor $(if ($Apply) { 'Yellow' } else { 'DarkGray' })
Write-Host ("Keep: {0} | IncludeUnmerged: {1} | SwitchToMain: {2}" -f ($Keep -join ', '), [bool]$IncludeUnmerged, [bool]$SwitchToMain) -ForegroundColor DarkGray
Write-Host ("Repos: {0}" -f (($repoDirs | Select-Object -ExpandProperty Name) -join ', ')) -ForegroundColor DarkGray
Write-Host ''

# --- Run ---------------------------------------------------------------------------
if ($Parallel -and $PSVersionTable.PSVersion.Major -ge 7) {
    $repoScriptText = $repoScript.ToString()
    $results = $repoDirs | ForEach-Object -ThrottleLimit 8 -Parallel {
        $sb = [ScriptBlock]::Create($using:repoScriptText)
        & $sb $_.FullName $using:MainBranch $using:Keep ([bool]$using:IncludeUnmerged) ([bool]$using:SwitchToMain) ([bool]$using:Apply)
    }
}
else {
    $total = $repoDirs.Count
    $i = 0
    $results = foreach ($dir in $repoDirs) {
        $i++
        Write-Host ("--- ({0}/{1}) {2} ---" -f $i, $total, $dir.Name) -ForegroundColor White
        & $repoScript $dir.FullName $MainBranch $Keep ([bool]$IncludeUnmerged) ([bool]$SwitchToMain) ([bool]$Apply)
        Write-Host ("    ...{0}/{1} repos processed" -f $i, $total) -ForegroundColor DarkGray
    }
}

# --- Report ------------------------------------------------------------------------
$results = $results | Sort-Object Repo
Write-Host ''
$results | Format-Table Repo, Status, Deleted, Kept, Detail -AutoSize -Wrap

$attention   = @($results | Where-Object Status -eq 'Needs attention')
$totalDelete = ($results | Measure-Object -Property Deleted -Sum).Sum
$overall.Stop()
Write-Host ''
if ($Apply) {
    Write-Host ("Done in {0:n1}s. Deleted: {1} branch(es) | Repos cleaned: {2} | Needs attention: {3}" -f `
        $overall.Elapsed.TotalSeconds,
        $totalDelete,
        @($results | Where-Object Status -eq 'Deleted').Count,
        $attention.Count) -ForegroundColor Cyan
}
else {
    Write-Host ("Done in {0:n1}s. Would delete: {1} branch(es) across {2} repo(s) | Needs attention: {3}" -f `
        $overall.Elapsed.TotalSeconds,
        $totalDelete,
        @($results | Where-Object Status -eq 'Would delete').Count,
        $attention.Count) -ForegroundColor Cyan
    Write-Host "Re-run with -Apply to actually delete." -ForegroundColor Yellow
}

if ($attention.Count -gt 0) { exit 1 } else { exit 0 }
