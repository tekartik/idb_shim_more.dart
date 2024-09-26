library tekartik_idb_provider.test.test_common;

import 'package:idb_shim/idb_client_sembast.dart';
import 'package:sembast/sembast.dart' as sdb;

export 'dart:async';

export 'package:idb_shim/idb_client_memory.dart';
export 'package:idb_shim/src/common/common_meta.dart';
export 'package:test/test.dart';

class TestContext {
  static var _id = 0;
  late IdbFactory factory;

  String get dbName => 'test-${++_id}.db';
}

class SembastTestContext extends TestContext {
  late sdb.DatabaseFactory sdbFactory;

  @override
  IdbFactorySembast get factory => super.factory as IdbFactorySembast;
}

TestContext idbMemoryContext = SembastTestContext()..factory = idbFactoryMemory;
