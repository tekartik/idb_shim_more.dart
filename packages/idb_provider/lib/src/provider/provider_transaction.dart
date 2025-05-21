import 'package:idb_shim/idb.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_idb_provider/provider.dart';

class ProviderIndexTransaction<K, V> extends Object
    with ProviderSourceTransactionMixin<K, V?> {
  Future get completed => _store!.completed;

  ProviderStoreTransaction<K, V>? _store;
  ProviderStoreTransaction<K, V>? get store => _store;

  ProviderIndexTransaction.fromStoreTransaction(this._store, String indexName) {
    _index = _store!.store!.index(indexName);
  }
  //ProviderIndex get index => _index;
  //ProviderStore get store => this;
  //ProviderStore get store => super._store;

  @override
  Future<V?> get(K key) async {
    return await _index.index.get(key!) as V?;
  }

  Future getKey(K key) {
    return _index.index.getKey(key!);
  }

  late ProviderIndex _index;
  ProviderIndexTransaction(
    Provider provider,
    String storeName,
    String indexName, [
    bool readWrite = false,
  ]) //
  {
    _store = ProviderStoreTransaction(provider, storeName, readWrite);
    _index = _store!.store!.index(indexName);
  }

  @override
  Future<int> count() => _index.count();

  @override
  Stream<CursorWithValue> openRawCursor({K? key, String? direction}) {
    return _index.index.openCursor(
      //
      key: key,
      direction: direction,
    );
  }

  // @override
  Stream<Cursor> openRawKeyCursor({K? key, String? direction}) {
    return _index.index.openKeyCursor(
      //
      key: key,
      direction: direction,
    );
  }

  Stream<Cursor> openKeyCursor({
    K? key,
    bool reverse = false,
    int? limit,
    int? offset,
  }) {
    final direction = reverse ? idbDirectionPrev : null;
    final stream = openRawKeyCursor(key: key, direction: direction);
    return _limitOffsetStream(stream, limit: limit, offset: offset);
  }

  //@override
  Stream<CursorWithValue> openCursor({
    K? key,
    bool reverse = false,
    int? limit,
    int? offset,
  }) {
    final direction = reverse ? idbDirectionPrev : null;
    final stream = openRawCursor(key: key, direction: direction);
    return _limitOffsetStream(stream, limit: limit, offset: offset);
  }
}

class RawProviderStoreTransaction
    extends ProviderStoreTransaction<Object, Object> {
  RawProviderStoreTransaction(
    super.provider,
    super.storeName, [
    super.readWrite,
  ]);
}

class ProviderStoreTransaction<K, V>
    extends ProviderStoreTransactionBase<K, V> {
  @protected
  ProviderStoreTransaction(super.provider, super.storeName, [super.readWrite]);

  @protected
  ProviderStoreTransaction.fromList(
    ProviderTransactionList list,
    String storeName,
  ) : super._() {
    _transaction = list._transaction;
    _mode = list._mode;
    _store = ProviderStore(_transaction!.objectStore(storeName));
  }
}

class WriteTransactionMixin {}

abstract class ProviderWritableSourceTransactionMixin<K, V>
    implements
        ProviderSourceTransaction<K, V>,
        ProviderWritableSourceTransaction<K, V> {
  late ProviderStore _store;

  @override
  Future<K> add(V value, [K? key]) async {
    return await _store.objectStore.add(value!, key) as K;
  }

  @override
  Future<K> put(V value, [K? key]) async {
    return await _store.objectStore.put(value!, key) as K;
  }

  @override
  Future<V?> get(K key) async {
    return await _store.objectStore.getObject(key!) as V?;
  }
}

abstract class ProviderSourceTransaction<K, V> {
  /// Get an object by key
  Future<V?> get(K key);
}

mixin ProviderSourceTransactionMixin<K, V>
    implements ProviderSourceTransaction<K, V> {
  //Future<V?> get(K key);
  Future<int> count();
  Stream<CursorWithValue> openRawCursor({String? direction});

  Stream<T> _limitOffsetStream<T extends Cursor>(
    Stream<T> rawStream, {
    int? limit,
    int? offset,
  }) {
    final ctlr = StreamController<T>(sync: true);

    var count = 0;

    void close() {
      if (!ctlr.isClosed) {
        ctlr.close();
      }
    }

    void onCursorValue(T c) {
      if (offset != null && offset > 0) {
        c.advance(offset);
      } else {
        if (limit != null) {
          if (count >= limit) {
            // stop here
            close();
            return;
          }
        }
        ctlr.add(c);
        count++;
        c.next();
      }
    }

    rawStream.listen(
      onCursorValue,
      onDone: () {
        close();
      },
    );

    //}).asFuture() {
    return ctlr.stream;
  }
}

abstract class ProviderWritableSourceTransaction<K, V>
    implements ProviderSourceTransaction<K, V> {
  /// Add an object
  Future<K> add(V value, [K? key]);

  /// Put an object
  Future<K> put(V value, [K? key]);
}

class ProviderStoreTransactionBase<K, V> extends ProviderTransaction
    with
        ProviderStoreTransactionMixin<K, V>,
        ProviderSourceTransactionMixin<K, V> {
  ProviderStore? _store;

  // not recommended though
  //@deprecated
  @override
  ProviderStore? get store => _store;

  ProviderStoreTransactionBase._();

  ProviderStoreTransactionBase(
    Provider provider,
    String storeName, [
    bool readWrite = false,
  ]) {
    _mode = readWrite ? idbModeReadWrite : idbModeReadOnly;

    try {
      _transaction = provider.db!.database!.transaction(storeName, _mode!);
    } catch (e) {
      // typically db might have been closed so add some debug information
      if (provider.isClosed) {
        print('database has been closed');
      }
      rethrow;
    }
    _store = ProviderStore(_transaction!.objectStore(storeName));
  }

  @override
  Stream<CursorWithValue> openRawCursor({String? direction}) {
    return store!.objectStore.openCursor(
      //
      direction: direction,
    );
  }

  Stream<CursorWithValue> openCursor({
    bool reverse = false,
    int? limit,
    int? offset,
  }) {
    final direction = reverse ? idbDirectionPrev : null;
    final stream = openRawCursor(direction: direction);
    return _limitOffsetStream(stream, limit: limit, offset: offset);
  }
}

mixin ProviderStoreTransactionMixin<K, V> {
  ProviderStore? get store;

  ProviderIndexTransaction<K, V> index(String name) =>
      ProviderIndexTransaction.fromStoreTransaction(
        this as ProviderStoreTransaction<K, V>,
        name,
      );

  Future<int> count() => store!.count();

  Future<V?> get(K key) async {
    final value = await store!.get(key!);
    return value as V?;
  }

  Future<K> add(V value, [K? key]) async =>
      (await store!.add(value!, key)) as K;

  Future<K> put(V value, [K? key]) async =>
      (await store!.put(value!, key)) as K;

  Future delete(K key) => store!.delete(key!);

  Future clear() => store!.clear();
}

//class _ProviderStoreInTransactionList extends Object with ProviderStoreTransactionMixin {
//  final ProviderStore store;
//  _ProviderStoreInTransactionList(this.store);
//}

class ProviderTransactionList extends ProviderTransaction {
  ProviderTransactionList(
    Provider provider,
    Iterable<String> storeNames, [
    bool readWrite = false,
  ]) {
    _mode = readWrite ? idbModeReadWrite : idbModeReadOnly;
    _transaction = provider.db!.database!.transactionList(
      storeNames.toList(),
      _mode!,
    );
  }
  ProviderStoreTransaction store(String storeName) {
    return ProviderStoreTransaction.fromList(this, storeName);
  }

  ProviderIndexTransaction index(String storeName, String indexName) =>
      store(storeName).index(indexName);
}

class ProviderTransaction {
  //Provider _provider;
  Transaction? _transaction;
  String? _mode;

  bool get readWrite => _mode == idbModeReadWrite;
  bool get readOnly => _mode == idbModeReadOnly;
  Future<void> get completed => _transaction!.completed;

  //
  //  Future<int> add(Map<String, dynamic> data) {
  //    if (_store != null) {
  //      return _store.add(data);
  //    }
  //    // should crash then
  //    return null;
  //  }
  //
  //  Future<Map<String, dynamic>> getById(int id) {
  //    if (_index != null) {
  //      return _index.get(id);
  //
  //    } else if (_store != null) {
  //      return _store.getObject(id);
  //    }
  //    // should crash then
  //    return null;
  //  }
}
