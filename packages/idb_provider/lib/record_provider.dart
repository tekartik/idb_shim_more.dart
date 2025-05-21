library;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:tekartik_idb_provider/provider.dart';

abstract class DbField {
  static const String syncVersion = 'syncVersion';
  static const String version = 'version';

  // local version (incremented)
  static const String dirty = 'dirty';
  static const String deleted = 'deleted';
  static const String syncId = 'syncId';
  static const String kind = 'kind';
}

abstract class DbRecordBase<K> {
  /// Nullable key
  K? get id;

  set id(K? id);

  void fillDbEntry(Map entry);

  void fillFromDbEntry(Map entry);

  Map<String, Object?> toDbEntry() {
    final entry = <String, Object?>{};
    fillDbEntry(entry);

    return entry;
  }

  void set(Map map, String key, Object? value) {
    if (value != null) {
      map[key] = value;
    } else {
      map.remove(key);
    }
  }

  @override
  String toString() {
    final map = <String, Object?>{};
    fillDbEntry(map);
    if (id != null) {
      map['_id'] = id.toString();
    }
    return map.toString();
  }

  @override
  int get hashCode =>
      const MapEquality<Object?, Object?>().hash(toDbEntry()) + id.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is DbRecordBase) {
      return (const MapEquality<String, Object?>().equals(
            toDbEntry(),
            other.toDbEntry(),
          )) &&
          id == other.id;
    }
    return false;
  }
}

abstract class DbRecord extends DbRecordBase {
  /*
  get id;

  set id(var id);

  @override
  bool operator ==(o) {
    return (super == (o) && id == o.id);
  }
  */
}

abstract class DbSyncedRecordBase<T> extends DbRecordBase<T> {
  //String get kind;

  int? version;

  String? _syncId;
  String? _syncVersion;

  String? get syncId => _syncId;

  // will match the tag when synced
  String? get syncVersion => _syncVersion;

  void setSyncInfo(String? syncId, String? syncVersion) {
    _syncId = syncId;
    _syncVersion = syncVersion;
  }

  bool? _deleted;

  bool get deleted => _deleted == true;

  // true or false
  set deleted(bool deleted) => _deleted = deleted;

  bool? _dirty;

  bool get dirty => _dirty == true;

  // true or false
  set dirty(bool dirty) => _dirty = dirty;

  @override
  void fillFromDbEntry(Map entry) {
    // type = entry[FIELD_TYPE]; already done
    version = entry[DbField.version] as int?;
    _syncId = entry[DbField.syncId] as String?;
    _syncVersion = entry[DbField.syncVersion] as String?;
    _deleted = entry[DbField.deleted] as bool?;
    _dirty = entry[DbField.dirty] == 1;
  }

  @override
  void fillDbEntry(Map entry) {
    set(entry, DbField.version, version);
    set(entry, DbField.syncId, syncId);
    set(entry, DbField.syncVersion, syncVersion);
    set(entry, DbField.deleted, deleted ? true : null);
    set(entry, DbField.dirty, dirty ? 1 : null);
    //set(entry, DbField.kind, kind);
  }
}

abstract class DbSyncedRecord extends DbSyncedRecordBase<int> {}

class DbRecordProviderPutEvent extends DbRecordProviderEvent {
  DbRecordBase? record;
}

class DbRecordProviderDeleteEvent extends DbRecordProviderEvent {
  dynamic key;
}

// not tested
class DbRecordProviderClearEvent extends DbRecordProviderEvent {}

class DbRecordProviderEvent {
  bool? _syncing;

  bool? get syncing => _syncing;

  set syncing(bool? syncing) => _syncing = syncing == true;
}

// only for writable transaction
abstract class DbRecordProviderTransaction<K>
    extends ProviderStoreTransaction<K, Map> {
  DbRecordBaseProvider _provider;

  factory DbRecordProviderTransaction(
    DbRecordBaseProvider provider,
    String storeName, [
    bool? readWrite = false,
  ]) {
    if (readWrite == true) {
      return DbRecordProviderWriteTransaction(provider, storeName);
    } else {
      return DbRecordProviderReadTransaction(provider, storeName);
    }
  }

  /*
  @deprecated // discouraged
  Future<Map> get(K key) async => (await super.get(key);
  */

  DbRecordProviderTransaction._fromList(
    this._provider,
    ProviderTransactionList list,
    String storeName,
  ) : super.fromList(list, storeName);

  DbRecordProviderTransaction._(
    DbRecordBaseProvider provider,
    String storeName, [
    bool readWrite = false,
  ]) : _provider = provider,
       super(provider.provider, storeName, readWrite);
}

class DbRecordProviderReadTransaction<T extends DbRecordBase?, K>
    extends DbRecordProviderTransaction<K> {
  DbRecordProviderReadTransaction(
    DbRecordBaseProvider provider,
    String storeName,
  ) : super._(provider, storeName, false);

  DbRecordProviderReadTransaction.fromList(
    super.provider,
    super.list,
    super.storeName,
  ) : super._fromList();
}

class DbRecordProviderWriteTransaction<T extends DbRecordBase, K>
    extends DbRecordProviderTransaction<K> {
  bool get _hasListener => _provider._hasListener;

  List<DbRecordProviderEvent> changes = [];

  DbRecordProviderWriteTransaction(
    DbRecordBaseProvider provider,
    String storeName,
  ) : super._(provider, storeName, true);

  DbRecordProviderWriteTransaction.fromList(
    super.provider,
    super.list,
    super.storeName,
  ) : super._fromList();

  Future<T> putRecord(T record, {bool? syncing}) {
    return super.put(record.toDbEntry(), record.id as K?).then((var key) {
      record.id = key;
      if (_hasListener) {
        changes.add(
          DbRecordProviderPutEvent()
            ..record = record
            ..syncing = syncing,
        );
      }
      return record;
    });
  }

  // ignore: avoid_shadowing_type_parameters
  Future<K> _throwError<K>() async =>
      throw UnsupportedError(
        'use putRecord, deleteRecord and clearRecords API',
      );

  @Deprecated('not supported, use record API')
  @override
  Future<K> add(Map value, [K? key]) => _throwError<K>();

  @Deprecated('not supported, use record API')
  @override
  Future<K> put(Map value, [K? key]) => _throwError<K>();

  @Deprecated('not supported, use record API')
  @override
  Future delete(K key) => _throwError();

  @Deprecated('not supported, use record API')
  @override
  Future clear() => _throwError();

  Future deleteRecord(K key, {bool? syncing}) {
    return super.delete(key).then((_) {
      if (_hasListener) {
        changes.add(
          DbRecordProviderDeleteEvent()
            ..key = key
            ..syncing = syncing,
        );
      }
    });
  }

  Future clearRecords({bool? syncing}) {
    return super.clear().then((_) {
      if (_hasListener) {
        changes.add(DbRecordProviderClearEvent()..syncing = syncing);
      }
    });
  }

  @override
  Future get completed {
    // delayed notification
    return super.completed.then((_) {
      if (_hasListener && changes.isNotEmpty) {
        for (final ctlr in _provider._onChangeCtlrs) {
          ctlr.add(changes);
        }
      }
    });
  }
}

///
/// A record provider is a provider of a given object type
/// in one store
///
abstract class DbRecordBaseProvider<T extends DbRecordBase, K> {
  late Provider provider;

  String get store;

  DbRecordProviderReadTransaction<T, K> get readTransaction =>
      DbRecordProviderReadTransaction<T, K>(this, store);

  DbRecordProviderWriteTransaction<T, K> get writeTransaction =>
      DbRecordProviderWriteTransaction<T, K>(this, store);

  DbRecordProviderReadTransaction<T, K> get storeReadTransaction =>
      readTransaction;

  DbRecordProviderWriteTransaction<T, K> get storeWriteTransaction =>
      writeTransaction;

  DbRecordProviderTransaction storeTransaction(bool? readWrite) =>
      DbRecordProviderTransaction<K>(this, store, readWrite);

  Future<T?> get(K id) async {
    var txn = provider.storeTransaction(store);
    final record = await _txnGet(txn, id);
    await txn.completed;
    return record;
  }

  T? fromEntry(Map? entry, K? id);

  //@deprecated
  Future<T?> txnGet(ProviderStoreTransaction txn, K id) => _txnGet(txn, id);

  Future<T?> _txnGet(ProviderStoreTransaction txn, K id) async {
    var entry = await txn.get(id);
    return fromEntry(entry as Map?, id);
  }

  Future<T?> indexGet(ProviderIndexTransaction txn, dynamic id) {
    return txn.get(id).then((Object? entry) {
      return txn.getKey(id).then((Object? primaryId) {
        return fromEntry(entry as Map?, primaryId as K?);
      });
    });
  }

  // transaction from a transaction list
  DbRecordProviderReadTransaction txnListReadTransaction(
    DbRecordProviderTransactionList txnList,
  ) => DbRecordProviderReadTransaction.fromList(this, txnList, store);

  DbRecordProviderWriteTransaction txnListWriteTransaction(
    DbRecordProviderWriteTransactionList txnList,
  ) => DbRecordProviderWriteTransaction.fromList(this, txnList, store);

  // Listener
  final List<StreamController> _onChangeCtlrs = [];

  Stream<List<DbRecordProviderEvent>> get onChange {
    var ctlr = StreamController<List<DbRecordProviderEvent>>(sync: true);
    _onChangeCtlrs.add(ctlr);
    return ctlr.stream;
  }

  void close() {
    for (final ctlr in _onChangeCtlrs) {
      ctlr.close();
    }
  }

  bool get _hasListener => _onChangeCtlrs.isNotEmpty;
}

abstract class DbRecordProvider<T extends DbRecord, K>
    extends DbRecordBaseProvider<T, K> {
  Future<T> put(T record) async {
    var txn = storeTransaction(true);
    record = await txnPut(
      txn as DbRecordProviderWriteTransaction<T, K>,
      record,
    );
    await txn.completed;
    return record;
  }

  Future<T> txnPut(DbRecordProviderWriteTransaction txn, T record) async =>
      (await txn.putRecord(record)) as T;

  Future delete(K key) async {
    var txn = storeTransaction(true);
    await txnDelete(txn as DbRecordProviderWriteTransaction, key);
    await txn.completed;
  }

  Future txnDelete(DbRecordProviderWriteTransaction txn, K key) =>
      txn.deleteRecord(key);

  Future clear() async {
    var txn = storeTransaction(true);
    await txnClear(txn as DbRecordProviderWriteTransaction);
    return txn.completed;
  }

  // Future txnClear(DbRecordProviderWriteTransaction txn) async { await txn.clearRecords(); }
  Future txnClear(DbRecordProviderWriteTransaction txn) => txn.clearRecords();
}

abstract class DbSyncedRecordProvider<T extends DbSyncedRecordBase, K>
    extends DbRecordBaseProvider<T, K> {
  static const String dirtyIndex = DbField.dirty;

  // must be int for indexing
  static const String syncIdIndex = DbField.syncId;

  ProviderIndexTransaction indexTransaction(
    String indexName, [
    bool? readWrite,
  ]) => ProviderIndexTransaction.fromStoreTransaction(
    storeTransaction(readWrite),
    indexName,
  );

  Future delete(K id, {bool? syncing}) async {
    var txn = storeTransaction(true);
    await txnDelete(
      txn as DbRecordProviderWriteTransaction,
      id,
      syncing: syncing,
    );
    await txn.completed;
  }

  Future txnRawDelete(DbRecordProviderWriteTransaction txn, K id) =>
      txn.deleteRecord(id);

  Future txnDelete(
    DbRecordProviderWriteTransaction txn,
    K id, {
    bool? syncing,
  }) {
    return txnGet(txn, id).then((T? existing) {
      if (existing != null) {
        // Not synced yet or from sync adapter
        if (existing.syncId == null || (syncing == true)) {
          return txnRawDelete(txn, id);
        } else if (!existing.deleted) {
          existing.deleted = true;
          existing.dirty = true;
          existing.version = existing.version! + 1;
          return txnRawPut(txn, existing);
        }
      }
      return null;
    });
  }

  Future<T?> getBySyncId(String syncId) async {
    final txn = indexTransaction(syncIdIndex);
    final id = await txn.getKey(syncId) as K?;
    T? record;
    if (id != null) {
      record = await txnGet(txn.store!, id);
    }
    await txn.completed;
    return record;
  }

  Future<T?> txnRawPut(DbRecordProviderWriteTransaction txn, T record) async {
    return (await txn.putRecord(record)) as T?;
  }

  Future<T?> txnPut(
    DbRecordProviderWriteTransaction txn,
    T record, {
    bool? syncing,
  }) {
    syncing = syncing == true;
    // remove deleted if set
    record.deleted = false;
    // never update sync info
    // dirty for not sync only
    if (syncing) {
      record.dirty = false;
    } else {
      // try to retrieve existing sync info
      // list.setSyncInfo(null, null);
      record.setSyncInfo(null, null);
      record.dirty = true;
    }
    Future<T?> doInsert() {
      record.version = 1;
      return txnRawPut(txn, record);
    }

    if (record.id != null) {
      return txnGet(txn, record.id as K).then((T? existingRecord) {
        if (existingRecord != null) {
          // if not syncing keep existing syncId and syncVersion
          if (syncing != true) {
            record.setSyncInfo(
              existingRecord.syncId,
              existingRecord.syncVersion,
            );
          }
          record.version = existingRecord.version! + 1;
          return txnRawPut(txn, record);
        } else {
          return doInsert();
        }
      });
    } else {
      return doInsert();
    }
  }

  Future clear({bool? syncing}) async {
    if (syncing != true) {
      throw UnimplementedError('force the syncing field to true');
    }
    var txn = storeTransaction(true);
    await txnClear(txn as DbRecordProviderWriteTransaction, syncing: syncing);
    return txn.completed;
  }

  Future txnClear(DbRecordProviderWriteTransaction txn, {bool? syncing}) {
    if (syncing != true) {
      throw UnimplementedError('force the syncing field to true');
    }
    return txn.clearRecords();
  }

  ///
  /// TODO: Put won't change data (which one) if local version has changed
  ///
  Future<T> put(T record, {bool? syncing}) async {
    var txn = storeTransaction(true);

    record =
        (await txnPut(
              txn as DbRecordProviderWriteTransaction,
              record,
              syncing: syncing,
            ))
            as T;
    await txn.completed;
    return record;
  }

  ///
  /// during sync, update the sync version
  /// if the local version has changed since, keep the dirty flag
  /// other data is not touched
  /// the dirty flag is only cleared if the local version has not changed
  ///
  Future updateSyncInfo(T record, String syncId, String syncVersion) async {
    var txn = storeTransaction(true);
    var existingRecord = await txnGet(txn, record.id as K);
    if (existingRecord != null) {
      // Check version before changing the dirty flag
      if (record.version == existingRecord.version) {
        existingRecord.dirty = false;
      }
      record = existingRecord;
    }
    record.setSyncInfo(syncId, syncVersion);
    await txnRawPut(txn as DbRecordProviderWriteTransaction, record);
    await txn.completed;
  }

  Future<T?> getFirstDirty() async {
    var txn = indexTransaction(dirtyIndex);
    var id = await txn.getKey(1) as K?; // 1 is dirty
    T? record;
    if (id != null) {
      record = await txnGet(txn.store!, id);
    }
    await txn.completed;
    return record;
  }

  /*
  // Delete all records with synchronisation information
  Future txnDeleteSyncedRecord(DbRecordProviderWriteTransaction txn) {
    ProviderIndexTransaction index =
        ProviderIndexTransaction.fromStoreTransaction(txn, syncIdIndex);
    index.openCursor().listen((idb.CursorWithValue cwv) {
      //print('deleting: ${cwv.primaryKey}');
      cwv.delete();
    });
  }
  */
}

// only for writable transaction
abstract class DbRecordProviderTransactionList extends ProviderTransactionList {
  DbRecordProvidersMixin _provider;

  factory DbRecordProviderTransactionList(
    DbRecordProvidersMixin provider,
    List<String> storeNames, [
    bool readWrite = false,
  ]) {
    if (readWrite) {
      return DbRecordProviderWriteTransactionList(provider, storeNames);
    } else {
      return DbRecordProviderReadTransactionList(provider, storeNames);
    }
  }

  //  DbRecordBaseProvider getRecordProvider(String storeName) =>      _provider.getRecordProvider(storeName);

  DbRecordProviderTransactionList._(
    DbRecordProvidersMixin provider,
    List<String> storeNames, [
    bool readWrite = false,
  ]) : _provider = provider,
       super(provider as Provider, storeNames, readWrite);
}

class DbRecordProviderReadTransactionList
    extends DbRecordProviderTransactionList {
  DbRecordProviderReadTransactionList(
    DbRecordProvidersMixin provider,
    List<String> storeNames,
  ) : super._(provider, storeNames, false);

  @override
  DbRecordProviderReadTransaction store(String storeName) {
    return DbRecordProviderReadTransaction.fromList(
      _provider.getRecordProvider(storeName)!,
      this,
      storeName,
    );
  }
}

class DbRecordProviderWriteTransactionList
    extends DbRecordProviderTransactionList {
  DbRecordProviderWriteTransactionList(
    DbRecordProvidersMixin provider,
    List<String> storeNames,
  ) : super._(provider, storeNames, true);

  @override
  DbRecordProviderTransaction store(String storeName) {
    return DbRecordProviderWriteTransaction.fromList(
      _provider.getRecordProvider(storeName)!,
      this,
      storeName,
    );
  }
}

mixin DbRecordProvidersMapMixin {
  late Map<String, DbRecordBaseProvider?> providerMap;

  void initAll(Provider provider) {
    for (final recordProvider in providerMap.values) {
      recordProvider!.provider = provider;
    }
  }

  DbRecordBaseProvider? getRecordProvider(String storeName) =>
      providerMap[storeName];

  void closeAll() {
    for (final recordProvider in recordProviders) {
      recordProvider.close();
    }
  }

  Iterable<DbRecordBaseProvider> get recordProviders =>
      providerMap.values.cast<DbRecordBaseProvider>();
}

mixin DbRecordProvidersMixin {
  DbRecordProviderReadTransactionList dbRecordProviderReadTransactionList(
    List<String> storeNames,
  ) => DbRecordProviderReadTransactionList(this, storeNames);

  DbRecordProviderWriteTransactionList writeTransactionList(
    List<String> storeNames,
  ) => DbRecordProviderWriteTransactionList(this, storeNames);

  DbRecordProviderWriteTransactionList dbRecordProviderWriteTransactionList(
    List<String> storeNames,
  ) => writeTransactionList(storeNames);

  // to implement
  DbRecordBaseProvider? getRecordProvider(String storeName);

  Iterable<DbRecordBaseProvider> get recordProviders;
}
