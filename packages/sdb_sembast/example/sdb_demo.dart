// A small sdb demo, on the VM (sembast in memory) or in a browser
// (sembast_web, IndexedDB):
//
//     dart run example/sdb_demo.dart
//     dart run tekartik_common_build:web_run example/sdb_demo.dart
//     dart run tekartik_common_build:web_run --wasm example/sdb_demo.dart
// ignore_for_file: avoid_print
import 'package:idb_shim/sdb.dart';

import 'src/demo_factory.dart';

/// A store of notes with an int key generated on add.
final notesStore = SdbStoreRef<int, SdbModel>('notes');

Future<void> main() async {
  const name = 'sdb_demo.db';
  print('factory: $demoSdbFactoryName');
  // A fresh database each run.
  await demoSdbFactory.deleteDatabase(name);
  var db = await demoSdbFactory.openDatabase(
    name,
    options: SdbOpenDatabaseOptions(
      version: 1,
      schema: SdbDatabaseSchema(
        stores: [notesStore.schema(autoIncrement: true)],
      ),
    ),
  );
  var key = await notesStore.add(db, {'title': 'Hello'});
  await notesStore.add(db, {'title': 'World'});
  print('note $key: ${(await notesStore.record(key).get(db))!.value}');
  print('${(await notesStore.findRecords(db)).length} notes');
  await db.close();
  await demoSdbFactory.deleteDatabase(name);
}
