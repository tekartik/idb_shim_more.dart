library;

import 'package:tekartik_idb_provider/provider.dart';

import 'test_common.dart';

void main() {
  testMain(idbMemoryContext);
}

void testMain(TestContext context) {
  final idbFactory = context.factory;
  group('meta', () {
    group('raw', () {
      test('index', () {
        final indexMeta = ProviderIndexMeta('idx', 'my_key');
        final indexMeta2 = ProviderIndexMeta('idx', 'my_key');
        expect(indexMeta, indexMeta2);
        expect(
          indexMeta,
          ProviderIndexMeta('idx', 'my_key', unique: false, multiEntry: false),
        );
        expect(
          indexMeta,
          isNot(
            ProviderIndexMeta('idx', 'my_key', unique: false, multiEntry: true),
          ),
        );
        expect(
          indexMeta,
          isNot(
            ProviderIndexMeta('idx', 'my_key', unique: true, multiEntry: false),
          ),
        );
        expect(
          indexMeta,
          isNot(
            ProviderIndexMeta(
              'idx',
              'my_key2',
              unique: false,
              multiEntry: false,
            ),
          ),
        );
        expect(
          indexMeta,
          isNot(
            ProviderIndexMeta(
              'idx2',
              'my_key',
              unique: false,
              multiEntry: false,
            ),
          ),
        );
      });

      test('store', () {
        var storeMeta = ProviderStoreMeta('str');
        expect(storeMeta, ProviderStoreMeta('str'));
        expect(storeMeta, isNot(ProviderStoreMeta('str2')));
        expect(
          storeMeta,
          ProviderStoreMeta('str', keyPath: null, autoIncrement: false),
        );
        expect(
          storeMeta,
          isNot(ProviderStoreMeta('str', keyPath: null, autoIncrement: true)),
        );
        expect(
          storeMeta,
          isNot(
            ProviderStoreMeta('str', keyPath: 'some', autoIncrement: false),
          ),
        );
        expect(
          storeMeta,
          isNot(ProviderStoreMeta('str2', keyPath: null, autoIncrement: false)),
        );

        storeMeta = ProviderStoreMeta(
          'str',
          keyPath: 'some',
          autoIncrement: true,
        );
        var storeMeta2 = ProviderStoreMeta(
          'str',
          keyPath: 'some',
          autoIncrement: true,
        );
        expect(storeMeta, storeMeta2);
        final indexMeta = ProviderIndexMeta('idx', 'my_key');
        final indexMeta2 = ProviderIndexMeta('idx', 'my_key');

        storeMeta = ProviderStoreMeta(
          'str',
          keyPath: 'some',
          autoIncrement: true,
          indecies: [indexMeta],
        );
        expect(storeMeta, isNot(storeMeta2));
        storeMeta = ProviderStoreMeta(
          'str',
          keyPath: 'some',
          autoIncrement: true,
          indecies: [indexMeta, indexMeta2],
        );
        storeMeta2 = ProviderStoreMeta(
          'str',
          keyPath: 'some',
          autoIncrement: true,
          indecies: [indexMeta2, indexMeta],
        );
        expect(storeMeta, storeMeta2);
      });

      test('stores', () {
        final storeMeta = ProviderStoreMeta('str');
        final storeMeta2 = ProviderStoreMeta('str2');
        var storesMeta = ProviderStoresMeta([]);
        var storesMeta2 = ProviderStoresMeta([]);
        expect(storesMeta, storesMeta2);
        storesMeta = ProviderStoresMeta([storeMeta]);
        expect(storesMeta, isNot(storesMeta2));
        storesMeta2 = ProviderStoresMeta([storeMeta]);
        expect(storesMeta, storesMeta2);
        storesMeta2 = ProviderStoresMeta([storeMeta2]);
        expect(storesMeta, isNot(storesMeta2));
        storesMeta = ProviderStoresMeta([storeMeta, storeMeta2]);
        storesMeta2 = ProviderStoresMeta([storeMeta2, storeMeta]);
        expect(storesMeta, storesMeta2);
      });
    });
    group('provider', () {
      group('more', () {
        final providerName = 'test';

        late DynamicProvider provider;

        setUp(() {
          provider = DynamicProvider(idbFactory, ProviderDbMeta(providerName));
          return provider.delete();
        });
        tearDown(() async {
          provider.close();
        });

        Future roundCircle(ProviderStoresMeta storesMeta) {
          provider.addStores(storesMeta);
          return provider.ready!.then((Provider readyProvider) {
            return provider.storesMeta!.then((metas) {
              expect(metas, storesMeta);
              expect(metas, isNot(same(storesMeta)));
            });
          });
        }

        test('one_store', () {
          provider.addStore(ProviderStoreMeta('store'));
          return provider.ready!.then((Provider readyProvider) {
            return provider.storesMeta!.then((metas) {
              expect(metas, ProviderStoresMeta([ProviderStoreMeta('store')]));
            });
          });
        });

        test('one_store round_cirle', () {
          final meta = ProviderStoresMeta([
            //)
            ProviderStoreMeta('store'),
          ]);
          return roundCircle(meta);
        });
        test('two_stores', () {
          provider.addStore(ProviderStoreMeta('store'));
          provider.addStore(ProviderStoreMeta('store1'));
          return provider.ready!.then((Provider readyProvider) {
            return provider.storesMeta!.then((metas) {
              expect(
                metas,
                ProviderStoresMeta([
                  ProviderStoreMeta('store'),
                  ProviderStoreMeta('store1'),
                ]),
              );
            });
          });
        });

        test('one_index', () {
          final meta = ProviderStoresMeta([
            //)
            ProviderStoreMeta(
              'store',
              indecies: //
                  [ProviderIndexMeta('idx', 'my_key')], //
            ),
          ]);
          return roundCircle(meta);
        });
      });
    });
  });
}

//class TestApp extends ConsoleApp {
//
//}
