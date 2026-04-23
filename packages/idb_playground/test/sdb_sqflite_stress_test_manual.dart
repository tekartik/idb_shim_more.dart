import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tekartik_idb_playground/sdb_playground_menu.dart';

Future<void> sdbCreateNAndList(
  SdbFactory factory,
  String dbName, {
  int? count,
}) async {
  count ??= 10;
  if (dbName != inMemoryDatabasePath) {
    await factory.deleteDatabase(dbName);
  }
  var notesDb = await PlaygoundNotesDb.open(factory, dbName);
  await notesDb.generateNotes(count);
  await notesDb.dumpNotes();
  await notesDb.close();
}

void stressMenu(SdbFactory factory, String dbName) {
  for (var count in [10, 100, 500, 800, 1000, 5000]) {
    test('create and list $count', () async {
      await sdbCreateNAndList(factory, dbName, count: count);
    }, timeout: Timeout(Duration(minutes: 5)));
  }

  // Solo?
  var count = 10;
  test(
    'create and list $count',
    () async {
      await sdbCreateNAndList(factory, dbName, count: count);
    },
    solo: true,
    timeout: Timeout(Duration(minutes: count > 500 ? 5 : 1)),
  );
}

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  var factory = sdbFactorySqflite;

  var dbName = '.local/sqflite_stress/notes.db';

  stressMenu(factory, dbName);
}
