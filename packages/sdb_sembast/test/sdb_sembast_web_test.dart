@TestOn('browser')
library;

import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/sdb_iterate_test.dart';
import 'package:idb_test/sdb_review_regression_test.dart';
import 'package:idb_test/sdb_test.dart';
import 'package:idb_test/test_runner.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:tekartik_sdb_sembast/sdb_sembast.dart';

void main() {
  var ctx = SdbTestContext(sdbFactorySembastFrom(databaseFactoryWeb));
  sdbDefineAllTests(ctx);
  // Same suites as the memory runner.
  sdbIterateTests(ctx);
  sdbReviewRegressionTests(ctx);
}
