library tekartik_idb_provider.test.io_test_common;

import 'package:idb_shim/idb_client_sembast.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast_io.dart';

import 'test_common.dart';

export 'test_common.dart';

class IoTestContext extends SembastTestContext {
  IoTestContext() {
    sdbFactory = databaseFactoryIo;
    factory = IdbFactorySembast(databaseFactoryIo, testOutTopPath);
  }
}

IoTestContext idbIoContext = IoTestContext();

String get testScriptPath => 'test';

String get testOutTopPath =>
    join('.dart_tool', 'tekartik_idb_provider', 'test');
