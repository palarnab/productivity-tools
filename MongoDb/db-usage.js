/**
 * DB namespace/usage inspector (see error: "cannot create a new collection -- already using 501
 * collections of 500"). Atlas shared/free tiers cap a cluster at 500 *namespaces*, where a
 * namespace = each collection PLUS each index, counted across ALL databases on the cluster. This
 * script scans every (non-system) database and reports, for every collection:
 *   - document count, data size, index count, total index size
 *   - last write activity (newest document, derived from updatedAt / createdAt / the _id timestamp)
 *   - whether it is EMPTY (0 docs) or STALE (no writes for --stale-days, default 90)
 * and prints the cluster-wide total namespace usage against the 500 cap so you can see how much
 * room you can reclaim.
 *
 * Read-only by default. Pass --drop-empty to DROP every zero-document collection (frees the
 * collection + its indexes) — destructive, so it prints the list and requires --yes to proceed.
 *
 * Usage:
 *   node scripts/db-usage.js                    # report only (all databases)
 *   node scripts/db-usage.js --stale-days=30    # flag collections idle > 30 days
 *   node scripts/db-usage.js --json             # machine-readable output
 *   node scripts/db-usage.js --drop-empty --yes # reclaim namespaces from empty collections
 */
import { connectMongo, disconnectMongo, mongoose } from '../src/infrastructure/mongodb/connection.js';

const NAMESPACE_CAP = 500; // Atlas M0/Flex/M2/M5 hard limit (collections + indexes per cluster).
const SYSTEM_DBS = new Set(['admin', 'local', 'config']); // managed by Atlas; not user namespaces.

function parseArgs(argv) {
  const args = { staleDays: 90, dropEmpty: false, yes: false, json: false };
  for (const a of argv.slice(2)) {
    if (a === '--drop-empty') args.dropEmpty = true;
    else if (a === '--yes') args.yes = true;
    else if (a === '--json') args.json = true;
    else if (a.startsWith('--stale-days=')) args.staleDays = Number(a.split('=')[1]) || 90;
  }
  return args;
}

function fmtBytes(n) {
  if (!n) return '0 B';
  const u = ['B', 'KB', 'MB', 'GB'];
  const i = Math.min(u.length - 1, Math.floor(Math.log(n) / Math.log(1024)));
  return `${(n / 1024 ** i).toFixed(i ? 1 : 0)} ${u[i]}`;
}

function fmtAge(date) {
  if (!date) return 'never';
  const days = Math.floor((Date.now() - date.getTime()) / 86_400_000);
  if (days <= 0) return 'today';
  return `${days}d ago`;
}

/**
 * Best-effort newest-write timestamp for a collection: prefer an explicit updatedAt/createdAt field,
 * else fall back to the creation time embedded in the newest ObjectId _id.
 */
async function newestActivity(coll) {
  for (const field of ['updatedAt', 'createdAt']) {
    const doc = await coll.find({ [field]: { $exists: true } }).sort({ [field]: -1 }).limit(1).next();
    if (doc?.[field] instanceof Date) return doc[field];
  }
  const newest = await coll.find({}).sort({ _id: -1 }).limit(1).next();
  if (newest?._id?.getTimestamp) {
    try {
      return newest._id.getTimestamp();
    } catch {
      /* _id is not an ObjectId */
    }
  }
  return null;
}

/** Inspect every collection in one database; returns the rows and this db's index total. */
async function inspectDb(db, staleDays) {
  const infos = await db.listCollections({ type: 'collection' }).toArray();
  const rows = [];
  let totalIndexes = 0;

  for (const info of infos) {
    const name = info.name;
    const coll = db.collection(name);
    let stats = {};
    try {
      stats = await db.command({ collStats: name });
    } catch {
      /* view or inaccessible */
    }
    const count = stats.count ?? (await coll.estimatedDocumentCount());
    const nindexes = stats.nindexes ?? (await coll.indexes()).length;
    const lastWrite = count > 0 ? await newestActivity(coll) : null;
    totalIndexes += nindexes;
    rows.push({
      db: db.databaseName,
      name,
      count,
      dataSize: stats.size ?? 0,
      indexes: nindexes,
      indexSize: stats.totalIndexSize ?? 0,
      lastWrite,
      empty: count === 0,
      stale:
        count > 0 &&
        lastWrite instanceof Date &&
        Date.now() - lastWrite.getTime() > staleDays * 86_400_000,
    });
  }

  rows.sort((a, b) => Number(b.empty) - Number(a.empty) || a.count - b.count);
  return { rows, totalIndexes };
}

function printDbTable(dbName, rows, totalIndexes, staleDays) {
  const pad = (s, n) => String(s).padEnd(n);
  const padL = (s, n) => String(s).padStart(n);
  const namespaces = rows.length + totalIndexes;
  console.log(`\n=== Database: ${dbName} ===`);
  console.log(
    `  Namespaces: ${namespaces}  (${rows.length} collections + ${totalIndexes} indexes)\n`,
  );
  console.log(
    pad('COLLECTION', 30) +
      padL('DOCS', 8) +
      padL('IDXS', 6) +
      padL('DATA', 10) +
      padL('INDEX', 10) +
      '  LAST WRITE   FLAG',
  );
  console.log('-'.repeat(88));
  for (const r of rows) {
    const flag = r.empty ? 'EMPTY' : r.stale ? 'STALE' : '';
    console.log(
      pad(r.name, 30) +
        padL(r.count, 8) +
        padL(r.indexes, 6) +
        padL(fmtBytes(r.dataSize), 10) +
        padL(fmtBytes(r.indexSize), 10) +
        '  ' +
        pad(fmtAge(r.lastWrite), 11) +
        '  ' +
        flag,
    );
  }
}

async function main() {
  const args = parseArgs(process.argv);
  await connectMongo();
  const client = mongoose.connection.getClient();

  const { databases } = await client.db('admin').admin().listDatabases();
  const userDbs = databases.map((d) => d.name).filter((n) => !SYSTEM_DBS.has(n));

  const perDb = [];
  let clusterCollections = 0;
  let clusterIndexes = 0;
  for (const name of userDbs) {
    const { rows, totalIndexes } = await inspectDb(client.db(name), args.staleDays);
    perDb.push({ dbName: name, rows, totalIndexes });
    clusterCollections += rows.length;
    clusterIndexes += totalIndexes;
  }
  const clusterNamespaces = clusterCollections + clusterIndexes;

  if (args.json) {
    console.log(
      JSON.stringify(
        { clusterNamespaces, cap: NAMESPACE_CAP, databases: perDb },
        null,
        2,
      ),
    );
  } else {
    console.log(
      `\nCluster namespaces used: ${clusterNamespaces} / ${NAMESPACE_CAP}  ` +
        `(${clusterCollections} collections + ${clusterIndexes} indexes across ${userDbs.length} db(s))  ` +
        `— ${Math.max(0, NAMESPACE_CAP - clusterNamespaces)} free`,
    );
    for (const { dbName, rows, totalIndexes } of perDb) {
      printDbTable(dbName, rows, totalIndexes, args.staleDays);
    }

    const allRows = perDb.flatMap((d) => d.rows);
    const empties = allRows.filter((r) => r.empty);
    const stales = allRows.filter((r) => r.stale);
    const reclaimable = empties.reduce((n, r) => n + 1 + r.indexes, 0);
    console.log('\nSummary (cluster-wide)');
    console.log(`  Empty collections: ${empties.length}  (reclaims ~${reclaimable} namespaces if dropped)`);
    console.log(`  Stale collections (> ${args.staleDays}d idle, has data): ${stales.length}`);
    if (empties.length) {
      console.log(`  Empty: ${empties.map((r) => `${r.db}.${r.name}`).join(', ')}`);
    }
  }

  if (args.dropEmpty) {
    const empties = perDb.flatMap((d) => d.rows).filter((r) => r.empty);
    if (!empties.length) {
      console.log('\nNothing to drop: no empty collections.');
    } else if (!args.yes) {
      console.log(
        `\n--drop-empty would DROP ${empties.length} empty collection(s): ` +
          `${empties.map((r) => `${r.db}.${r.name}`).join(', ')}\n` +
          'Re-run with --yes to actually drop them.',
      );
    } else {
      for (const r of empties) {
        await client
          .db(r.db)
          .collection(r.name)
          .drop()
          .catch((err) => console.error(`  failed to drop ${r.db}.${r.name}: ${err.message}`));
        console.log(`  dropped ${r.db}.${r.name}`);
      }
      console.log(`\nDropped ${empties.length} empty collection(s).`);
    }
  }

  await disconnectMongo();
}

main().catch((err) => {
  console.error('db-usage failed:', err);
  process.exit(1);
});
