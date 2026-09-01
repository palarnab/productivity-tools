# PullAll — Usage Guide

`pullall.ps1` syncs the `main` branch of every git repository that sits directly under a root
folder. For each sibling repo it fetches (with `--prune`), fast-forwards `main`, and then returns
to the branch you started on — without ever running a destructive command. See the root
[`README.md`](../../README.md) for where this fits in the repository.

---

## What it does per repo

1. Records the current branch.
2. Fetches with `--prune` (so branches deleted upstream are detected).
3. Checks out `main` if not already on it.
4. Pulls `main` with `--ff-only` (fast-forward only — never rebases, never creates a merge commit).
5. Switches back to the original branch **only if** it still exists on `origin`. If the branch is
   not on `origin`, it stays on `main`.

It never runs `reset --hard`, `checkout -f`, or `clean`. A repo with a dirty tree, conflict, or
diverged history is reported as **Needs attention** and the script continues with the rest.

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
.\pullall.ps1                                 # sync every repo under the script's folder
.\pullall.ps1 -Root "C:\git"                  # scan a different root folder
.\pullall.ps1 -MainBranch "master"            # use a different primary branch name
.\pullall.ps1 -Parallel                       # process repos in parallel (PowerShell 7+)
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
| `-MainBranch` | `main` | Name of the primary branch to pull. |
| `-Parallel` | off | Process repos in parallel (requires PowerShell 7+; falls back to sequential on 5.1). |

---

## Output

Live progress is written per repo (timestamped), followed by a summary table of every repo with one
of these statuses:

| Status | Meaning |
| --- | --- |
| **Updated** | `main` advanced; shows the commit range and number of files changed. |
| **Already up to date** | Nothing to pull. |
| **Needs attention** | Dirty tree, conflict, failed fetch/pull, detached HEAD, etc. — left untouched for you to resolve. |

The final line summarizes counts and total time. The script exits with code `1` if any repo needs
attention, otherwise `0`.
