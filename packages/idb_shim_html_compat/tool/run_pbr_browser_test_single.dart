import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''

  # pub run build_runner test -- -p chrome -j 1 test/multiplatform/idb_shim_import_test.dart
  # dart run build_runner test -- -p chrome -j 1 test/web/idb_native_factory_test.dart -r json
  dart run build_runner test -- -p chrome -j 1 test/web/idb_native_factory_test.dart 
  # pub run build_runner test -- -p chrome -j 1 test/multiplatform/idb_api_test.dart -r json
  

''');
}
