// ignore_for_file: implementation_imports
import 'dart:typed_data';

import 'package:idb_shim/idb_client_memory.dart';
import 'package:idb_shim/sdb.dart';
import 'package:tekartik_sdb_sembast/sdb_sembast.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_transaction_index.dart';
import 'package:test/test.dart';

var _store = SdbStoreRef<int, SdbModel>('compat');
var _nameIndex = _store.index<String>('name');
var _uniqueIndex = _store.index<int>('u');
var _autoStore = SdbStoreRef<int, SdbModel>('compat_auto');
var _stringStore = SdbStoreRef<String, SdbModel>('compat_string');

/// Same behavior on the idb based sdb and on sdb_sembast.
void main() {
  defineCompatTests('idb', sdbFactoryFromIdb(newIdbFactoryMemory()));
  defineCompatTests('sembast', sdbFactorySembastNewInMemory(), sembast: true);

  test('sdbSembastIsValidRawIndexKey', () {
    for (var key in <Object>[
      1,
      1.5,
      'a',
      <Object?>[],
      [1, 'a'],
      Uint8List.fromList([1, 2]),
    ]) {
      expect(sdbSembastIsValidRawIndexKey(key), isTrue, reason: '$key');
    }
    for (var key in <Object?>[
      null,
      double.nan,
      [1, double.nan],
      [1, null],
      true,
      <String, Object?>{},
      DateTime(2020),
    ]) {
      expect(sdbSembastIsValidRawIndexKey(key), isFalse, reason: '$key');
    }
  });
}

void defineCompatTests(
  String name,
  SdbFactory factory, {
  bool sembast = false,
}) {
  group(name, () {
    late SdbDatabase db;
    var dbName = 'sdb_sembast_idb_compat.db';

    setUp(() async {
      await factory.deleteDatabase(dbName);
      db = await factory.openDatabase(
        dbName,
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [
              _store.schema(
                indexes: [
                  _nameIndex.schema(keyPath: 'name'),
                  _uniqueIndex.schema(keyPath: 'u', unique: true),
                ],
              ),
              _autoStore.schema(autoIncrement: true),
              _stringStore.schema(),
            ],
          ),
        ),
      );
      // a a b b c c
      for (var i = 0; i < 6; i++) {
        await _store.record(i).put(db, {
          'name': ['a', 'b', 'c'][i ~/ 2],
        });
      }
    });
    tearDown(() async {
      await db.close();
    });

    test('limit 0 deletes nothing', () async {
      await _store.delete(db, options: SdbFindOptions<int>(limit: 0));
      await _nameIndex.delete(db, options: SdbFindOptions<String>(limit: 0));
      await _nameIndex
          .record('a')
          .delete(db, options: SdbFindOptions<String>(limit: 0));
      expect(await _store.count(db), 6);
      // A limit still applies
      await _nameIndex
          .record('a')
          .delete(db, options: SdbFindOptions(limit: 1));
      expect(await _store.count(db), 5);
    });

    test('NaN index values are not indexed', () async {
      await _store.record(10).put(db, {'u': double.nan});
      await _store.record(11).put(db, {'u': double.nan});
      await _store.record(12).put(db, {'u': 1});
      expect((await _uniqueIndex.findRecords(db)).map((record) => record.key), [
        12,
      ]);
      expect(await _uniqueIndex.count(db), 1);
    });

    test('add without key path and auto increment', () async {
      await expectLater(
        () => _store.add(db, {'name': 'new'}),
        throwsA(isA<DatabaseException>()),
      );
      expect(await _store.count(db), 6);
      // Generated keys
      expect(await _autoStore.add(db, {'name': 'new'}), 1);
      expect(await _stringStore.add(db, {'name': 'new'}), isNotEmpty);
    });

    test('unique index violation', () async {
      await _store.record(10).put(db, {'u': 1});
      await expectLater(
        () => _store.record(11).put(db, {'u': 1}),
        throwsA(isA<DatabaseException>()),
      );
      expect(await _store.record(11).exists(db), isFalse);
    });

    test('write in a read only transaction', () async {
      Future<void> readOnly(
        Future<void> Function(SdbSingleStoreTransaction<int, SdbModel> txn)
        action,
      ) => db.inStoreTransaction(_store, SdbTransactionMode.readOnly, action);
      await expectLater(
        () => readOnly((txn) => txn.put(10, {'name': 'new'})),
        throwsA(isA<DatabaseReadOnlyError>()),
      );
      await expectLater(
        () => readOnly((txn) => txn.add({'name': 'new'})),
        throwsA(isA<DatabaseReadOnlyError>()),
      );
      await expectLater(
        () => readOnly((txn) => txn.delete(0)),
        throwsA(isA<DatabaseReadOnlyError>()),
      );
      expect(await _store.count(db), 6);
    });

    if (sembast) {
      // idb also reports the aborted transaction as an uncaught error.
      test('row update checks the unique indexes', () async {
        await _store.record(10).put(db, {'u': 1});
        await expectLater(
          () => _store.iterate(
            db,
            mode: SdbTransactionMode.readWrite,
            options: SdbFindOptions(limit: 1),
            onRow: (row) async {
              await row.update({'name': 'z', 'u': 1});
              return true;
            },
          ),
          throwsA(isA<DatabaseException>()),
        );
        expect((await _store.record(0).get(db))!.value, {'name': 'a'});
      });
    }
  });
}
