@TestOn('browser && !wasm')
library;

import 'package:idb_shim/idb.dart';
import 'package:idb_shim_html_compat/idb_client_native_html.dart';
import 'package:test/test.dart';

/// A shim KeyRange is converted to a native one (index get/getKey, store
/// delete).
void main() {
  group('native_key_range_query', () {
    late Database db;
    var dbName = 'native_key_range_query.db';

    setUp(() async {
      var factory = idbFactoryNativeHtml;
      await factory.deleteDatabase(dbName);
      db = await factory.open(
        dbName,
        version: 1,
        onUpgradeNeeded: (event) {
          var store = event.database.createObjectStore('s');
          store.createIndex('i', 'v');
        },
      );
      var txn = db.transaction('s', idbModeReadWrite);
      var store = txn.objectStore('s');
      await store.put({'v': 'a'}, 1);
      await store.put({'v': 'b'}, 2);
      await store.put({'v': 'c'}, 3);
      await txn.completed;
    });
    tearDown(() {
      db.close();
    });

    test('index get and getKey', () async {
      var txn = db.transaction('s', idbModeReadOnly);
      var index = txn.objectStore('s').index('i');
      expect(await index.get(KeyRange.lowerBound('b')), {'v': 'b'});
      expect(await index.getKey(KeyRange.lowerBound('b', true)), 3);
      await txn.completed;
    });

    test('store delete', () async {
      var txn = db.transaction('s', idbModeReadWrite);
      var store = txn.objectStore('s');
      await store.delete(KeyRange.lowerBound(2));
      expect(await store.count(), 1);
      await txn.completed;
    });
  });
}
