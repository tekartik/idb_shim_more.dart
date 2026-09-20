---
name: tekartik-idb-provider-setup
description: >-
  Use when opening and querying an idb_shim (IndexedDB) database through
  tekartik_idb_provider's provider pattern: Provider / DynamicProvider,
  init + ready + close + delete, onUpdateDatabase, ProviderDbMeta,
  ProviderStoreMeta, ProviderIndexMeta, ProviderStoresMeta, ProviderDb,
  ProviderStore, ProviderIndex, storeTransaction / indexTransaction /
  transactionList, ProviderStoreTransaction, RawProviderStoreTransaction,
  ProviderIndexTransaction, openCursor with limit/offset, IntMapRow and
  StringMapRow row factories.
---

# Provider pattern over IndexedDB (tekartik_idb_provider)

`tekartik_idb_provider` wraps an `idb_shim` `IdbFactory` in a `Provider`: the
database name, version and schema live in one object, opening is a single
`ready` future, and every read/write goes through a small transaction object.
Its README says **Not maintained** - use it for existing code; for new code
prefer the SDB API of `idb_shim` (`package:idb_shim/sdb.dart`).

## Guidelines

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    tekartik_idb_provider:
      git:
        url: https://github.com/tekartik/idb_shim_more.dart
        path: packages/idb_provider
  ```
  `import 'package:tekartik_idb_provider/provider.dart';` gives the provider,
  meta, transaction and row classes. It does *not* re-export `idb_shim`: add
  `import 'package:idb_shim/idb_client.dart';` for `IdbFactory`,
  `VersionChangeEvent`, `CursorWithValue`, and
  `package:idb_shim/idb_client_memory.dart` (`idbFactoryMemory`) in tests.
* Two ways to define the schema:
  * `DynamicProvider(idbFactory, ProviderDbMeta(name, version))` (or
    `DynamicProvider.noMeta(idbFactory)` + `init(idbFactory, name, version)`)
    then `addStore(ProviderStoreMeta(...))` / `addStores(ProviderStoresMeta
    ([...]))` before the first `ready`: the stores and indexes are created for
    you in `onUpdateDatabase`.
  * `class MyProvider extends Provider` overriding
    `void onUpdateDatabase(VersionChangeEvent e)` and calling
    `database!.createObjectStore(...)` / `db!.createStore(meta)` /
    `db!.deleteStore(name)` by hand, with `init(idbFactory, name, version)` in
    the constructor. `e.oldVersion` / `e.newVersion` drive the migration.
* Lifecycle: `provider.ready` (a `Future<Provider>?`) opens the database on
  first access - always `await provider.ready`; `isReady` / `isClosed` report
  the state; `close()` releases it; `delete()` closes then deletes the
  database; `clear()` empties every store. An already open `Database` can be
  adopted with `Provider.fromIdb(db)` or `provider.database = db`.
* Metadata: `ProviderStoreMeta(name, {keyPath, autoIncrement, indecies})` and
  `ProviderIndexMeta(name, keyPath, {unique, multiEntry})` (note the spelling
  `indecies`); `provider.storesMeta` reads the live schema back, which is handy
  to compare with the expected one. `ProviderDb` (`provider.db`) exposes
  `database`, `storeNames`, `version`, `meta`, `factory`, `createStore`,
  `deleteStore`, `close`.
* Transactions (one idb transaction each, all created from the provider):
  * `provider.storeTransaction(storeName, true)` - read/write single store
    (`false`/omitted = read-only). Methods: `get`, `add`, `put`, `delete`,
    `clear`, `count`, `index(name)`, `openCursor({reverse, limit, offset})`,
    and `completed`, which must be awaited before the transaction is reused.
  * `provider.indexTransaction(storeName, indexName, readWrite)` or
    `txn.index(indexName)` - `get`, `getKey`, `count`, `openCursor(...)`,
    `openKeyCursor(...)`, all with an optional `key:`.
  * `provider.transactionList([store1, store2], true)` - a
    `ProviderTransactionList`, then `list.store(name)` / `list.index(name,
    indexName)` to work on each store inside the same transaction, and
    `list.completed` once.
  * `RawProviderStoreTransaction(provider, storeName, [readWrite])` is the
    untyped (`Object`) store transaction, useful inside a `Provider`
    subclass.
* Cursors: `openCursor(limit: n, offset: k)` applies the limit/offset on top
  of the idb cursor; the stream yields `CursorWithValue` (`cwv.primaryKey`,
  `cwv.value`). Turn them into rows with `intMapProviderRawFactory.newRow(key,
  map)` / `.cursorWithValueRow(cwv)` (`IntMapRow`), or
  `StringMapProviderRowFactory()` for `String` keys (`StringMapRow`); rows
  compare by value and support `row['field']`.
* Anti-patterns: creating a transaction before `await provider.ready`; holding
  a transaction across an `await` that is not part of it (idb closes inactive
  transactions); forgetting `await txn.completed` before `provider.close()`;
  calling `addStore` after the database is open (it only runs during an
  upgrade); expecting `provider.db` to be non-null once `close()` was called.
* Testing: `idbFactoryMemory` from `package:idb_shim/idb_client_memory.dart`
  and a fresh database name per test (`provider.delete()` in `setUp`).

## Examples

### A dynamic provider: schema declared, no subclass

```dart
import 'package:idb_shim/idb_client.dart';
import 'package:tekartik_idb_provider/provider.dart';

Future<DynamicProvider> openNotesProvider(IdbFactory idbFactory) async {
  var provider = DynamicProvider(idbFactory, ProviderDbMeta('notes.db', 1));
  provider.addStores(
    ProviderStoresMeta([
      ProviderStoreMeta(
        'notes',
        autoIncrement: true,
        indecies: [ProviderIndexMeta('name', 'name', unique: false)],
      ),
    ]),
  );
  await provider.ready;
  return provider;
}
```

### A provider subclass with its own migration and queries

```dart
import 'package:idb_shim/idb_client.dart';
import 'package:tekartik_idb_provider/provider.dart';

class NotesProvider extends Provider {
  static const store = 'notes';
  static const nameIndex = 'name';

  NotesProvider(IdbFactory idbFactory) {
    init(idbFactory, 'notes.db', 1);
  }

  @override
  void onUpdateDatabase(VersionChangeEvent e) {
    if (e.oldVersion < 1) {
      var objectStore = database!.createObjectStore(
        store,
        autoIncrement: true,
      );
      objectStore.createIndex(nameIndex, 'name', unique: false);
    }
  }

  Future<int> add(String name) async {
    var txn = storeTransaction(store, true);
    var key = await txn.put({'name': name}) as int;
    await txn.completed;
    return key;
  }

  Future<List<String>> names({int? limit, int? offset}) async {
    var txn = indexTransaction(store, nameIndex);
    var names = <String>[];
    await txn
        .openCursor(limit: limit, offset: offset)
        .listen((CursorWithValue cwv) {
          names.add((cwv.value as Map)['name'] as String);
        })
        .asFuture<void>();
    await txn.completed;
    return names;
  }
}

Future<void> main() async {
  var provider = NotesProvider(idbFactoryMemory);
  await provider.ready;
  await provider.add('hello');
  print(await provider.names(limit: 10));
  provider.close();
}
```

### Several stores in one transaction

```dart
import 'package:tekartik_idb_provider/provider.dart';

Future<void> copyFirst(
  Provider provider,
  String fromStore,
  String toStore,
) async {
  var list = provider.transactionList([fromStore, toStore], true);
  var source = list.store(fromStore);
  var target = list.store(toStore);
  var first = await source.openCursor(limit: 1).first;
  await target.put(first.value);
  await list.completed;
}
```

### Rows from a cursor

```dart
import 'package:idb_shim/idb_client.dart';
import 'package:tekartik_idb_provider/provider.dart';

Future<List<IntMapRow>> readRows(Provider provider, String storeName) async {
  var txn = provider.storeTransaction(storeName);
  var rows = <IntMapRow>[];
  await txn
      .openCursor()
      .listen((CursorWithValue cwv) {
        rows.add(intMapProviderRawFactory.cursorWithValueRow(cwv));
      })
      .asFuture<void>();
  await txn.completed;
  return rows;
}

Future<void> main() async {
  var provider = DynamicProvider(idbFactoryMemory, ProviderDbMeta('demo.db'))
    ..addStore(ProviderStoreMeta('items', autoIncrement: true));
  await provider.ready;
  print(await readRows(provider, 'items'));
  provider.close();
}
```
