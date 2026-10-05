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

  @override
  void deleteStore(String storeName) {
    metas.remove(storeName);
    _deletedStoreNames.add(storeName);
  }

  /// Drop the deleted stores and write the schema.
  Future<void> commit(sembast.Transaction txn) async {
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
