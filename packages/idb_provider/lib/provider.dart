library;

import 'package:idb_shim/idb_client.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_idb_provider/provider.dart';

export 'package:tekartik_idb_provider/src/provider/provider_meta.dart';
export 'package:tekartik_idb_provider/src/provider/provider_row.dart';
export 'package:tekartik_idb_provider/src/provider/provider_transaction.dart';

class DynamicProvider extends Provider {
  final List<ProviderStoreMeta?> _storeMetas = [];

  @override
  void onUpdateDatabase(VersionChangeEvent e) {
    for (var meta in _storeMetas) {
      var store = db!.createStore(meta!);
      for (var indexMeta in meta.indecies) {
        store.createIndex(indexMeta!);
      }
    }
  }

  // to call before ready
  void addStore(ProviderStoreMeta? storeMeta) {
    _storeMetas.add(storeMeta);
  }

  // to call before ready
  void addStores(ProviderStoresMeta storesMeta) {
    for (final storeMeta in storesMeta.stores) {
      addStore(storeMeta);
    }
  }

  DynamicProvider.noMeta(IdbFactory? idbFactory) {
    _idbFactory = idbFactory;
  }

  DynamicProvider(IdbFactory? idbFactory, [ProviderDbMeta? meta]) {
    _idbFactory = idbFactory;
    _databaseMeta = meta;
  }
}

abstract class Provider {
  IdbFactory? _idbFactory;
  ProviderDb? _db;
  ProviderDbMeta? _databaseMeta;

  IdbFactory? get idbFactory => _idbFactory;

  ProviderDb? get db => _db;

  Provider();

  Provider.fromIdb(Database idbDatabase) {
    _setDatabase(idbDatabase);
    _databaseMeta = db!.meta;
  }

  //AppProvider(this.idbFactory);
  void init(IdbFactory? idbFactory, String dbName, int dbVersion) {
    _idbFactory = idbFactory;
    _databaseMeta = ProviderDbMeta(dbName, dbVersion);
  }

  // when everything ready
  void _setDatabase(Database db) {
    _db = ProviderDb(db);
  }

  // must be set before being ready
  // The provider take ownership of the database
  set db(ProviderDb? db) {
    if (db == null) {
      _db = null;
      _ready = null;
      _readyCompleter = null;
    } else {
      if (_ready != null) {
        throw 'ready should not have been called before setting the db';
      } else {
        _readyCompleter = Completer.sync();
        _db = db;
        _idbFactory = db.factory;
        _databaseMeta = _db!.meta;

        _ready = _readyCompleter!.future;
        _readyCompleter!.complete(this);
      }
    }
  }

  Database? get database => db!.database;

  // must be set before being ready
  // The provider take ownership of the database
  set database(Database? db) {
    if (db == null) {
      _db = null;
      _ready = null;
      _readyCompleter = null;
    } else {
      if (_ready != null) {
        throw 'ready should not have been called before setting the db';
      } else {
        _readyCompleter = Completer.sync();
        _setDatabase(db);
        _idbFactory = db.factory;
        _databaseMeta = _db!.meta;

        _ready = _readyCompleter!.future;
        _readyCompleter!.complete(this);
      }
    }
  }

  // during onUpdateOnly

  void close() {
    if (db != null) {
      db!.close();
      _db = null;
      _ready = null;
      _readyCompleter = null;
    }
  }

  // delete content
  Future clear() {
    final storeNames = db!.database!.objectStoreNames.toList(growable: false);
    var globalTrans = ProviderTransactionList(this, storeNames, true);
    final futures = <Future<Object?>>[];
    for (final storeName in storeNames) {
      var trans = globalTrans.store(storeName);
      futures.add(trans.clear());
    }
    return Future.wait(futures).then<Object?>((_) {
      return globalTrans.completed;
    });
  }

  // check if database is still opened
  bool get isClosed => (_db == null) && (_ready == null);

  // to implement
  void onUpdateDatabase(VersionChangeEvent e);

  void _onUpdateDatabase(VersionChangeEvent e) {
    _setDatabase(e.database);
    onUpdateDatabase(e);
  }

  Future<ProviderStoresMeta>? _storesMeta;

  Future<ProviderStoresMeta>? get storesMeta {
    _storesMeta ??= Future.sync(() {
      final metas = <ProviderStoreMeta?>[];

      var storeNames = db!.storeNames.toList();
      final txn = transactionList(storeNames);
      for (final storeName in storeNames) {
        metas.add(txn.store(storeName).store!.meta);
      }
      return txn.completed.then((_) {
        final meta = ProviderStoresMeta(metas);
        return meta;
      });
    });

    return _storesMeta;
  }

  //      Database db = e.database;
  //      int version = e.oldVersion;
  //
  //      if (e.oldVersion == 1) {
  //        db.deleteObjectStore(FILES_STORE);
  //
  //        // dev bug
  //        if (db.objectStoreNames.contains(METAS_STORE)) {
  //          db.deleteObjectStore(METAS_STORE);
  //        }
  //      }
  //
  //      var objectStore = db.createObjectStore(FILES_STORE, autoIncrement: true);
  //      Index index = objectStore.createIndex(NAME_INDEX, NAME_FIELD, unique: true);
  //
  //
  //      var metaStrore = db.createObjectStore(METAS_STORE, autoIncrement: true);
  //      Index fileIndex = metaStrore.createIndex(FILE_ID_INDEX, FILE_ID_FIELD, unique: true);
  //    }

  //  Stream<CursorWithValue> Future<List<MetaRow>> metaCursorToList(Stream<CursorWithValue> stream) {
  //      List<MetaRow> list = new List();
  //      return stream.listen((CursorWithValue cwv) {
  //        MetaRow row = new MetaRow.fromCursor(cwv);
  //
  //        list.add(row);
  //        cwv.next();
  //      }).asFuture(list);
  //    }

  Future delete() {
    close();
    return idbFactory!.deleteDatabase(_databaseMeta!.name);
  }

  Future<Provider>? _ready;
  Completer<Provider>? _readyCompleter;

  bool get isReady => _readyCompleter != null && _readyCompleter!.isCompleted;

  Future<Provider>? get ready {
    if (_ready == null) {
      _readyCompleter = Completer.sync();

      _ready = _readyCompleter!.future;

      runZonedGuarded(
        () {
          return _idbFactory!
              .open(
                _databaseMeta!.name,
                version: _databaseMeta!.version,
                onUpgradeNeeded: _onUpdateDatabase,
              )
              .then((Database db) {
                _setDatabase(db);
                _readyCompleter!.complete(this);
              });
        },
        (e, StackTrace st) {
          print('open failed');
          print(e);
          print(st);
          _readyCompleter!.completeError(e, st);
        },
      );
    }
    return _ready;
  }

  // default read-only
  ProviderStoreTransaction storeTransaction(
    String storeName, [
    bool readWrite = false,
  ]) {
    return ProviderStoreTransaction(this, storeName, readWrite);
  }

  // default read-only
  ProviderIndexTransaction indexTransaction(
    String storeName,
    String indexName, [
    bool readWrite = false,
  ]) {
    return ProviderIndexTransaction(this, storeName, indexName, readWrite);
  }

  ProviderTransactionList transactionList(
    List<String> storeNames, [
    bool readWrite = false,
  ]) {
    return ProviderTransactionList(this, storeNames, readWrite);
  }

  Map toMap() {
    final map = <String, Object?>{};
    if (_db != null) {
      map['db'] = _db!.database!.name;
    }
    return map;
  }

  @override
  String toString() => toMap().toString();
}
