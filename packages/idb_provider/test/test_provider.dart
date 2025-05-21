library;

import 'dart:async';
import 'package:idb_shim/idb_client.dart';
import 'package:tekartik_idb_provider/provider.dart';

int dbVersion = 1;
String databaseName = 'tekartik_app.test.app_provider';

String itemsStore = 'items';
String nameIndex = 'name';
String nameField = 'name';

// String NAME_FIELD = 'name';

class TestProvider extends Provider {
  TestProvider(IdbFactory? idbFactory) {
    init(idbFactory, databaseName, dbVersion);
  }
  @override
  void onUpdateDatabase(VersionChangeEvent e) {
    if (e.oldVersion < dbVersion) {
      // delete stuff
    }
    var objectStore = database!.createObjectStore(
      itemsStore,
      autoIncrement: true,
    );
    objectStore.createIndex(nameIndex, nameField, unique: false);
  }

  @override
  Future delete() {
    return idbFactory!.deleteDatabase(databaseName);
  }

  Future count() {
    var trans = RawProviderStoreTransaction(this, itemsStore);
    return trans.count().then((int count) {
      return trans.completed.then((_) {
        return count;
      });
    });
  }

  Future<List<String?>> getNames({int? limit, int? offset}) {
    var trans = RawProviderStoreTransaction(this, itemsStore);
    final names = <String?>[];
    return trans
        .openCursor(limit: limit, offset: offset)
        .listen((CursorWithValue cwv) {
          names.add((cwv.value as Map)[nameField] as String?);
        })
        .asFuture<void>()
        .then((_) {
          return names;
        });
  }

  Future<List<String?>> getOrderedNames({int? limit, int? offset}) {
    var trans = ProviderIndexTransaction<Object?, Object?>(
      this,
      itemsStore,
      nameIndex,
    );

    final names = <String?>[];
    return trans
        .openCursor(limit: limit, offset: offset)
        .listen((CursorWithValue cwv) {
          names.add((cwv.value as Map)[nameField] as String?);
        })
        .asFuture<void>()
        .then((_) {
          return trans.completed;
        })
        .then((_) {
          return names;
        });
  }

  Future<int> putName(String name) {
    var trans = RawProviderStoreTransaction(this, itemsStore, true);

    final data = <String, Object?>{};
    data[nameField] = name;

    return trans.add(data).then((key) {
      return trans.completed.then((_) {
        return key as int;
      });
    });
  }

  // null if not found
  Future<String?> getName(int key) {
    var trans = RawProviderStoreTransaction(this, itemsStore);

    return trans.get(key).then((var data) {
      return trans.completed.then((_) {
        if (data == null) {
          return null;
        }
        return (data as Map)[nameField] as String;
      });
    });
  }

  Future<int> get(int key) {
    var trans = RawProviderStoreTransaction(this, itemsStore);
    return trans.store!.get(key).then((var key) {
      return trans.completed.then((_) {
        return key as int;
      });
    });
  }
}
