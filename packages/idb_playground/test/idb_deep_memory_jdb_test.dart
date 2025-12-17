import 'package:idb_shim/idb_client_sembast.dart';
import 'package:idb_test/idb_test_common.dart' as idb;
import 'package:idb_test/test_runner.dart';
import 'package:sembast/utils/jdb.dart';
import 'package:sembast_test/jdb_test_common.dart';

void main() {
  var sembast1Factory = databaseFactoryMemoryJdb;
  var idb1Factory = IdbFactorySembast(sembast1Factory);
  var sembast2Factory = DatabaseFactoryJdb(JdbFactoryIdb(idb1Factory));

  var testContext = idb.SembastTestContext(
    sembastDatabaseFactory: sembast2Factory,
    // inMemory: true,
  );
  defineAllTests(testContext);
}
