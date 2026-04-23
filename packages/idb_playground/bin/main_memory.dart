import 'package:idb_shim/idb_io.dart';
import 'package:path/path.dart';
import 'package:tekartik_app_dev_menu/dev_menu.dart';
import 'package:tekartik_idb_playground/idb_playground_menu.dart';

Future<void> main(List<String> args) async {
  await mainMenu(args, () {
    menu('idb_memory', () {
      idbPlaygroundMenu(idbFactoryMemory, path: join('.local', 'playground'));
    });
  });
}
