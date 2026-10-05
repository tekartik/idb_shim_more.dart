// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math';

import 'package:tekartik_sdb_sembast/src/sembast/sdb_import.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_meta.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_transaction_store.dart';

/// A record of the store seen through an index: the raw (encoded) index key,
/// the primary key and the raw value.
class SdbIndexRowSembast<K extends SdbKey> {
  final K primaryKey;
  final Object indexKey;
  final Object rawValue;

  SdbIndexRowSembast({
    required this.primaryKey,
    required this.indexKey,
    required this.rawValue,
  });
}

/// True for a raw value usable as an index key, like idb: num, String or a
/// list of them (composite key).
bool sdbSembastIsValidRawIndexKey(Object? raw) {
  if (raw is num || raw is String) {
    return true;
  }
  if (raw is List) {
    return raw.isNotEmpty && raw.every(sdbSembastIsValidRawIndexKey);
  }
  return false;
}

/// The raw index key of an encoded value, null if the record is not in the
/// index (no value at the key path or not a valid key).
Object? sdbSembastRawIndexKey(Object encodedValue, SdbKeyPath keyPath) {
  if (encodedValue is! Map) {
    return null;
  }
  var raw = encodedValue.getKeyValue(sdbKeyPathToIdbKeyPath(keyPath));
  return sdbSembastIsValidRawIndexKey(raw) ? raw : null;
}

/// Sembast based transaction index, emulated: sembast has no secondary index,
/// the store is read and the index key of each record is computed from the
/// index key path on the encoded value, then ordered like idb (index key then
/// primary key).
class SdbTransactionIndexRefSembast<
  K extends SdbKey,
  V extends SdbValue,
  I extends SdbIndexKey
>
    implements
        SdbTransactionIndexRefInterface<K, V, I>,
        SdbOpenIndexRef<K, V, I> {
  @override
  final SdbTransactionStoreRefSembast<K, V> store;
  @override
  final SdbIndexRef<K, V, I> ref;

  SdbTransactionIndexRefSembast({required this.store, required this.ref});

  /// The index definition.
  SdbIndexMetaSembast get meta =>
      store.meta?.indexes[ref.name] ??
      (throw StateError(
        'Index ${ref.name} not found in store ${store.store.name}',
      ));

  @override
  String get name => ref.name;

  @override
  SdbTransaction get transaction => store.transaction;

  @override
  SdbKeyPath get keyPath => meta.keyPath;

  @override
  bool get unique => meta.unique;

  @override
  bool get multiEntry => false;

  SdbCodec get _codec => store.transaction.codec;

  /// The rows of the index within [boundaries] (index keys), ordered.
  Future<List<SdbIndexRowSembast<K>>> rows({
    SdbBoundaries? boundaries,
    bool descending = false,
  }) async {
    var keyPath = meta.keyPath;
    var records = await store.findAllRaw();
    var rows = <SdbIndexRowSembast<K>>[];
    for (var record in records) {
      var indexKey = sdbSembastRawIndexKey(record.rawValue, keyPath);
      if (indexKey == null) {
        continue;
      }
      rows.add(
        SdbIndexRowSembast<K>(
          primaryKey: record.key,
          indexKey: indexKey,
          rawValue: record.rawValue,
        ),
      );
    }
    var lower = boundaries?.lower;
    if (lower != null) {
      var rawLower = sdbIndexKeyToIdbKey(_codec, lower.value);
      rows.retainWhere((row) {
        var cmp = compareKeys(row.indexKey, rawLower);
        return lower.include ? cmp >= 0 : cmp > 0;
      });
    }
    var upper = boundaries?.upper;
    if (upper != null) {
      var rawUpper = sdbIndexKeyToIdbKey(_codec, upper.value);
      rows.retainWhere((row) {
        var cmp = compareKeys(row.indexKey, rawUpper);
        return upper.include ? cmp <= 0 : cmp < 0;
      });
    }
    rows.sort((row1, row2) {
      var cmp = compareKeys(row1.indexKey, row2.indexKey);
      if (cmp == 0) {
        cmp = compareKeys(row1.primaryKey, row2.primaryKey);
      }
      return descending ? -cmp : cmp;
    });
    return rows;
  }

  /// The rows matching [options], filter (in dart on the decoded value),
  /// offset and limit applied.
  Future<List<SdbIndexRowSembast<K>>> find(SdbFindOptions options) async {
    var found = await rows(
      boundaries: options.boundaries,
      descending: options.descending ?? false,
    );
    var filter = options.filter;
    Iterable<SdbIndexRowSembast<K>> matching = found;
    if (filter != null) {
      matching = matching.where(
        (row) => sdbRecordMatchesFilter(
          filter,
          primaryKey: row.primaryKey,
          indexKey: row.indexKey,
          value: _codec.decode<Object>(row.rawValue),
        ),
      );
    }
    return sdbSembastOffsetLimit(
      matching,
      offset: options.offset,
      limit: options.limit,
    ).toList();
  }

  I _indexKey(SdbIndexRowSembast<K> row) =>
      ref.impl.indexIdbToSdbKeyValue(_codec, row.indexKey);

  SdbIndexRecordSnapshot<K, V, I> _snapshot(SdbIndexRowSembast<K> row) =>
      SdbIndexRecordSnapshotImpl<K, V, I>(
        ref,
        row.primaryKey,
        _codec.decode<V>(row.rawValue),
        _indexKey(row),
      );

  SdbIndexRecordKey<K, V, I> _recordKey(SdbIndexRowSembast<K> row) =>
      SdbIndexRecordKeyImpl<K, V, I>(ref, row.primaryKey, _indexKey(row));

  Future<SdbIndexRowSembast<K>?> _firstRow(I indexKey) async {
    var found = await rows(boundaries: SdbBoundaries<I>.key(indexKey));
    return found.firstOrNull;
  }

  @override
  Future<SdbIndexRecordSnapshot<K, V, I>?> getRecordImpl(I indexKey) async {
    var row = await _firstRow(indexKey);
    return row == null ? null : _snapshot(row);
  }

  @override
  Future<K?> getKeyImpl(I indexKey) async =>
      (await _firstRow(indexKey))?.primaryKey;

  @override
  Future<List<K>> getKeysImpl(I indexKey) async => (await rows(
    boundaries: SdbBoundaries<I>.key(indexKey),
  )).map((row) => row.primaryKey).toList();

  @override
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> getRecordsImpl(
    I indexKey,
  ) async => (await rows(
    boundaries: SdbBoundaries<I>.key(indexKey),
  )).map(_snapshot).toList();

  @override
  Future<List<SdbIndexRecordSnapshot<K, V, I>>> findRecordsImpl({
    required SdbFindOptions<I> options,
  }) async => (await find(options)).map(_snapshot).toList();

  @override
  Stream<SdbIndexRecordSnapshot<K, V, I>> streamRecordsImpl({
    required SdbFindOptions<I> options,
  }) => Stream.fromFuture(
    findRecordsImpl(options: options),
  ).expand((records) => records);

  @override
  Future<List<SdbIndexRecordKey<K, V, I>>> findRecordKeysImpl({
    required SdbFindOptions<I> options,
  }) async {
    if (options.filter != null) {
      // Filtered on the values, a snapshot is a record key.
      return findRecordsImpl(options: options);
    }
    return (await find(options)).map(_recordKey).toList();
  }

  @override
  Future<int> countImpl({required SdbFindOptions<I> options}) async {
    if (options.filter != null) {
      return (await find(options)).length;
    }
    var count = (await rows(boundaries: options.boundaries)).length;
    var offset = options.offset;
    var limit = options.limit;
    if (offset != null && offset > 0) {
      count = max(0, count - offset);
    }
    if (limit != null && limit > 0) {
      count = min(count, limit);
    }
    return count;
  }

  @override
  Future<void> deleteRecordsImpl({required SdbFindOptions<I> options}) async {
    var found = await find(options);
    for (var row in found) {
      await store.deleteImpl(row.primaryKey);
    }
  }

  @override
  Future<void> iterateImpl({
    required SdbFindOptions<SdbKey> options,
    required SdbIndexCursorRowHandler<K, V, I> handler,
  }) async {
    var found = await find(options);
    // Like an idb cursor, the transaction waits for the row updates the
    // handler did not await.
    var pendingUpdates = <Future<void>>[];
    try {
      for (var row in found) {
        var primaryKey = row.primaryKey;
        var cursorRow = SdbIndexCursorRowImpl<K, V, I>.paged(
          key: row.indexKey,
          primaryKey: primaryKey,
          rawValue: row.rawValue,
          onUpdate: (data) {
            var future = store.updateImpl(primaryKey, data);
            pendingUpdates.add(future);
            return future;
          },
        );
        var result = handler(cursorRow);
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
  String toString() =>
      'SdbTransactionIndexRefSembast(${store.store.name}, $name)';
}
