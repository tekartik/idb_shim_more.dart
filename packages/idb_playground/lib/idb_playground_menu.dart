import 'package:idb_shim/idb.dart';
import 'package:idb_shim/utils/idb_cursor_utils.dart';
import 'package:path/path.dart';
import 'package:tekartik_app_dev_menu/dev_menu.dart';

void idbPlaygroundMenu(IdbFactory idbFactory, {String? path}) {
  String fixDbName(String name) {
    if (path != null) {
      return join(path, name);
    }

    return name;
  }

  item('open downgrade', () async {
    var name = fixDbName('open_downgrade.db');
    await idbFactory.deleteDatabase(name);
    var db = await idbFactory.open(
      name,
      version: 2,
      onUpgradeNeeded: (VersionChangeEvent e) async {
        var db = e.database;
        db.createObjectStore('store');
      },
    );
    db.close();
    try {
      db = await idbFactory.open(
        name,
        version: 1,
        onUpgradeNeeded: (VersionChangeEvent e) {
          var db = e.database;
          db.createObjectStore('store');
        },
      );
      db.close();
    } catch (e) {
      write('error type: ${e.runtimeType}');
      write('error: $e');
    }
  });
  item('openOnDowngradeDelete downgrade', () async {
    var name = fixDbName('openOnDowngradeDelete_downgrade.db');
    await idbFactory.deleteDatabase(name);
    write('open version 2');
    var db = await idbFactory.open(
      name,
      version: 2,
      onUpgradeNeeded: (VersionChangeEvent e) async {
        var db = e.database;
        var store = db.createObjectStore('store');
        await store.put('value2', 'key2');
      },
    );
    Future<void> dumpRows() async {
      write('opened ${db.version}');
      var store = db.transaction('store', idbModeReadOnly).objectStore('store');

      var cursor = store.openCursor(direction: idbDirectionNext);
      var rows = await cursor.toRowList();
      for (var row in rows) {
        write('row: $row');
      }
    }

    await dumpRows();
    db.close();
    write('open version 1');
    try {
      db = await idbFactory.openOnDowngradeDelete(
        name,
        version: 1,
        onUpgradeNeeded: (VersionChangeEvent e) async {
          var db = e.database;
          var store = db.createObjectStore('store');
          await store.put('value1', 'key1');
        },
      );
      await dumpRows();
      db.close();
    } catch (e) {
      write('error type: ${e.runtimeType}');
      write('error: $e');
    }
  });
}
