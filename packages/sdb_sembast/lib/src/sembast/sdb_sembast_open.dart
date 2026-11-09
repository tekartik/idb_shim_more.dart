// ignore_for_file: implementation_imports, public_member_api_docs

import 'package:sembast/sembast.dart' as sembast;
import 'package:tekartik_sdb_sembast/src/sembast/sdb_import.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_database.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_meta.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_transaction.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_transaction_index.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_transaction_store.dart';

/// The transaction of a version change, its stores are open stores and the
/// schema it sees is the working copy of [SdbOpenDatabaseSembastPrv].
class SdbOpenTransactionSembastPrv extends SdbTransactionSembast
    implements SdbOpenTransaction {
  @override
  final SdbOpenDatabaseSembastPrv openDatabase;

  SdbOpenTransactionSembastPrv({
    required this.openDatabase,
    required super.sdbTransactionSembast,
    required super.storeNames,
    required super.mode,
  }) : super(db: openDatabase.sembastSdbDatabase);

  @override
  SdbStoreMetaSembast? storeMeta(String name) => openDatabase.metas[name];

  /// No change listener during a version change.
  @override
  SdbDatabaseChangesListener? get changesListener => null;

  /// The stores, including the ones created during the version change.
  @override
  List<String> get storeNames => openDatabase.metas.keys.toList();

  @override
  SdbTransactionStoreRefSembast<K, V>
  newTxnStore<K extends SdbKey, V extends SdbValue>(SdbStoreRef<K, V> store) =>
      SdbOpenStoreRefSembast<K, V>(transaction: this, store: store);
}

/// Database during a version change, works on a copy of the schema written
/// back by [commit].
class SdbOpenDatabaseSembastPrv implements SdbOpenDatabase {
  final SdbDatabaseSembastPrv sembastSdbDatabase;

  /// Working copy of the schema, by store name.
  final Map<String, SdbStoreMetaSembast> metas;

  /// Stores deleted during the version change, dropped on [commit].
  final _deletedStoreNames = <String>{};

  /// Set right after creation.
  late SdbOpenTransactionSembastPrv transaction;

  SdbOpenDatabaseSembastPrv({
    required this.sembastSdbDatabase,
    required this.metas,
  });

  SdbOpenStoreRefSembast<K, V> _openStore<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
  ) => transaction.txnStoreInterface(store) as SdbOpenStoreRefSembast<K, V>;

  @override
  SdbOpenStoreRef<K, V> createStore<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store, {
    Object? keyPath,
    bool? autoIncrement,
  }) {
    var name = store.name;
    if (metas.containsKey(name)) {
      throw StateError('Store $name already exists');
    }
    metas[name] = SdbStoreMetaSembast(
      name: name,
      keyPath: keyPath == null ? null : sdbKeyPathFromAny(keyPath),
      // Like idb: int keys auto increment unless said otherwise.
      autoIncrement: autoIncrement ?? (K == int),
    );
    return _openStore(store);
  }

  @override
  SdbOpenStoreRef<K, V> objectStore<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
  ) {
    if (!metas.containsKey(store.name)) {
      throw StateError('Store ${store.name} not found');
    }
    return _openStore(store);
  }

  @override
  Iterable<String> get objectStoreNames => metas.keys;

  /// The drops of the deleted stores, chained on the version change
  /// transaction. As idb, a deleted store has no record left, even when
  /// created again in the same version change: every store operation of the
  /// version change waits for them.
  Future<void>? _drops;

  /// Completes once the stores deleted so far are dropped, null if none was.
  Future<void>? get pendingDrops => _drops;

  @override
  void deleteStore(String storeName) {
    metas.remove(storeName);
    _deletedStoreNames.add(storeName);
    var txn = transaction.sdbTransactionSembast;
    var previous = _drops ?? Future<void>.value();
    // The error, if any, is reported by the next operation and by commit.
    _drops = previous.then(
      (_) => sembast.StoreRef<Object, Object>(storeName).drop(txn),
    )..ignore();
  }

  /// Drop the deleted stores and write the schema.
  Future<void> commit(sembast.Transaction txn) async {
    await _drops;
    // Records written to a deleted store not created again.
    for (var name in _deletedStoreNames) {
      if (!metas.containsKey(name)) {
        await sembast.StoreRef<Object, Object>(name).drop(txn);
      }
    }
    await sdbSembastWriteMetas(txn, metas);
  }
}

/// Open store: a transaction store that can also change the indexes.
class SdbOpenStoreRefSembast<K extends SdbKey, V extends SdbValue>
    extends SdbTransactionStoreRefSembast<K, V>
    implements SdbOpenStoreRefInterface<K, V> {
  SdbOpenStoreRefSembast({required super.transaction, required super.store});

  /// Run [action] once the stores deleted so far are dropped.
  Future<T> _afterDrops<T>(Future<T> Function() action) async {
    var drops =
        (transaction as SdbOpenTransactionSembastPrv).openDatabase.pendingDrops;
    if (drops != null) {
      await drops;
    }
    return await action();
  }

  @override
  Future<List<SdbRawRecordSembast<K>>> findAllRaw() =>
      _afterDrops(super.findAllRaw);

  @override
  Future<SdbRecordSnapshot<K, V>?> getRecordImpl(K key) =>
      _afterDrops(() => super.getRecordImpl(key));

  @override
  Future<bool> existsImpl(K key) => _afterDrops(() => super.existsImpl(key));

  @override
  Future<K> addImpl(V value) => _afterDrops(() => super.addImpl(value));

  @override
  Future<void> putImpl(K? key, V value) =>
      _afterDrops(() => super.putImpl(key, value));

  @override
  Future<void> putRawImpl(K key, Object rawValue) =>
      _afterDrops(() => super.putRawImpl(key, rawValue));

  @override
  Future<void> deleteImpl(K key) => _afterDrops(() => super.deleteImpl(key));

  @override
  Future<List<SdbRecordSnapshot<K, V>>> findRecordsImpl({
    required SdbFindOptions<K> options,
  }) => _afterDrops(() => super.findRecordsImpl(options: options));

  @override
  Future<void> iterateImpl({
    required SdbFindOptions<K> options,
    required SdbCursorRowHandler<K, V> handler,
  }) =>
      _afterDrops(() => super.iterateImpl(options: options, handler: handler));

  @override
  Future<List<SdbRecordKey<K, V>>> findRecordKeysImpl({
    required SdbFindOptions<K> options,
  }) => _afterDrops(() => super.findRecordKeysImpl(options: options));

  @override
  Future<int> countImpl({required SdbFindOptions<K> options}) =>
      _afterDrops(() => super.countImpl(options: options));

  @override
  Future<void> deleteRecordsImpl({required SdbFindOptions<K> options}) =>
      _afterDrops(() => super.deleteRecordsImpl(options: options));

  SdbStoreMetaSembast get _meta =>
      meta ?? (throw StateError('Store ${store.name} not found'));

  @override
  SdbOpenIndexRef<K, V, I> createIndexImpl<I extends SdbIndexKey>(
    SdbIndexRef<K, V, I> index,
    Object indexKeyPath, {
    required bool? unique,
  }) {
    var meta = _meta;
    var name = index.name;
    if (meta.indexes.containsKey(name)) {
      throw StateError('Index $name already exists in store ${store.name}');
    }
    meta.indexes[name] = SdbIndexMetaSembast(
      name: name,
      keyPath: sdbKeyPathFromAny(indexKeyPath),
      unique: unique ?? false,
    );
    return SdbTransactionIndexRefSembast<K, V, I>(store: this, ref: index);
  }

  @override
  void deleteIndex(String indexName) {
    _meta.indexes.remove(indexName);
  }
}
