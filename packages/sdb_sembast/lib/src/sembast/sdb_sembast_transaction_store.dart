// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:sembast/sembast.dart' as sembast;
import 'package:tekartik_sdb_sembast/src/sembast/sdb_import.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_meta.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_transaction.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_transaction_index.dart';

/// Skip [offset] items then keep [limit] items, when positive.
Iterable<T> sdbSembastOffsetLimit<T>(
  Iterable<T> iterable, {
  int? offset,
  int? limit,
}) {
  if (offset != null && offset > 0) {
    iterable = iterable.skip(offset);
  }
  if (limit != null && limit > 0) {
    iterable = iterable.take(limit);
  }
  return iterable;
}

int? _positiveOrNull(int? value) => (value != null && value > 0) ? value : null;

/// A record read from sembast: its key and its raw (codec encoded) value in
/// the idb form (DateTime, Uint8List), see [SdbTransactionStoreRefSembast].
class SdbRawRecordSembast<K extends SdbKey> {
  final K key;
  final Object rawValue;

  SdbRawRecordSembast({required this.key, required this.rawValue});
}

/// Sembast based transaction store.
///
/// Values are stored encoded with the database codec, like the idb
/// implementation does, keys are the sembast keys (int or String). The idb
/// native types the codec lets through (DateTime, Uint8List) are written as
/// sembast ones (Timestamp, Blob) and converted back when read, the mapping
/// of the sembast based idb factory. What sembast cannot store (a Timestamp
/// with [SdbCodec.none] for example) throws, like idb does.
///
/// The store definition (key path, auto increment, indexes) comes from the
/// schema store of the database, see [SdbStoreMetaSembast].
///
/// Boundaries, sort order, offset and limit are pushed to sembast. A filter is
/// applied in dart on the decoded value, offset and limit then applied after
/// it, like the idb cursor path.
class SdbTransactionStoreRefSembast<K extends SdbKey, V extends SdbValue>
    implements SdbTransactionStoreRefInterface<K, V> {
  @override
  final SdbTransactionSembast transaction;
  @override
  final SdbStoreRef<K, V> store;

  /// The sembast store, values are the encoded values in their sembast form.
  late final sembastStore = sembast.StoreRef<K, Object>(store.name);

  SdbTransactionStoreRefSembast({
    required this.transaction,
    required this.store,
  });

  /// The sembast client to use (the transaction).
  sembast.DatabaseClient get sembastClient => transaction.sembastDatabaseClient;

  /// The store definition, null for a store unknown to the schema.
  SdbStoreMetaSembast? get meta => transaction.storeMeta(store.name);

  SdbCodec get _codec => transaction.codec;

  void _checkWrite() {
    if (transaction.mode != SdbTransactionMode.readWrite) {
      throw StateError('Read only transaction on store ${store.name}');
    }
  }

  /// The raw record of a sembast snapshot.
  SdbRawRecordSembast<K> _rawRecord(
    sembast.RecordSnapshot<K, Object> snapshot,
  ) => SdbRawRecordSembast<K>(
    key: snapshot.key,
    rawValue: fromSembastValue(snapshot.value),
  );

  SdbRecordSnapshot<K, V> _snapshot(SdbRawRecordSembast<K> record) =>
      SdbRecordSnapshotImpl<K, V>(
        store.record(record.key),
        _codec.decode<V>(record.rawValue),
      );

  SdbRecordKey<K, V> _recordKey(K key) =>
      SdbRecordKeyImpl<K, V>(store.record(key));

  /// Primary key boundaries as a sembast filter.
  sembast.Filter? _boundariesFilter(SdbBoundaries<K>? boundaries) {
    if (boundaries == null) {
      return null;
    }
    var filters = <sembast.Filter>[];
    var lower = boundaries.lower;
    if (lower != null) {
      filters.add(
        lower.include
            ? sembast.Filter.greaterThanOrEquals(sembast.Field.key, lower.value)
            : sembast.Filter.greaterThan(sembast.Field.key, lower.value),
      );
    }
    var upper = boundaries.upper;
    if (upper != null) {
      filters.add(
        upper.include
            ? sembast.Filter.lessThanOrEquals(sembast.Field.key, upper.value)
            : sembast.Filter.lessThan(sembast.Field.key, upper.value),
      );
    }
    if (filters.isEmpty) {
      return null;
    } else if (filters.length == 1) {
      return filters.first;
    }
    return sembast.Filter.and(filters);
  }

  /// Boundaries and sort order, offset and limit only when [offsetLimit] is
  /// true (no dart filter to apply first).
  sembast.Finder _finder(
    SdbFindOptions<K> options, {
    required bool offsetLimit,
  }) => sembast.Finder(
    filter: _boundariesFilter(options.boundaries),
    sortOrders: [
      sembast.SortOrder(sembast.Field.key, !(options.descending ?? false)),
    ],
    offset: offsetLimit ? _positiveOrNull(options.offset) : null,
    limit: offsetLimit ? _positiveOrNull(options.limit) : null,
  );

  /// All the raw records of the store, in key order.
  Future<List<SdbRawRecordSembast<K>>> findAllRaw() async =>
      (await sembastStore.find(sembastClient)).map(_rawRecord).toList();

  /// The raw records matching [options], filter included.
  Future<List<SdbRawRecordSembast<K>>> _findRaw(
    SdbFindOptions<K> options,
  ) async {
    var filter = options.filter;
    if (filter == null) {
      return (await sembastStore.find(
        sembastClient,
        finder: _finder(options, offsetLimit: true),
      )).map(_rawRecord).toList();
    }
    var records = (await sembastStore.find(
      sembastClient,
      finder: _finder(options, offsetLimit: false),
    )).map(_rawRecord);
    var matching = records.where(
      (record) => sdbRecordMatchesFilter(
        filter,
        primaryKey: record.key,
        value: _codec.decode<Object>(record.rawValue),
      ),
    );
    return sdbSembastOffsetLimit(
      matching,
      offset: options.offset,
      limit: options.limit,
    ).toList();
  }

  /// Unique indexes: no other record may share the index key of [encoded].
  Future<void> _checkUnique(K? key, Object encoded) async {
    var meta = this.meta;
    if (meta == null) {
      return;
    }
    List<SdbRawRecordSembast<K>>? records;
    for (var index in meta.indexes.values.where((index) => index.unique)) {
      var indexKey = sdbSembastRawIndexKey(encoded, index.keyPath);
      if (indexKey == null) {
        continue;
      }
      records ??= await findAllRaw();
      for (var record in records) {
        if (record.key == key) {
          continue;
        }
        var otherIndexKey = sdbSembastRawIndexKey(
          record.rawValue,
          index.keyPath,
        );
        if (otherIndexKey != null &&
            compareKeys(otherIndexKey, indexKey) == 0) {
          throw StateError(
            'Unique index ${index.name} of store ${store.name}: '
            'key $indexKey already used by record ${record.key}',
          );
        }
      }
    }
  }

  /// True when a change listener wants the changes of this store.
  bool get _hasChangeListener =>
      transaction.changesListener?.storeHasChangeListener(store) ?? false;

  /// Checked write of [value] (decoded) and [encoded], the change recorded
  /// for the listeners. [sembastValue] is the sembast form of [encoded] when
  /// already computed.
  Future<void> _write(
    K key,
    V value,
    Object encoded, {
    bool checkUnique = true,
    Object? sembastValue,
  }) async {
    sembastValue ??= toSembastValue(encoded);
    var hasChangeListener = _hasChangeListener;
    SdbRecordSnapshot<K, V>? oldSnapshot;
    if (hasChangeListener) {
      oldSnapshot = await getRecordImpl(key);
    }
    if (checkUnique) {
      await _checkUnique(key, encoded);
    }
    await sembastStore.record(key).put(sembastClient, sembastValue);
    transaction.noteWriteToStore(store.name);
    if (hasChangeListener) {
      transaction.changesListener?.addChange(
        transaction,
        oldSnapshot,
        SdbRecordSnapshotImpl<K, V>(store.record(key), value),
      );
    }
  }

  @override
  Future<SdbRecordSnapshot<K, V>?> getRecordImpl(K key) async {
    var snapshot = await sembastStore.record(key).getSnapshot(sembastClient);
    if (snapshot == null) {
      return null;
    }
    return _snapshot(_rawRecord(snapshot));
  }

  @override
  Future<bool> existsImpl(K key) =>
      sembastStore.record(key).exists(sembastClient);

  @override
  Future<K> addImpl(V value) async {
    _checkWrite();
    var meta = this.meta;
    var keyPath = meta?.keyPath;
    if (keyPath == null) {
      var encoded = _codec.encode(value);
      // Checked and converted before generating the key: a failed add must
      // not consume it.
      var sembastValue = toSembastValue(encoded);
      await _checkUnique(null, encoded);
      var key = await sembastStore.generateKey(sembastClient);
      await _write(
        key,
        value,
        encoded,
        checkUnique: false,
        sembastValue: sembastValue,
      );
      return key;
    }
    // Inline key.
    if (value is! Map) {
      throw ArgumentError.value(
        value,
        'value',
        'Store ${store.name} with key path $keyPath requires a Map value',
      );
    }
    var idbKeyPath = sdbKeyPathToIdbKeyPath(keyPath);
    var key = value.getKeyValue(idbKeyPath);
    if (key == null) {
      if (!meta!.autoIncrement) {
        throw ArgumentError.value(
          value,
          'value',
          'Missing key at $keyPath in store ${store.name}',
        );
      }
      // Checked before generating the key: a failed add must not consume it.
      var encoded = _codec.encode(value);
      toSembastValue(encoded);
      await _checkUnique(null, encoded);
      key = await sembastStore.generateKey(sembastClient);
      var valueWithKey = Map<String, Object?>.from(value)
        ..setKeyValue(idbKeyPath, key);
      await _write(
        key as K,
        valueWithKey as V,
        _codec.encode(valueWithKey),
        checkUnique: false,
      );
      return key;
    }
    if (await sembastStore.record(key as K).exists(sembastClient)) {
      throw StateError('Record $key already exists in store ${store.name}');
    }
    await _write(key, value, _codec.encode(value));
    return key;
  }

  @override
  Future<void> putImpl(K? key, V value) async {
    _checkWrite();
    if (key == null) {
      // Inline key.
      var keyPath = meta?.keyPath;
      if (keyPath == null || value is! Map) {
        throw ArgumentError.value(
          value,
          'value',
          'Store ${store.name} has no key path, a key is required',
        );
      }
      key = value.getKeyValue(sdbKeyPathToIdbKeyPath(keyPath)) as K?;
      if (key == null) {
        throw ArgumentError.value(
          value,
          'value',
          'Missing key at $keyPath in store ${store.name}',
        );
      }
    }
    await _write(key, value, _codec.encode(value));
  }

  /// Write the raw (encoded) [rawValue] at [key], for cursor row updates and
  /// imports: like idb, the change listeners are not told about it.
  @override
  Future<void> putRawImpl(K key, Object rawValue) async {
    _checkWrite();
    var sembastValue = toSembastValue(rawValue);
    await _checkUnique(key, rawValue);
    await sembastStore.record(key).put(sembastClient, sembastValue);
    transaction.noteWriteToStore(store.name);
  }

  /// Cursor row update, raw like idb.
  Future<void> updateImpl(K key, Object data) => putRawImpl(key, data);

  @override
  Future<void> deleteImpl(K key) async {
    _checkWrite();
    var hasChangeListener = _hasChangeListener;
    SdbRecordSnapshot<K, V>? oldSnapshot;
    if (hasChangeListener) {
      oldSnapshot = await getRecordImpl(key);
    }
    await sembastStore.record(key).delete(sembastClient);
    transaction.noteWriteToStore(store.name);
    if (hasChangeListener) {
      transaction.changesListener?.addChange(transaction, oldSnapshot, null);
    }
  }

  @override
  Future<List<SdbRecordSnapshot<K, V>>> findRecordsImpl({
    required SdbFindOptions<K> options,
  }) async {
    var records = await _findRaw(options);
    return records.map(_snapshot).toList();
  }

  @override
  Stream<SdbRecordSnapshot<K, V>> streamRecordsImpl({
    required SdbFindOptions<K> options,
  }) => Stream.fromFuture(
    findRecordsImpl(options: options),
  ).expand((records) => records);

  @override
  Future<void> iterateImpl({
    required SdbFindOptions<K> options,
    required SdbCursorRowHandler<K, V> handler,
  }) async {
    var records = await _findRaw(options);
    // Like an idb cursor, the transaction waits for the row updates the
    // handler did not await.
    var pendingUpdates = <Future<void>>[];
    try {
      for (var record in records) {
        var key = record.key;
        var row = SdbCursorRowImpl<K, V>.paged(
          key: key,
          rawValue: record.rawValue,
          onUpdate: (data) {
            var future = updateImpl(key, data);
            pendingUpdates.add(future);
            return future;
          },
        );
        var result = handler(row);
        var doContinue = result is Future<bool> ? await result : result;
        if (!doContinue) {
          return;
        }
      }
    } finally {
      await Future.wait(pendingUpdates);
    }
  }

  @override
  Future<List<SdbRecordKey<K, V>>> findRecordKeysImpl({
    required SdbFindOptions<K> options,
  }) async {
    if (options.filter != null) {
      // Filtered in dart on the values, a snapshot is a record key.
      return findRecordsImpl(options: options);
    }
    var keys = await sembastStore.findKeys(
      sembastClient,
      finder: _finder(options, offsetLimit: true),
    );
    return keys.map(_recordKey).toList();
  }

  @override
  Future<int> countImpl({required SdbFindOptions<K> options}) async {
    if (options.filter != null) {
      return (await _findRaw(options)).length;
    }
    var count = await sembastStore.count(
      sembastClient,
      filter: _boundariesFilter(options.boundaries),
    );
    var offset = _positiveOrNull(options.offset);
    var limit = _positiveOrNull(options.limit);
    if (offset != null) {
      count = max(0, count - offset);
    }
    if (limit != null) {
      count = min(count, limit);
    }
    return count;
  }

  @override
  Future<void> deleteRecordsImpl({required SdbFindOptions<K> options}) async {
    _checkWrite();
    List<K> keys;
    if (options.filter != null) {
      keys = (await _findRaw(options)).map((record) => record.key).toList();
    } else {
      keys = await sembastStore.findKeys(
        sembastClient,
        finder: _finder(options, offsetLimit: true),
      );
    }
    if (keys.isEmpty) {
      return;
    }
    if (_hasChangeListener) {
      // Record by record so that the listeners get each change.
      for (var key in keys) {
        await deleteImpl(key);
      }
      return;
    }
    await sembastStore.records(keys).delete(sembastClient);
    transaction.noteWriteToStore(store.name);
  }

  @override
  SdbKeyPath? get keyPath => meta?.keyPath;

  @override
  bool get autoIncrement => meta?.autoIncrement ?? (K == int);

  @override
  Iterable<String> get indexNames => meta?.indexes.keys ?? const <String>[];

  @override
  SdbTransactionIndexRef<K, V, I> index<I extends SdbIndexKey>(
    SdbIndexRef<K, V, I> ref,
  ) {
    var meta = this.meta;
    if (meta != null && !meta.indexes.containsKey(ref.name)) {
      throw StateError('Index ${ref.name} not found in store ${store.name}');
    }
    return SdbTransactionIndexRefSembast<K, V, I>(store: this, ref: ref);
  }

  @override
  String toString() => 'SdbTransactionStoreRefSembast(${store.name})';
}
