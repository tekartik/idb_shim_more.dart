import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:tekartik_idb_playground/sdb_playground_menu.dart';

Future<void> main() async {
  var factory = sdbFactoryMemory;

  var dbName = '.local/sqflite_stress/notes.db';
  Future<void> createNAndList(int count) async {
    await factory.deleteDatabase(dbName);
    var notesDb = await PlaygoundNotesDb.open(factory, dbName);
    await notesDb.generateNotes(count);
    await notesDb.dumpNotes();
    await notesDb.close();
  }

  for (var count in [
    10,
    100,
    500,
    800,
    1000,
    5000,
    10000,
    20000,
    50000,
    100000,
  ]) {
    test('create and list $count', () async {
      await createNAndList(count);
    });
  }
}
