@TestOn('vm')
library;

import 'package:idb_test/sdb_test.dart';
import 'package:idb_test/test_runner.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast_io.dart';
import 'package:tekartik_sdb_sembast/sdb_sembast.dart';
import 'package:test/scaffolding.dart';

void main() {
  sdbDefineAllTests(
    SdbTestContext(
      sdbFactorySembastFrom(
        databaseFactoryIo.sandbox(path: join('.local', 'sdb_sembast_io_test')),
      ),
    ),
  );
}
