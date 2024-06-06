@TestOn('browser && !wasm')
library idb_browser_test;

import 'dart:html';

import 'package:idb_shim_html_compat/idb_client_native_html.dart';
import 'package:test/test.dart';

void main() {
  group('idb_native_factory', () {
    test('idbFactoryFromIndexedDB', () async {
      var factory1 = idbFactoryFromIndexedDB(window.indexedDB!);
      // ignore: deprecated_member_use_from_same_package
      var factory2 = idbFactoryNative;
      var dbName = 'idbFactoryFromIndexedDB.db';
      var version = 1234;
      await factory1.deleteDatabase('idbFactoryFromIndexedDB.db');
      var db = await factory1.open(dbName,
          version: version, onUpgradeNeeded: (_) {});
      expect(db.version, version);
      db.close();
      // Open without version, should match
      db = await factory2.open(dbName);
      expect(db.version, version);
      db.close();
    });
  });
}
