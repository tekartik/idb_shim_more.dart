// ignore_for_file: public_member_api_docs

import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:sembast/sembast.dart' as sembast;
import 'package:tekartik_sdb_sembast/src/sembast/sdb_import.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_factory.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_meta.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_open.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_transaction.dart';

import 'sdb_sembast_client.dart';

/// Sembast based database
abstract class SdbDatabaseSembast implements SdbDatabase {}

/// Private implementation of [SdbDatabaseSembast].
///
/// The schema (stores, key paths, indexes) is kept in a sembast store, see
/// [sdbSembastMetaStore], read at open and changed during version changes.
class SdbDatabaseSembastPrv
    with SdbClientInterfaceDefaultMixin, SdbDatabaseDefaultMixin
    implements SdbDatabaseSembast, SdbClientInterface, SdbClientSembast {
  @override
  SdbDatabase get db => this;
  @override
  final SdbFactorySembast factory;
  @override
  final String name;
  int? get _openVersion => options.version;
  @override
  int get version => _sembastDatabase!.version;

  sembast.Database? _sembastDatabase;
  bool _closed = false;

  /// The schema, by store name.
  var _metas = <String, SdbStoreMetaSembast>{};

  final SdbOpenDatabaseOptions options;

  /// Sembast database.
  SdbDatabaseSembastPrv({
    required this.factory,
    required this.name,
    required this.options,
  }) : codec = options.codec ?? SdbCodec.defaultCodec;

  @override
  final SdbCodec codec;

  @override
  SdbOpenDatabaseOptions? get openOptions => options;

  /// The store definition, null if unknown.
  SdbStoreMetaSembast? storeMeta(String name) => _metas[name];

  /// The sembast database, throws if not open or closed.
  sembast.Database get sembastDatabase {
    var db = _sembastDatabase;
    if (db == null || _closed) {
      throw StateError('Database $name is not open');
    }
    return db;
  }

  /// Open the database, applying the schema and calling onVersionChange on
  /// version change, in one sembast transaction.
  Future<void> open() async {
    var sembastFactory = factory.sembastFactory;
    var schema = options.schema;
    var onVersionChange = options.onVersionChange;
    var versionChanged = false;
    _sembastDatabase = await sembastFactory.openDatabase(
      name,
      version: _openVersion,
      onVersionChanged: (db, oldVersion, newVersion) async {
        versionChanged = true;
        // The object returned by openDatabase, needed during the change.
        _sembastDatabase = db;
        if (newVersion < oldVersion) {
          // sembast would happily downgrade, idb does not.
          throw StateError(
            'Downgrade of $name from version $oldVersion to $newVersion'
            ' not supported',
          );
        }
        await db.transaction((txn) async {
          var metas = await sdbSembastReadMetas(txn);
          var openDatabase = SdbOpenDatabaseSembastPrv(
            sembastSdbDatabase: this,
            metas: metas,
          );
          var openTransaction = openDatabase.transaction =
              SdbOpenTransactionSembastPrv(
                openDatabase: openDatabase,
                sdbTransactionSembast: txn,
                storeNames: const [],
                mode: SdbTransactionMode.readWrite,
              );
          var event = SdbVersionChangeEvent(
            db: openDatabase,
            transaction: openTransaction,
            oldVersion: oldVersion,
            newVersion: newVersion,
          );
          if (schema != null) {
            SchemaSdbDatabasePrvExtension.applySchema(event, schema);
          }
          if (onVersionChange != null) {
            await onVersionChange(event);
          }
          await openDatabase.commit(txn);
          _metas = openDatabase.metas;
        });
      },
    );
    if (!versionChanged) {
      _metas = await sdbSembastReadMetas(_sembastDatabase!);
      if (isDebug && schema != null) {
        try {
          await checkSchema(schema);
        } catch (e) {
          await close();
          rethrow;
        }
      }
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _sembastDatabase?.close();
  }

  @override
  bool get isClosed => _closed;

  @override
  sembast.DatabaseClient get sembastDatabaseClient => sembastDatabase;

  @override
  Iterable<String> get storeNames => _metas.keys;

  @override
  Future<T> clientHandleDbOrTxn<T>(
    Future<T> Function(SdbDatabase db) dbFn,
    Future<T> Function(SdbTransaction txn) txnFn,
  ) => dbFn(this);

  @override
  Future<K> sdbAddImpl<K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    V value,
  ) => inStoreTransaction<K, K, V>(
    store,
    SdbTransactionMode.readWrite,
    (txn) => txn.add(value),
  );

  /// Run [callback] on a new sdb transaction wrapping a sembast transaction,
  /// the change listeners included, then notify the other connections of the
  /// stores written.
  Future<T> _inTransaction<T, TXN extends SdbTransactionSembast>(
    TXN Function(sembast.Transaction sembastTxn) newTransaction,
    FutureOr<T> Function(TXN txn) callback,
  ) async {
    late TXN txn;
    var result = await sembastDatabase.transaction((sembastTxn) {
      txn = newTransaction(sembastTxn);
      return txn.runWithChangesListener(() => callback(txn));
    });
    txn.broadcastWrittenStores();
    return result;
  }

  @override
  Future<T> inStoreTransaction<T, K extends SdbKey, V extends SdbValue>(
    SdbStoreRef<K, V> store,
    SdbTransactionMode mode,
    FutureOr<T> Function(SdbSingleStoreTransaction<K, V> txn) callback,
  ) => _inTransaction(
    (sembastTxn) => SdbSingleStoreTransactionSembast<K, V>(
      db: this,
      sdbTransactionSembast: sembastTxn,
      store: store,
      mode: mode,
    ),
    callback,
  );

  @override
  Future<T> inStoresTransaction<T>(
    List<SdbStoreRef> stores,
    SdbTransactionMode mode,
    FutureOr<T> Function(SdbMultiStoreTransaction txn) callback,
  ) => _inTransaction(
    (sembastTxn) => SdbMultiStoreTransactionSembast(
      db: this,
      sdbTransactionSembast: sembastTxn,
      storeNames: stores.names,
      mode: mode,
    ),
    callback,
  );

  /// Run a transaction, use either [storeNames] or [stores], mode defaults to
  /// read only.
  @override
  Future<T> inTransaction<T>({
    List<String>? storeNames,
    List<SdbStoreRef>? stores,
    SdbTransactionMode? mode,
    required FutureOr<T> Function(SdbTransaction txn) run,
  }) {
    var names = storeNames ?? stores?.names;
    if (names == null || names.isEmpty) {
      throw ArgumentError(
        'Either storeNames ($storeNames) or stores ($stores) must be provided',
      );
    }
    return _inTransaction(
      (sembastTxn) => SdbMultiStoreTransactionSembast(
        db: this,
        sdbTransactionSembast: sembastTxn,
        storeNames: names,
        mode: mode ?? SdbTransactionMode.readOnly,
      ),
      run,
    );
  }

  @override
  String toString() => 'SdbDatabaseSembast($name, v$version)';
}

extension SdbSembastDatabasePrvExt on SdbDatabase {
  SdbDatabaseSembastPrv get impl => this as SdbDatabaseSembastPrv;
}
