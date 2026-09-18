# CleanBranches — Usage Guide

`cleanbranches.ps1` deletes stale **local** branches in every git repository that sits directly under
a root folder. It is the companion to [`pullall.ps1`](../PullAll/usage-guide.md): pull everything
first, then clean up the branches that are no longer needed. See the root
[`README.md`](../../README.md) for where this fits in the repository.

**Dry run by default** — nothing is deleted unless you pass `-Apply`.

---

## What it does per repo

1. Fetches with `--prune` (so branches deleted upstream are detected).
2. Classifies every local branch:

   | Class | Meaning | Action |
   | --- | --- | --- |
   | **Protected** | The main branch, the current branch, or a match for `-Keep`. | Kept |
   | **Merged** | Already merged into `origin/<main>`. | Deleted (`git branch -d`) |
   | **Gone** | Had an upstream that no longer exists on `origin` — typically a squash-merged, deleted PR branch. | Deleted (`git branch -D`) |
   | **Active** | Upstream still exists on `origin`. | Kept |
   | **Local-only unmerged** | No upstream and not merged into main. | Kept unless `-IncludeUnmerged` |

3. Deletes the eligible branches and prints each deleted SHA.

It never touches the working tree — no `reset`, `checkout -f`, or `clean`. The current branch is
never deleted; use `-SwitchToMain` to park the repo on `main` first so a stale current branch
becomes eligible. A repo with a failed fetch, detached HEAD, or missing main branch is reported as
**Needs attention** and the script continues with the rest.

---

## Recovering a deleted branch

Every deletion prints a restore command, e.g.:

```
deleted feature/login (a1b2c3d, upstream gone) - restore: git checkout -b feature/login a1b2c3d
```

The commits stay in the reflog for roughly 90 days, so the branch can be recreated with
`git checkout -b <name> <sha>`.

---

## Prerequisites

| Requirement | Notes |
| --- | --- |
| **Git on PATH** | The script exits early if `git` is not found. |
| **Windows PowerShell 5.1+** | Ships with Windows 10/11. |
| **PowerShell 7+** *(optional)* | Required for the `-Parallel` switch; on 5.1 it falls back to sequential. |

---

## Running

```powershell
.\cleanbranches.ps1                                       # dry run - report only
.\cleanbranches.ps1 -Apply                                # delete merged + gone-upstream branches
.\cleanbranches.ps1 -Root "C:\git" -Apply                 # scan a different root folder
.\cleanbranches.ps1 -MainBranch "master" -Apply           # different primary branch name
.\cleanbranches.ps1 -SwitchToMain -IncludeUnmerged -Apply # aggressive cleanup
.\cleanbranches.ps1 -Parallel                             # process repos in parallel (PowerShell 7+)
```

If PowerShell blocks the script, allow it for the current session only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

---

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `-Root` | script folder | Folder whose immediate child directories are scanned for git repos. |
| `-MainBranch` | `main` | Name of the primary branch used as the merge base. |
| `-Keep` | `master`, `develop`, `dev`, `release/*`, `release-*`, `hotfix/*`, `hotfix-*` | Wildcard patterns for branches that must never be deleted. |
| `-IncludeUnmerged` | off | Also delete local-only branches (no upstream) that are not merged into main. **This is the only option that can lose work that was never pushed.** |
| `-SwitchToMain` | off | Check out the main branch first (only if the tree is clean) so the branch you are standing on can also be cleaned. |
| `-Apply` | off | Actually delete. Without this the script only reports what it would do. |
| `-Parallel` | off | Process repos in parallel (requires PowerShell 7+; falls back to sequential on 5.1). |

---

## Output

Live progress is written per repo (timestamped), followed by a summary table with the repo name,
status, number of branches deleted and kept, and a detail column:

| Status | Meaning |
| --- | --- |
| **Deleted** | Branches were removed (`-Apply` mode); lists `name@sha` for each. |
| **Would delete** | Dry run — lists the branches and why each one qualifies. |
| **Nothing to clean** | No eligible branches. |
| **Needs attention** | Failed fetch, detached HEAD, missing main branch, or a delete that git refused. |

The final line summarizes counts and total time.
