# MongoDb — Usage Guide

Maintenance helpers for MongoDB/Atlas clusters: inspect namespace usage, migrate a database between
clusters, and turn Markdown docs into print-ready HTML. See the root [`README.md`](../README.md) for
where this folder fits in the repository.

## Contents

| File | Purpose |
| --- | --- |
| `db-usage.js` | Inspect MongoDB namespace/collection usage; optionally drop empty collections. |
| `db-migration.txt` | Command cheat sheet for migrating a database between clusters. |
| `md-to-html.mjs` | Convert a Markdown file into styled, print-ready HTML. |

---

## Prerequisites

| Requirement | Needed for | Notes |
| --- | --- | --- |
| **Node.js 14+** | `db-usage.js`, `md-to-html.mjs` | ES modules are used. |
| **MongoDB Database Tools** (`mongodump`, `mongorestore`) | `db-migration.txt` steps | Install from the MongoDB Database Tools package. |
| **`marked`** npm package | `md-to-html.mjs` | `npm install marked`. |
| **Cluster connection helper** | `db-usage.js` | A project-local `src/infrastructure/mongodb/connection.js` exporting `connectMongo`, `disconnectMongo`, and `mongoose`. |

---

## 1. `db-usage.js` — namespace/usage inspector

Scans every non-system database on a MongoDB/Atlas cluster and reports namespace usage. It targets
the Atlas shared-tier limit of **500 namespaces** (each collection *plus* each index counts as one),
which surfaces as the error `cannot create a new collection -- already using 501 collections of 500`.

For every collection it reports document count, data size, index count, total index size, last write
activity, and whether the collection is **EMPTY** (0 docs) or **STALE** (no writes within
`--stale-days`). It then prints cluster-wide namespace usage against the 500 cap so you can see how
much room can be reclaimed.

The script expects a project-local connection helper at
`src/infrastructure/mongodb/connection.js` and is intended to run from a project's `scripts/`
directory.

**Read-only by default.** `--drop-empty` can DROP zero-document collections to reclaim namespaces;
because that is destructive it lists the targets and only proceeds when `--yes` is also passed.

### Usage

```bash
node scripts/db-usage.js                    # report only (all databases)
node scripts/db-usage.js --stale-days=30    # flag collections idle > 30 days
node scripts/db-usage.js --json             # machine-readable output
node scripts/db-usage.js --drop-empty       # preview which empty collections would be dropped
node scripts/db-usage.js --drop-empty --yes # actually drop empty collections (destructive)
```

### Options

| Flag | Default | Description |
| --- | --- | --- |
| `--stale-days=N` | `90` | Number of idle days after which a non-empty collection is flagged STALE. |
| `--json` | off | Emit machine-readable JSON instead of formatted tables. |
| `--drop-empty` | off | Target zero-document collections for dropping (preview unless `--yes`). |
| `--yes` | off | Confirm and actually perform the drop. |

> **Destructive flag warning:** always run once without `--yes` and review the printed list of
> targeted collections before adding `--yes`.

---

## 2. `db-migration.txt` — cluster migration cheat sheet

A command cheat sheet for migrating a database (example db name `lmsdb`) from one cluster to another
using `mongodump`/`mongorestore`, then re-pointing the app, recreating indexes, and redeploying.

Steps at a glance:

1. `mongodump` the current database.
2. `mongorestore` into the new (M10+/dedicated) cluster.
3. Point the app at the new cluster (`MONGODB_URI`).
4. Recreate indexes / missing collections on the new cluster.
5. Redeploy / restart the api, worker, and scheduler.

> Replace `<OLD_MONGODB_URI>` and `<NEW_MONGODB_URI>` with your real connection strings before
> running any command.

---

## 3. `md-to-html.mjs` — Markdown to print-ready HTML

Converts a Markdown file into a single, self-contained HTML document with embedded print-friendly
(A4) styling — useful for generating clean PDFs from Markdown via a browser's Print dialog. Uses the
[`marked`](https://www.npmjs.com/package/marked) library with GitHub-Flavored Markdown enabled. The
document `<title>` is derived from the input file name.

### Prerequisite

```bash
npm install marked
```

### Usage

```bash
node md-to-html.mjs <input.md> <output.html>
```

Then open `<output.html>` in a browser and use **Print → Save as PDF** for an A4 document.
