// ignore_for_file: avoid_print

import 'package:idb_shim/sdb.dart';
import 'package:tekartik_sdb_sembast/sdb_sembast.dart';

/// A store of notes with an int key generated on add.
final notesStore = SdbStoreRef<int, SdbModel>('notes');

Future<void> main() async {
  // sdbFactorySembastFrom(databaseFactoryIo) to store in a file.
  var factory = sdbFactorySembastNewInMemory();
  var db = await factory.openDatabase(
    'notes.db',
    options: SdbOpenDatabaseOptions(
      version: 1,
      schema: SdbDatabaseSchema(
        stores: [notesStore.schema(autoIncrement: true)],
      ),
    ),
  );
  var key = await notesStore.add(db, {'title': 'Hello'});
  await notesStore.add(db, {'title': 'World'});
  print((await notesStore.record(key).get(db))!.value); // {title: Hello}
  print((await notesStore.findRecords(db)).length); // 2
  await db.close();
}
