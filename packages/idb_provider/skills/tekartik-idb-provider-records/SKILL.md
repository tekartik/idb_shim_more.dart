---
name: tekartik-idb-provider-records
description: >-
  Use when mapping typed objects to an idb_shim store with
  tekartik_idb_provider's record layer: DbRecordBase, DbRecord,
  DbSyncedRecordBase / DbSyncedRecord, DbField (dirty, deleted, syncId,
  syncVersion, version), DbRecordProvider and DbSyncedRecordProvider
  (fromEntry, store, get, put, delete, clear, txnPut / txnGet / txnDelete,
  getBySyncId, getFirstDirty, updateSyncInfo, syncing flag),
  DbRecordProviderReadTransaction / DbRecordProviderWriteTransaction,
  putRecord / deleteRecord / clearRecords, DbRecordProvidersMixin,
  DbRecordProvidersMapMixin and the onChange DbRecordProviderEvent stream.
---

# Typed records and sync (tekartik_idb_provider)

`package:tekartik_idb_provider/record_provider.dart` adds a typed record layer
on top of the provider described by the `tekartik-idb-provider-setup` skill
(`../tekartik-idb-provider-setup/SKILL.md`): one `DbRecord` class per store,
one `DbRecordProvider` to read/write it, plus a synced flavour that tracks
`dirty` / `syncId` / `deleted` for client-server synchronization. The package
README says **Not maintained**: use it for existing code.

## Guidelines

* Imports: `package:tekartik_idb_provider/record_provider.dart` for this layer
  and `package:tekartik_idb_provider/provider.dart` for `DynamicProvider`,
  `ProviderStoreMeta` and `ProviderIndexMeta` (the record library re-exports
  neither `idb_shim` nor `provider.dart`).
* A record class extends `DbRecord` (plain) or `DbSyncedRecordBase<K>` /
  `DbSyncedRecord` (synced, `K` is the key type) and implements
  `fillDbEntry(Map entry)` (object -> map, use the inherited
  `set(entry, field, value)` which skips nulls) and `fillFromDbEntry(Map
  entry)` (map -> object). Always call `super.fillDbEntry(entry)` /
  `super.fillFromDbEntry(entry)` first in a synced record: that is where
  `DbField.version`, `syncId`, `syncVersion`, `dirty` and `deleted` are
  written. `id` is the primary key and is not part of the entry;
  `toDbEntry()`, `toString()` and `==` come for free.
* A record provider extends `DbRecordProvider<T, K>` (or
  `DbSyncedRecordProvider<T, K>`) and implements two members: `String get
  store` (the store name) and `T? fromEntry(Map? entry, K? id)` (return
  `null` when `entry` or `id` is null).
* The provider must be attached to an open `Provider`: either
  `recordProvider.provider = myProvider;` or, with several stores, mix
  `DbRecordProvidersMixin, DbRecordProvidersMapMixin` into your
  `DynamicProvider` subclass, set `providerMap = {store: recordProvider, ...}`
  and call `initAll(this)` in the constructor (and `closeAll()` in `close()`).
* Reads/writes: `await recordProvider.get(id)`, `await
  recordProvider.put(record)` (returns the record with its `id` set),
  `delete(key)`, `clear()`. For several operations in one transaction use
  `var txn = recordProvider.writeTransaction;` then `txnPut(txn, record)`,
  `txnGet(txn, id)`, `txnDelete(txn, id)`, `txnClear(txn)`, and always `await
  txn.completed`. `readTransaction` / `storeReadTransaction` are the read-only
  equivalents; `indexGet(indexTransaction, key)` reads through an index.
* Inside a `DbRecordProviderWriteTransaction` use the record methods
  `putRecord(record)`, `deleteRecord(key)`, `clearRecords()`: the raw `add`,
  `put`, `delete` and `clear` of the store transaction deliberately throw, so
  that change events are never bypassed.
* Change notifications: `recordProvider.onChange` is a
  `Stream<List<DbRecordProviderEvent>>` emitted when a write transaction
  completes; each event is a `DbRecordProviderPutEvent` (`.record`),
  `DbRecordProviderDeleteEvent` (`.key`) or `DbRecordProviderClearEvent`, with
  `.syncing` true when the change came from a sync. `close()` closes the
  listeners.
* Synced records (`DbSyncedRecordProvider`): every local write marks the record
  `dirty` and bumps `version`; a write done while synchronizing passes
  `syncing: true` (`put(record, syncing: true)`, `delete(id, syncing: true)`,
  `clear(syncing: true)` - `clear` *requires* it). Sync helpers:
  `getFirstDirty()` (next record to push), `getBySyncId(syncId)`,
  `updateSyncInfo(record, syncId, syncVersion)` (clears `dirty`),
  `txnDeleteSyncedRecord(txn)`. Deleting a record that has a `syncId` keeps a
  tombstone (`deleted` true, `dirty` true) instead of removing it.
* The store of a synced record needs the two indexes named by the constants
  `DbSyncedRecordProvider.dirtyIndex` (`DbField.dirty`) and
  `DbSyncedRecordProvider.syncIdIndex` (`DbField.syncId`); declare them in
  `onUpdateDatabase` with `ProviderIndexMeta(DbField.dirty, DbField.dirty)`
  and `ProviderIndexMeta(DbField.syncId, DbField.syncId)`. `dirty` is stored
  as `1`/absent and `deleted` as `true`/absent so that they stay indexable.
* Multi-store transactions: `writeTransactionList([storeA, storeB])` (from
  `DbRecordProvidersMixin`) returns a `DbRecordProviderWriteTransactionList`;
  `list.store(name)` gives the per-store record transaction, and
  `recordProvider.txnListWriteTransaction(list)` does the same from the record
  provider side. One `await list.completed` at the end.
* Anti-patterns: forgetting `initAll` / `provider =` (throws a late
  initialization error on first use); using the raw `put` of a record
  transaction; calling `clear()` on a synced provider without `syncing: true`;
  keeping a transaction open across unrelated awaits.

## Examples

### A record, its provider, and the app provider holding them

```dart
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/idb_client_memory.dart';
import 'package:tekartik_idb_provider/provider.dart';
import 'package:tekartik_idb_provider/record_provider.dart';

const String noteNameField = 'name';

class DbNote extends DbRecord {
  @override
  Object? id;
  String? name;

  static DbNote? fromDbEntry(Map? entry, Object? id) {
    if (entry == null || id == null) {
      return null;
    }
    return DbNote()
      ..id = id
      ..fillFromDbEntry(entry);
  }

  @override
  void fillFromDbEntry(Map entry) {
    name = entry[noteNameField] as String?;
  }

  @override
  void fillDbEntry(Map entry) {
    set(entry, noteNameField, name);
  }
}

class DbNoteProvider extends DbRecordProvider<DbNote, int> {
  @override
  String get store => AppProvider.noteStore;

  @override
  DbNote? fromEntry(Map? entry, int? id) => DbNote.fromDbEntry(entry, id);
}

class AppProvider extends DynamicProvider
    with DbRecordProvidersMixin, DbRecordProvidersMapMixin {
  static const String noteStore = 'note';
  static const int dbVersion = 1;

  final note = DbNoteProvider();

  AppProvider(IdbFactory idbFactory, String dbName)
    : super.noMeta(idbFactory) {
    init(idbFactory, dbName, dbVersion);
    providerMap = {noteStore: note};
    initAll(this);
  }

  @override
  void onUpdateDatabase(VersionChangeEvent e) {
    if (e.oldVersion < 1) {
      addStores(
        ProviderStoresMeta([
          ProviderStoreMeta(
            noteStore,
            autoIncrement: true,
            indecies: [ProviderIndexMeta(noteNameField, noteNameField)],
          ),
        ]),
      );
    }
    super.onUpdateDatabase(e);
  }

  @override
  void close() {
    closeAll();
    super.close();
  }
}

Future<void> main() async {
  var provider = AppProvider(idbFactoryMemory, 'app.db');
  await provider.ready;

  var saved = await provider.note.put(DbNote()..name = 'first');
  print('${saved.id}: ${(await provider.note.get(saved.id as int))?.name}');

  // Several writes in one transaction
  var txn = provider.note.writeTransaction;
  await provider.note.txnPut(txn, DbNote()..name = 'second');
  await provider.note.txnPut(txn, DbNote()..name = 'third');
  await txn.completed;

  await provider.note.delete(saved.id as int);
  provider.close();
}
```

### Listening to changes

```dart
import 'package:tekartik_idb_provider/record_provider.dart';

void watch(DbRecordBaseProvider recordProvider) {
  recordProvider.onChange.listen((events) {
    for (var event in events) {
      if (event is DbRecordProviderPutEvent) {
        print('put ${event.record} (syncing: ${event.syncing})');
      } else if (event is DbRecordProviderDeleteEvent) {
        print('deleted ${event.key}');
      } else if (event is DbRecordProviderClearEvent) {
        print('cleared');
      }
    }
  });
}
```

### A synced record and its sync loop

```dart
import 'package:tekartik_idb_provider/record_provider.dart';

class DbTodo extends DbSyncedRecordBase<int> {
  @override
  int? id;
  String? title;

  static DbTodo? fromDbEntry(Map? entry, int? id) {
    if (entry == null || id == null) {
      return null;
    }
    return DbTodo()
      ..id = id
      ..fillFromDbEntry(entry);
  }

  @override
  void fillFromDbEntry(Map entry) {
    super.fillFromDbEntry(entry);
    title = entry['title'] as String?;
  }

  @override
  void fillDbEntry(Map entry) {
    super.fillDbEntry(entry);
    set(entry, 'title', title);
  }
}

class DbTodoProvider extends DbSyncedRecordProvider<DbTodo, int> {
  @override
  String get store => 'todo';

  @override
  DbTodo? fromEntry(Map? entry, int? id) => DbTodo.fromDbEntry(entry, id);
}

/// Push local changes, then apply what the server returns.
Future<void> syncAll(
  DbTodoProvider todos,
  Future<String> Function(DbTodo record) push,
) async {
  DbTodo? dirty;
  while ((dirty = await todos.getFirstDirty()) != null) {
    if (dirty!.deleted) {
      await todos.delete(dirty.id as int, syncing: true);
    } else {
      var syncId = await push(dirty);
      await todos.updateSyncInfo(dirty, syncId, dirty.version.toString());
    }
  }
}
```
