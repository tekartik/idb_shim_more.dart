@TestOn('browser && !wasm')
library;

import 'package:idb_shim_html_compat/idb_client_native_html.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/object_store_test.dart' as object_store;

void main() {
  group('native_html', () {
    var idbFactory = idbFactoryNativeHtml;
    if (idbFactoryNativeSupported) {
      test('properties', () {
        expect(idbFactory.persistent, isTrue);
      });

      final ctx = TestContext()..factory = idbFactory;
      object_store.defineTests(ctx);
    } else {
      test(
        'idb native html supported',
        () {},
        skip: 'idb native html not supported',
      );
    }
  });
}
