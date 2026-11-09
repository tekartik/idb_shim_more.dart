library;

import 'package:idb_test/sdb_iterate_test.dart';
import 'package:idb_test/sdb_review_regression_test.dart';
import 'package:idb_test/sdb_test.dart';
import 'package:idb_test/test_runner.dart';
import 'package:tekartik_sdb_sembast/sdb_sembast.dart';

void main() {
  var ctx = SdbTestContext(sdbFactorySembastNewInMemory());
  sdbDefineAllTests(ctx);
  sdbIterateTests(ctx);
  // Nested filters, join limit 0, errors (fixed in idb_shim 2.11.3).
  sdbReviewRegressionTests(ctx);
}
