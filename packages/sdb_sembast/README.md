# tekartik_sdb_sembast

Simple DB (`package:idb_shim/sdb.dart`) implementation on top of
[sembast](https://pub.dev/packages/sembast), without IndexedDB.

Experimental: it shows that the sdb API can be backed by something else than
IndexedDB. It passes the sdb test suites of `idb_test` on the sembast memory,
io and web factories. For an app, the sdb factories of
[idb_shim](https://pub.dev/packages/idb_shim) (on IndexedDB, or on sembast
through idb) are the supported ones.

## Getting started

Add the git dependency (not on pub.dev), next to `idb_shim` and `sembast`:

```yaml
dependencies:
  idb_shim: ^2.11.3
  sembast: ^3.10.1
  tekartik_sdb_sembast:
    git:
      url: https://github.com/tekartik/idb_shim_more.dart
      path: packages/sdb_sembast
```

Then use the sdb API with a factory of this package:

```dart
import 'package:idb_shim/sdb.dart';
import 'package:tekartik_sdb_sembast/sdb_sembast.dart';

/// A store of notes with an int key generated on add.
final notesStore = SdbStoreRef<int, SdbModel>('notes');

Future<void> main() async {
  // sdbFactorySembastFrom(databaseFactoryIo) to store in a file.
  var factory = sdbFactorySembastNewInMemory();
  var db = await factory.openDatabase(
    'notes.db',
    options: SdbOpenDatabaseOptions(
      version: 1,
      schema: SdbDatabaseSchema(
        stores: [notesStore.schema(autoIncrement: true)],
      ),
    ),
  );
  var key = await notesStore.add(db, {'title': 'Hello'});
  print((await notesStore.record(key).get(db))!.value); // {title: Hello}
  await db.close();
}
```

- `sdbFactorySembastFrom(sembastFactory)`: any sembast database factory,
  `databaseFactoryMemory`, `databaseFactoryIo` (Dart VM, Flutter native,
  `package:sembast/sembast_io.dart`) or `databaseFactoryWeb` (browser,
  `package:sembast_web`).
- `sdbFactorySembastNewInMemory()`: a new empty in memory factory (tests).

## Behaviour

Same as the idb based sdb: a failed write throws a `DatabaseError` (a
`DatabaseReadOnlyError` in a read-only transaction), a store deleted and
created again in a version change starts empty, a filter can use dotted
fields.

How it works:

- The schema (stores, key paths, auto increment, indexes) is kept in a sembast
  store named `_sdb_schema` and applied during the sembast version change.
- Values are stored encoded with the sdb codec. The idb native types
  (DateTime, Uint8List) are stored as sembast Timestamp and Blob.
- Indexes are emulated: the store is scanned and ordered by index key then
  primary key.

## Pitfalls

- Do not name a store `_sdb_schema`: it holds the schema.
- An index query reads the whole store: fine for small stores, slow for big
  ones.
- Two `openDatabase` of the same name share one sembast database: closing one
  closes the other (as the idb based sdb on sembast).
