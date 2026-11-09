// ignore_for_file: deprecated_member_use

@TestOn('browser && !wasm')
library;

import 'dart:async';

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim_html_compat/idb_client_native_html.dart';
import 'package:test/test.dart';

void main() {
  group('native_html', () {
    final factory = idbFactoryNativeHtml;
    final upgrades = <String, FutureOr<void> Function(VersionChangeEvent e)>{
      'sync': (e) {
        e.database.createObjectStore('s');
        throw StateError('upgrade failed');
      },
      'async': (e) async {
        e.database.createObjectStore('s');
        throw StateError('upgrade failed');
      },
      'after write': (e) async {
        var store = e.database.createObjectStore('s');
        await store.put('v', 1);
        throw StateError('upgrade failed');
      },
    };
    upgrades.forEach((kind, onUpgradeNeeded) {
      // As idb_shim: a failed upgrade is aborted, not committed at the new
      // version (the error used to be caught and the upgrade kept).
      test('failed upgrade is not committed ($kind)', () async {
        var dbName = 'native_html_upgrade_error_${kind.hashCode}.db';
        await factory.deleteDatabase(dbName);
        try {
          await factory.open(
            dbName,
            version: 1,
            onUpgradeNeeded: onUpgradeNeeded,
          );
          fail('should fail');
        } on StateError catch (e) {
          expect(e.message, 'upgrade failed');
        }
        var upgradeCalled = false;
        var db = await factory.open(
          dbName,
          version: 1,
          onUpgradeNeeded: (e) {
            upgradeCalled = true;
            expect(e.oldVersion, 0);
            e.database.createObjectStore('s');
          },
        );
        try {
          expect(upgradeCalled, isTrue);
          var txn = db.transaction('s', idbModeReadOnly);
          expect(await txn.objectStore('s').count(), 0);
          await txn.completed;
        } finally {
          db.close();
        }
      });
    });
  });
}
