import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sdb_sqflite_stress_test_manual.dart';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  var factory = sdbFactorySqflite;

  var dbName = inMemoryDatabasePath;

  for (var count in [10, 100, 500, 800, 1000, 5000]) {
    test('create and list $count', () async {
      await sdbCreateNAndList(factory, dbName, count: count);
    }, timeout: Timeout(Duration(minutes: 5)));
  }
  var count = 10;
  test('create and list $count', () async {
    await sdbCreateNAndList(factory, dbName, count: count);
  }, timeout: Timeout(Duration(minutes: 5)));
}
