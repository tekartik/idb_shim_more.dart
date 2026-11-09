@TestOn('browser && !wasm')
library;

import 'package:idb_shim_html_compat/idb_client_native_html.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/object_store_test.dart' as object_store;
import 'package:idb_test/review_regression_level3_test.dart'
    as review_regression_level3;
import 'package:idb_test/review_regression_test.dart' as review_regression;

void main() {
  group('native_html', () {
    var idbFactory = idbFactoryNativeHtml;
    if (idbFactoryNativeSupported) {
      test('properties', () {
        expect(idbFactory.persistent, isTrue);
      });

      final ctx = TestContext()
        ..factory = idbFactory
        ..isIdbHtmlCompat = true;
      object_store.defineTests(ctx);
      // The regression suites of the 2026-11-09 reviews. The whole idb_test
      // suite (defineAllTests) is not registered: dart:html needs a version
      // and onUpgradeNeeded together and reads values as
      // Map<dynamic, dynamic> (no sdb), 142 tests fail (level 4 review).
      review_regression.defineTests(ctx);
      review_regression_level3.defineTests(ctx);
    } else {
      test(
        'idb native html supported',
        () {},
        skip: 'idb native html not supported',
      );
    }
  });
}
