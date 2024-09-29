library;

import 'package:tekartik_idb_provider/provider.dart';

import 'test_common.dart';
import 'test_provider.dart';

void main() {
  testMain(idbMemoryContext);
}

void testMain(TestContext context) {
  final idbFactory = context.factory;

  group('provider', () {
    group('row', () {
      final providerName = 'test';

      late DynamicProvider provider;
      ProviderTransaction? transaction;

      setUp(() {
        provider = DynamicProvider(idbFactory, ProviderDbMeta(providerName));
        return provider.delete();
      });
      tearDown(() async {
        await transaction?.completed;
        provider.close();
      });

      test('int_map', () {
        provider.addStore(ProviderStoreMeta('store', autoIncrement: true));
        return provider.ready!.then((Provider readyProvider) {
          final txn = provider.storeTransaction('store', true);
          // for cleanup
          transaction = txn;

          return txn.put({'test': 1}).then((key) {
            return txn.get(key).then((value) {
              final row =
                  intMapProviderRawFactory.newRow(key as int, value as Map);

              // Cursor
              txn.openCursor().listen((cwv) {
                final cursorRow =
                    intMapProviderRawFactory.cursorWithValueRow(cwv);
                expect(cursorRow, row);
              });
            });
          });
        });
      });
    });
  });
  group('test_provider_open', () {
    test('open', () async {
      // open normal
      final provider = TestProvider(idbFactory);
      final provider2 = TestProvider(idbFactory);
      await provider.delete().then((_) {
        expect(provider.isReady, isFalse);
        final done = provider.ready!.then((readyProvider) {
          expect(readyProvider, provider);
        });
        // not ready yet when opening the db
        expect(provider.isReady, isFalse);
        return done;
      }).then((_) {
        // open using an incoming db
        expect(provider2.isReady, isFalse);
        provider2.db = provider.db;
        expect(provider2.isReady, isTrue);
        final done = provider2.ready!.then((readyProvider2) {
          expect(readyProvider2, provider2);
        });
        return done;
      });

      provider.close();
    });
  });
  group('test_provider', () {
    final provider = TestProvider(idbFactory);
    setUp(() {
      return provider.delete().then((_) {
        return provider.ready!.then((_) {
          //print(provider.db);
        });
      });
    });
    tearDown(() {
      provider.close();
    });
    test('toString', () {
      //print(provider);
      expect(provider.toString(), startsWith('{'));

      final anotherProvider = TestProvider(idbFactory);
      expect(anotherProvider.toString(), '{}');
      //print(anotherProvider);
    });
    test('empty', () {
      return provider.count().then((count) {
        expect(count, 0);
      });
    });

    test('put/get', () {
      return provider.putName('test').then((int key) {
        expect(key, 1);
        return provider.getName(key).then((String? name) {
          expect(name, 'test');
        });
      });
    });

    test('get/put', () {
      return provider.getName(1).then((data) {
        expect(data, isNull);
        return provider.putName('test').then((int key) {
          expect(key, 1);
          return provider.getName(key).then((String? name) {
            expect(name, 'test');
          });
        }).then((_) {
          return provider.count().then((count) {
            expect(count, 1);
          });
        });
      });
    });

    Future<int> slowCount() {
      final trans = RawProviderStoreTransaction(provider, itemsStore);
      var count = 0;
      return trans.store!.objectStore
          .openCursor(
              //
              direction: idbDirectionNext,
              autoAdvance: false)
          .listen((CursorWithValue cwv) {
            count++;
          })
          .asFuture<void>()
          .then((_) {
            return count;
          });
    }

    test('cursor count', () {
      slowCount().then((int count) {
        expect(count, 0);
      });
    });
    test('getNames', () {
      final c1 = 'C1';
      final a2 = 'A2';
      final b3 = 'B3';
      /*
      int c1;
      int a2;
      int b3;
      */
      return provider.getNames().then((var list) {
        expect(list, isEmpty);
      }).then((_) {
        return provider.putName(c1).then((int key) {
          //c1 = key;
        });
      }).then((_) {
        return provider.getNames().then((var list) {
          expect(list, [c1]);
          //expect(list.first, C1);
        });
      }).then((_) {
        return provider.putName(a2).then((int key) {
          //a2 = key;
        });
      }).then((_) {
        return provider.putName(b3).then((int key) {
          //b3 = key;
        });
      }).then((_) {
        return provider.getNames().then((var list) {
          expect(list, [c1, a2, b3]);
          //expect(list.first, C1);
        });
      }).then((_) {
        return provider.getNames(limit: 2).then((var list) {
          expect(list, [c1, a2]);
          //expect(list.first, C1);
        });
      }).then((_) {
        return provider.getOrderedNames().then((var list) {
          expect(list, [a2, b3, c1]);
          //expect(list.first, C1);
        });
      });
    });

    test('put/clear/get', () {
      return provider.putName('test').then((int key) {
        expect(key, 1);
        return provider.clear().then((_) {
          return provider.getName(key).then((String? name) {
            expect(name, isNull);
          });
        });
      });
    });
  });
}
//class TestApp extends ConsoleApp {
//
//}
