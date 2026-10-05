// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:sembast/sembast.dart' as sembast;
import 'package:tekartik_sdb_sembast/src/sembast/sdb_import.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_client.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_database.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_meta.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_transaction_store.dart';

/// Sembast based transaction, base of the single store, multi store and open
/// transactions.
///
/// Wraps one sembast transaction, every sdb operation runs on it.
class SdbTransactionSembast
    with SdbClientInterfaceDefaultMixin, SdbTransactionChangesDefaultMixin
    implements SdbTransactionInterface, SdbClientSembast {
  @override
  final SdbDatabaseSembast db;
  @override
  final SdbTransactionMode mode;
  @override
  final List<String> storeNames;

  /// Sembast transaction
  final sembast.Transaction sdbTransactionSembast;

  /// Transaction stores, created on demand.
  final _txnStores = <String, SdbTransactionStoreRefSembast>{};

  SdbTransactionSembast({
    required this.db,
    required this.sdbTransactionSembast,
    required this.storeNames,
    required this.mode,
  });

  @override
  Future<T> clientHandleDbOrTxn<T>(
    Future<T> Function(SdbDatabase db) dbFn,
    Future<T> Function(SdbTransaction txn) txnFn,
  ) => txnFn(this);

  @override
  sembast.DatabaseClient get sembastDatabaseClient => sdbTransactionSembast;

  @override
  SdbCodec get codec => db.impl.codec;

  /// The store definition from the database schema, the working copy during
  /// a version change.
  SdbStoreMetaSembast? storeMeta(String name) => db.impl.storeMeta(name);

  /// Create a transaction store, open transactions create open stores.
  SdbTransactionStoreRefSembast<K, V>
  newTxnStore<K extends SdbKey, V extends SdbValue>(SdbStoreRef<K, V> store) =>
      SdbTransactionStoreRefSembast<K, V>(transaction: this, store: store);

  @override
  SdbTransactionStoreRefInterface<K, V> txnStoreInterface<
    K extends SdbKey,
    V extends SdbValue
  >(SdbStoreRef<K, V> store) {
    var txnStore = _txnStores[store.name];
    if (txnStore is SdbTransactionStoreRefSembast<K, V>) {
      return txnStore;
    }
    var created = newTxnStore<K, V>(store);
    _txnStores[store.name] = created;
    return created;
  }

  @override
  Future<K> sdbAddImpl<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    V value,
  ) => txnStoreInterface(store).addImpl(value);

  @override
  String toString() => 'SdbTransactionSembast($mode, $storeNames)';
}

/// Single store transaction.
class SdbSingleStoreTransactionSembast<K extends SdbKey, V extends SdbValue>
    extends SdbTransactionSembast
    implements SdbSingleStoreTransaction<K, V> {
  final SdbStoreRef<K, V> store;

  SdbSingleStoreTransactionSembast({
    required super.db,
    required super.sdbTransactionSembast,
    required this.store,
    required super.mode,
  }) : super(storeNames: [store.name]);

  @override
  SdbTransactionStoreRef<K, V> get txnStore => txnStoreInterface(store);
}

/// Multi store transaction.
class SdbMultiStoreTransactionSembast extends SdbTransactionSembast
    implements SdbMultiStoreTransaction {
  SdbMultiStoreTransactionSembast({
    required super.db,
    required super.sdbTransactionSembast,
    required super.storeNames,
    required super.mode,
  });
}
