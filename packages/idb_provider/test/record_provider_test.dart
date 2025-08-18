import 'package:tekartik_idb_provider/provider.dart';
import 'package:tekartik_idb_provider/record_provider.dart';

import 'test_common.dart';
//IdbFactory idbFactory;

void main() {
  testMain(idbMemoryContext);
}

const String dbFieldName = 'name';

mixin DbBasicRecordMixin {
  String? name;

  void fillFromDbEntry(Map entry) {
    name = entry[dbFieldName] as String?;
  }

  void fillDbEntry(Map entry) {
    if (name != null) {
      entry[dbFieldName] = name;
    }
  }
}

class DbBasicRecordBase extends DbRecordBase with DbBasicRecordMixin {
  @override
  dynamic id;
  DbBasicRecordBase();

  /// create if null
  factory DbBasicRecordBase.fromDbEntry(Map entry) {
    final record = DbBasicRecordBase();
    record.fillFromDbEntry(entry);
    return record;
  }
}

class DbBasicRecord extends DbRecord with DbBasicRecordMixin {
  @override
  Object? id;

  DbBasicRecord();

  /// create if null
  static DbBasicRecord? fromDbEntry(Map? entry, String? id) {
    if (entry != null && id != null) {
      final record = DbBasicRecord()..id = id;
      record.fillFromDbEntry(entry);
      return record;
    }
    return null;
  }
}

class DbBasicRecordProvider extends DbRecordProvider<DbBasicRecord, String> {
  @override
  String get store => DbBasicAppProvider.basicStore;
  @override
  DbBasicRecord? fromEntry(Map? entry, String? id) =>
      DbBasicRecord.fromDbEntry(entry, id);
}

class DbBasicAppProvider extends DynamicProvider
    with DbRecordProvidersMixin, DbRecordProvidersMapMixin {
  DbBasicRecordProvider basic = DbBasicRecordProvider();

  // version 1 - initial
  static const int dbVersion = 1;

  static const String basicStore = 'basic';

  static const String defaultDbName =
      'com.tekartik.tekartik_idb_provider.record_test.db';

  //static const String currentIndex = dbFieldCurrent;

  // _dbVersion for testing
  DbBasicAppProvider(IdbFactory idbFactory, String dbName, [int? dbVersion])
    : super.noMeta(idbFactory) {
    basic.provider = this;
    dbVersion ??= DbBasicAppProvider.dbVersion;

    init(idbFactory, dbName, dbVersion);

    providerMap = {basicStore: basic};
  }

  @override
  void close() {
    closeAll();
    super.close();
  }

  /*
  Future<ProjectProvider> getCurrentProjectProvider() async {
    var txn = project.storeTransaction(true);
    var index = txn.index(currentIndex);
    DbProject dbProject = await index.get(true);
    await txn.completed;
    ProjectProvider projectProvider;
    if (dbProject != null) {
      projectProvider =
      new ProjectProvider(idbFactory, '${appPackage}-${dbProject.id}.db');
    }
    return projectProvider;
  }
  */
  @override
  void onUpdateDatabase(VersionChangeEvent e) {
    //devPrint('${e.newVersion}/${e.oldVersion}');
    //Database db = e.database;
    //int version = e.oldVersion;

    //    if (e.oldVersion == 1) {
    //      // add index
    //      // e.transaction
    //
    //    }
    if (e.oldVersion < 2) {
      //db.deleteObjectStore(ENTRIES_STORE);

      // default erase everything, we don't care we sync
      db!.deleteStore(basicStore);

      final nameIndexMeta = ProviderIndexMeta(dbFieldName, dbFieldName);

      final basicStoreMeta = ProviderStoreMeta(
        basicStore,
        autoIncrement: true,
        indecies: [nameIndexMeta],
      );

      // ProviderIndex fileIndex = entriesStore.createIndex(indexMeta);

      addStores(ProviderStoresMeta([basicStoreMeta]));

      //providerStore.c
    } else if (e.newVersion > 2 && e.oldVersion < 3) {
      /*
      ObjectStore store = e.transaction.objectStore(basicStore);
      //idbDevPrint(store);
      ProviderStore providerStore = new ProviderStore(store);
      */
    }

    super.onUpdateDatabase(e);
  }
}

void testMain(TestContext context) {
  final idbFactory = context.factory;
  group('record_provider', () {
    group('DbRecordBase', () {
      test('equality', () {
        final record1 = DbBasicRecordBase();
        final record2 = DbBasicRecordBase();
        expect(record1.hashCode, record2.hashCode);
        expect(record1, record2);

        record1.name = 'value';

        expect(record1.hashCode, isNot(record2.hashCode));
        expect(record1, isNot(record2));

        record2.name = 'value';

        expect(record1.hashCode, record2.hashCode);
        expect(record1, record2);
      });
    });

    group('DbRecord', () {
      test('toString', () {
        final record1 = DbBasicRecord();

        expect(record1.toString(), '{}');
        record1.id = 'key1';
        expect(record1.toString(), '{_id: key1}');
        record1.name = 'test';
        expect(record1.toString(), '{name: test, _id: key1}');
      });
      test('equality', () {
        final record1 = DbBasicRecord();
        final record2 = DbBasicRecord();
        expect(record1.hashCode, record2.hashCode);
        expect(record1, record2);

        record1.id = 'key';

        expect(record1.hashCode, isNot(record2.hashCode));
        expect(record1, isNot(record2));

        record2.id = 'key';

        expect(record1.hashCode, record2.hashCode);
        expect(record1, record2);

        record1.name = 'value';

        expect(record1.hashCode, isNot(record2.hashCode));
        expect(record1, isNot(record2));

        record2.name = 'value';

        expect(record1.hashCode, record2.hashCode);
        expect(record1, record2);
      });
    });

    group('access', () {
      test('version', () async {
        var appProvider = DbBasicAppProvider(idbFactory, context.dbName);
        await appProvider.delete();
        await appProvider.ready;
        appProvider.close();

        appProvider = DbBasicAppProvider(
          idbFactory,
          DbBasicAppProvider.defaultDbName,
          3,
        );
        await appProvider.ready;
      });

      test('open', () async {
        final appProvider = DbBasicAppProvider(idbFactory, context.dbName);
        await appProvider.delete();
        await appProvider.ready;

        final readTxn = appProvider.basic.readTransaction;
        expect(await appProvider.basic.txnGet(readTxn, '_1'), isNull);
        await readTxn.completed;

        final record = DbBasicRecord();
        record.name = 'test';
        record.id = '_1';

        final writeTxn = appProvider.basic.writeTransaction;

        var key = (await writeTxn.putRecord(record)).id;
        expect(key, '_1');
        expect((await appProvider.basic.txnGet(writeTxn, '_1'))!.id, '_1');
        await writeTxn.completed;

        var txn = appProvider.basic.storeReadTransaction;
        var stream = txn.openCursor(limit: 1);
        await stream.listen((CursorWithValue cwv) {
          final record = DbBasicRecord.fromDbEntry(
            cwv.value as Map,
            cwv.primaryKey as String,
          )!;
          expect(record.id, '_1');
        }).asFuture<void>();

        await txn.completed;

        var txnList = appProvider.dbRecordProviderReadTransactionList([
          DbBasicAppProvider.basicStore,
        ]);
        var singleReadTxn = appProvider.basic.txnListReadTransaction(txnList);
        expect((await appProvider.basic.txnGet(singleReadTxn, '_1'))!.id, '_1');

        await txnList.completed;

        var writeTxnList = appProvider.dbRecordProviderWriteTransactionList([
          DbBasicAppProvider.basicStore,
        ]);
        //txn = appProvider.basic.txnListReadTransaction(txnList);

        var singleWriteTxn = appProvider.basic.txnListWriteTransaction(
          writeTxnList,
        );
        expect(
          (await appProvider.basic.txnGet(singleWriteTxn, '_1'))!.id,
          '_1',
        );
        await appProvider.basic.txnClear(singleWriteTxn);
        expect((await appProvider.basic.txnGet(singleWriteTxn, '_1')), isNull);

        await txnList.completed;
        //var txn = basicRecordProvider.store;
        //basicRecordProvider.get()
      });

      test('write', () async {
        final appProvider = DbBasicAppProvider(idbFactory, context.dbName);
        await appProvider.delete();
        await appProvider.ready;

        final writeTxn = appProvider.basic.writeTransaction;
        DbRecordProviderTransaction txn = writeTxn;

        final record = DbBasicRecord();
        record.name = 'test';
        record.id = '_1';

        var key = (await (txn as DbRecordProviderWriteTransaction).putRecord(
          record,
        )).id;
        expect(key, '_1');
        expect((await appProvider.basic.txnGet(txn, '_1'))!.id, '_1');
        await txn.completed;

        txn = appProvider.basic.storeReadTransaction;
        var stream = txn.openCursor(limit: 1);
        await stream.listen((CursorWithValue cwv) {
          final record = DbBasicRecord.fromDbEntry(
            cwv.value as Map,
            cwv.primaryKey as String,
          )!;
          expect(record.id, '_1');
        }).asFuture<void>();

        await txn.completed;

        var txnList = appProvider.dbRecordProviderReadTransactionList([
          DbBasicAppProvider.basicStore,
        ]);
        txn = appProvider.basic.txnListReadTransaction(txnList);
        expect((await appProvider.basic.txnGet(txn, '_1'))!.id, '_1');

        await txnList.completed;

        var writeTxnList = appProvider.dbRecordProviderWriteTransactionList([
          DbBasicAppProvider.basicStore,
        ]);
        //txn = appProvider.basic.txnListReadTransaction(txnList);

        txn = appProvider.basic.txnListWriteTransaction(writeTxnList);
        expect((await appProvider.basic.txnGet(txn, '_1'))!.id, '_1');
        await appProvider.basic.txnClear(txn);
        expect((await appProvider.basic.txnGet(txn, '_1')), isNull);

        await txnList.completed;
        //var txn = basicRecordProvider.store;
        //basicRecordProvider.get()
      });

      test('index', () async {
        final appProvider = DbBasicAppProvider(idbFactory, context.dbName);
        await appProvider.delete();
        await appProvider.ready;
        final writeTxn = appProvider.basic.writeTransaction;
        DbRecordProviderTransaction txn = writeTxn;

        final record = DbBasicRecord();
        record.name = 'test';
        record.id = '_1';

        var key = (await (txn as DbRecordProviderWriteTransaction).putRecord(
          record,
        )).id;

        txn = appProvider.basic.readTransaction;
        var index = txn.index(dbFieldName);

        expect((await appProvider.basic.indexGet(index, 'test'))!.id, key);

        //index.
        //expect(key, '_1');
      });
    });
  });
}
