@TestOn('browser && !wasm')
library;

// ignore: deprecated_member_use
import 'package:idb_shim_html_compat/idb_client_native_html.dart';
import 'package:sembast_test/all_jdb_test.dart' as all_jdb_test;
import 'package:sembast_test/all_test.dart';
import 'package:sembast_test/jdb_test_common.dart';
import 'package:sembast_test/src/import_jdb.dart';
import 'package:sembast_test/test_common.dart';
// ignore: depend_on_referenced_packages
import 'package:sembast_web/src/jdb_factory_idb.dart';
import 'package:test/test.dart';

Future main() async {
  var jdbFactory = JdbFactoryIdb(idbFactoryNativeHtml);
  var factory = DatabaseFactoryJdb(jdbFactory);

  var testContext = DatabaseTestContextJdb()..factory = factory;

  group('idb_native', () {
    defineTests(testContext);
    all_jdb_test.defineJdbTests(testContext);
  });
}
