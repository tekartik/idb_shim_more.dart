library;

import 'package:tekartik_idb_provider/provider.dart';

import 'test_common.dart';

void main() {
  testMain(idbMemoryContext);
}

void testMain(TestContext context) {
  final idbFactory = context.factory;
  group('provider_dynamic', () {
    group('raw', () {
      //DynamicProvider provider;

      test('database', () {
        final provider = DynamicProvider(idbFactory, ProviderDbMeta('test'));

        return provider.delete().then(
          (_) => provider.ready!.then((Provider readyProvider) {
            expect(provider, readyProvider);
            expect(provider.db!.meta!.name, 'test');
            expect(provider.db!.meta!.version, 1);
            expect(provider.db!.storeNames, isEmpty);
            provider.close();
          }),
        );
      });

      test('database name version', () {
        final provider = DynamicProvider(
          idbFactory,
          ProviderDbMeta('test2', 2),
        );

        return provider.delete().then(
          (_) => provider.ready!.then((Provider readyProvider) {
            expect(provider, readyProvider);
            expect(provider.db!.meta!.name, 'test2');
            expect(provider.db!.meta!.version, 2);
            expect(provider.db!.storeNames, isEmpty);
            provider.close();
          }),
        );
      });
    });
  });
  group('more', () {
    final providerName = 'test';

    late DynamicProvider provider;
    ProviderTransaction? transaction;

    setUp(() {
      transaction = null;
      provider = DynamicProvider(idbFactory, ProviderDbMeta(providerName));
      return provider.delete();
    });
    tearDown(() async {
      if (transaction != null) {
        await transaction!.completed;
      }
      provider.close();
    });

    test('one_store', () {
      provider.addStore(ProviderStoreMeta('store'));
      return provider.ready!.then((Provider readyProvider) {
        final txn = provider.storeTransaction('store');
        expect(txn.store!.meta!.name, 'store');
        expect(txn.store!.meta!.keyPath, null);
        expect(txn.store!.meta!.autoIncrement, false);

        expect(txn.store!.meta!.indecies, isEmpty);

        // for cleanup
        transaction = txn;
      });
    });

    test('multiple_store', () {
      provider.addStore(
        ProviderStoreMeta('store', keyPath: 'key', autoIncrement: true),
      );
      provider.addStore(ProviderStoreMeta('store2'));
      return provider.ready!.then((Provider readyProvider) {
        final txn = provider.transactionList(['store', 'store2']);
        ProviderStoreTransactionMixin txn1 = txn.store('store');
        expect(txn1.store!.meta!.name, 'store');
        expect(txn1.store!.meta!.keyPath, 'key');
        expect(txn1.store!.meta!.autoIncrement, true);

        expect(txn1.store!.meta!.indecies, isEmpty);

        ProviderStoreTransactionMixin txn2 = txn.store('store2');
        expect(txn2.store!.meta!.name, 'store2');
        expect(txn2.store!.meta!.keyPath, null);
        expect(txn2.store!.meta!.autoIncrement, false);

        expect(txn2.store!.meta!.indecies, isEmpty);

        // for cleanup
        transaction = txn;
      });
    });

    test('one_index', () {
      final indexMeta = ProviderIndexMeta('idx', 'my_key');
      provider.addStore(ProviderStoreMeta('store', indecies: [indexMeta]));
      return provider.ready!.then((Provider readyProvider) {
        final txn = provider.storeTransaction('store');
        expect(txn.store!.meta!.name, 'store');
        expect(txn.store!.meta!.keyPath, null);
        expect(txn.store!.meta!.autoIncrement, false);

        expect(txn.store!.meta!.indecies, [indexMeta]);

        // for cleanup
        transaction = txn;
      });
    });
  });
}

//class TestApp extends ConsoleApp {
//
//}
