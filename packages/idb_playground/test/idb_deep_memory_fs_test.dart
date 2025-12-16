import 'package:idb_shim/idb_client_sembast.dart';
import 'package:idb_test/idb_test_common.dart' as idb;
import 'package:idb_test/test_runner.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast_test/jdb_test_common.dart';
import 'package:sembast_test/sembast_jdb.dart';

void main() {
  var sembast1Factory = databaseFactoryMemoryFs;
  var idb1Factory = IdbFactorySembast(sembast1Factory);
  var sembast2Factory = DatabaseFactoryJdb(JdbFactoryIdb(idb1Factory));
  /*
  var idb1Factory = JdbI;
  var sembast1Factory = IdbFactorySembast(idb1Factory);
  var idb2Factory = idbFactoryMemory;
  */
  var testContext = idb.SembastTestContext(
    sembastDatabaseFactory: sembast2Factory,
  );
  defineAllTests(testContext);
}
