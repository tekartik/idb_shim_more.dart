import 'package:idb_shim/idb_browser.dart';
import 'package:tekartik_app_dev_menu/dev_menu.dart';
import 'package:tekartik_idb_playground/idb_playground_menu.dart';

void main(List<String> arguments) {
  mainMenu(arguments, () {
    idbPlaygroundMenu(idbFactoryWeb);
  });
}
