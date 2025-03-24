import 'package:idb_shim/idb_io.dart';
import 'package:idb_sqflite/idb_client_sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sqflite;
import 'package:tekartik_app_dev_menu/dev_menu.dart';
import 'package:tekartik_idb_playground/idb_playground_menu.dart';

Future<void> main(List<String> args) async {
  sqflite.sqfliteFfiInit();
  sqflite.databaseFactory = sqflite.databaseFactoryFfi;
  // idbFactorySembastIo
  await mainMenu(args, () {
    menu('idb_io', () {
      idbPlaygroundMenu(
        idbFactorySembastIo,
        path: join('.local', 'playground'),
      );
    });
    menu('idb_sqflite', () {
      idbPlaygroundMenu(idbFactorySqflite);
    });
  });
}
