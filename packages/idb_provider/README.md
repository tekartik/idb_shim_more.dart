# tekartik_idb_provider

**Not maintained**: kept for existing code. For new code, use the sdb API of
[idb_shim](https://pub.dev/packages/idb_shim) (`package:idb_shim/sdb.dart`).

A provider pattern on top of [idb_shim](https://pub.dev/packages/idb_shim)
(IndexedDB): a `Provider` holds the database name, version and schema, opens
it once (`ready`) and gives small transaction objects to read and write. A
typed record layer (`DbRecord`, `DbRecordProvider`, synced records with
change notifications) sits on top.

## Getting started

Add the git dependency (not on pub.dev):

```yaml
dependencies:
  idb_shim: ^2.11.3
  tekartik_idb_provider:
    git:
      url: https://github.com/tekartik/idb_shim_more.dart
      path: packages/idb_provider
```

Declare the stores, wait for `ready`, then use transactions:

```dart
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:tekartik_idb_provider/provider.dart';

Future<void> main() async {
  var provider = DynamicProvider(idbFactoryMemory, ProviderDbMeta('notes.db'))
    ..addStore(
      ProviderStoreMeta(
        'notes',
        autoIncrement: true,
        indecies: [ProviderIndexMeta('name', 'name')],
      ),
    );
  await provider.ready;

  var txn = provider.storeTransaction('notes', true);
  await txn.put({'name': 'hello'});
  await txn.put({'name': 'world'});
  await txn.completed;

  txn = provider.storeTransaction('notes');
  var names = await txn
      .openCursor(offset: 1, limit: 10)
      .map((CursorWithValue cwv) => (cwv.value as Map)['name'])
      .toList();
  await txn.completed;
  print(names); // [world]
  provider.close();
}
```

## Platforms

Every `idb_shim` factory works: `idbFactoryMemory` (tests, any platform),
`getIdbFactorySembastIo(path)` (Dart VM, Flutter native),
`idbFactoryWeb` (browser).

## What to use

- `DynamicProvider` with `ProviderStoreMeta` / `ProviderIndexMeta` (note the
  spelling `indecies`): the stores are created on the first open. Or extend
  `Provider` and create the stores yourself in `onUpdateDatabase`.
- `provider.storeTransaction(store, readWrite)`,
  `provider.indexTransaction(store, index)`, `provider.transactionList(stores)`:
  one IndexedDB transaction each, `await txn.completed` at the end.
- `package:tekartik_idb_provider/record_provider.dart`: typed records
  (`DbRecord`, `DbRecordProvider`: `get`, `put`, `delete`, `onChange`) and
  synced records (`DbSyncedRecord`, `DbSyncedRecordProvider`: `dirty`,
  `syncId`, tombstones).

## Common pitfalls

- Use a provider only after `await provider.ready`; `addStore` has an effect
  only before the database is created or upgraded.
- Do not await something else (a timer, a network call) in the middle of a
  transaction: IndexedDB closes an inactive transaction.
- `await txn.completed` before `provider.close()`.
- `DynamicProvider` creates every declared store at each upgrade: bumping the
  version of an existing database fails in the browser (the store already
  exists). Extend `Provider` to migrate an existing database.

The package skills (`skills/`) document the API in detail.
