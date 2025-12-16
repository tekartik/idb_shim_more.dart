import 'package:idb_shim/idb_client_sembast.dart';
import 'package:idb_test/idb_test_common.dart' as idb;
import 'package:idb_test/test_runner.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_test/jdb_test_common.dart';
import 'package:sembast_test/sembast_jdb.dart';

String get testOutTopPath => join('.dart_tool', 'idb_shim', 'test');

void main() {
  var sembast1Factory = databaseFactoryIo;
  var idb1Factory = IdbFactorySembast(sembast1Factory, testOutTopPath);
  var sembast2Factory = DatabaseFactoryJdb(JdbFactoryIdb(idb1Factory));
  var testContext = idb.SembastTestContext(
    sembastDatabaseFactory: sembast2Factory,
  );
  defineAllTests(testContext);
}
