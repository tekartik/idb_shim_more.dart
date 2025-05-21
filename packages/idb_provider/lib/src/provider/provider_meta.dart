import 'package:collection/collection.dart';
import 'package:idb_shim/idb.dart';
import 'package:tekartik_common_utils/hash_code_utils.dart';

class ProviderDbMeta {
  final String name;
  final int version;

  ProviderDbMeta(this.name, [int? version]) : version = version ?? 1;

  ProviderDbMeta overrideMeta({String? name, int? version}) {
    name ??= this.name;
    version ??= this.version;
    return ProviderDbMeta(name, version);
  }

  @override
  int get hashCode => safeHashCode(name) * 17 + safeHashCode(version);

  @override
  bool operator ==(other) {
    if (other is ProviderDbMeta) {
      if (name != other.name) {
        return false;
      }
      if (version != other.version) {
        return false;
      }
      return true;
    }
    return false;
  }

  @override
  String toString() => '$name($version)';
}

class ProviderDb {
  Database? _database;

  Database? get database => _database;

  //Provider _provider;
  ProviderDb(this._database);

  ProviderStore createStore(ProviderStoreMeta meta) {
    final objectStore = database!.createObjectStore(
      meta.name,
      keyPath: meta.keyPath,
      autoIncrement: meta.autoIncrement,
    );
    return ProviderStore(objectStore);
  }

  /// during onUpdateOnly
  /// return false if it does not exists
  bool deleteStore(String name) {
    // dev bug
    if (storeNames.contains(name)) {
      database!.deleteObjectStore(name);
      return true;
    }
    return false;
  }

  Iterable<String> get storeNames {
    return database!.objectStoreNames;
  }

  ProviderDbMeta? _meta;

  ProviderDbMeta? get meta {
    _meta ??= ProviderDbMeta(database!.name, database!.version);

    return _meta;
  }

  int get version => meta!.version;

  void close() {
    database!.close();
    _database = null;
  }

  IdbFactory get factory => _database!.factory;

  @override
  String toString() => '$_database';
}

class StoreRow<K, V> {}

class ProviderStoresMeta {
  final Iterable<ProviderStoreMeta?> stores;

  ProviderStoresMeta(this.stores);

  @override
  int get hashCode =>
      stores.length * 17 +
      (stores.isEmpty ? 0 : safeHashCode(stores.first.hashCode));

  @override
  bool operator ==(other) {
    if (other is ProviderStoresMeta) {
      return const UnorderedIterableEquality<Object?>().equals(
        stores,
        other.stores,
      );
    }
    return false;
  }

  @override
  String toString() => '$stores';
}

class ProviderStoreMeta {
  final String name;
  final String? keyPath;
  final bool autoIncrement;

  ProviderStoreMeta(
    this.name, {
    this.keyPath,
    bool? autoIncrement,
    List<ProviderIndexMeta?>? indecies,
  })
    //
    : autoIncrement = (autoIncrement == true),
       //
       indecies = (indecies == null) ? [] : indecies;
  final List<ProviderIndexMeta?> indecies;

  ProviderStoreMeta overrideIndecies(List<ProviderIndexMeta> indecies) {
    return ProviderStoreMeta(
      name,
      keyPath: keyPath,
      autoIncrement: autoIncrement,
      indecies: indecies,
    );
  }

  @override
  int get hashCode {
    return safeHashCode(name);
  }

  @override
  bool operator ==(other) {
    if (other is ProviderStoreMeta) {
      if (other.name != name) {
        return false;
      }
      if (other.keyPath != keyPath) {
        return false;
      }
      if (other.autoIncrement != autoIncrement) {
        return false;
      }
      // order not important for index
      if (!(const UnorderedIterableEquality<Object?>().equals(
        indecies,
        other.indecies,
      ))) {
        return false;
      }
      return true;
    }
    return false;
  }

  @override
  String toString() =>
      '$name($keyPath${autoIncrement ? ' auto' : ''}) $indecies';
}

class ProviderStore {
  ProviderStoreMeta? _meta;

  ProviderStoreMeta? get meta {
    if (_meta == null) {
      final indecies = <ProviderIndexMeta?>[];
      for (final indexName in indexNames) {
        final index = this.index(indexName);
        indecies.add(index.meta);
      }
      _meta = ProviderStoreMeta(
        objectStore.name,
        keyPath: objectStore.keyPath as String?,
        autoIncrement: objectStore.autoIncrement,
        indecies: indecies,
      );
    }
    return _meta;
  }

  final ObjectStore objectStore;

  ProviderStore(this.objectStore);

  ProviderIndex createIndex(ProviderIndexMeta meta) {
    final index = objectStore.createIndex(
      meta.name,
      meta.keyPath,
      unique: meta.unique,
      multiEntry: meta.multiEntry,
    );
    return ProviderIndex(index);
  }

  Future<int> count() => objectStore.count();

  ProviderIndex index(String name) {
    final index = objectStore.index(name);
    return ProviderIndex(index);
  }

  Future<Object?> get(Object key) => objectStore.getObject(key);

  Future put(Object value, [Object? key]) => objectStore.put(value, key);

  Future add(Object value, [Object? key]) => objectStore.add(value, key);

  Future delete(Object key) => objectStore.delete(key);

  Future clear() => objectStore.clear();

  List<String> get indexNames => objectStore.indexNames;
}

class ProviderIndexMeta {
  final String name;
  final Object keyPath;
  final bool unique;
  final bool multiEntry;

  ProviderIndexMeta(this.name, this.keyPath, {bool? unique, bool? multiEntry})
    //
    : unique = (unique == true),
      multiEntry = (multiEntry == true);

  @override
  int get hashCode {
    // likely content will differ..
    return safeHashCode(name);
  }

  @override
  bool operator ==(other) {
    if (other is ProviderIndexMeta) {
      if (other.name != name) {
        return false;
      }
      if (other.keyPath != keyPath) {
        return false;
      }
      if (other.unique != unique) {
        return false;
      }
      if (other.multiEntry != multiEntry) {
        return false;
      }
      return true;
    }
    return false;
  }

  @override
  String toString() =>
      '$name $keyPath${unique ? 'unique' : ''}${multiEntry ? 'multi' : ''}';
}

class ProviderIndex {
  ProviderIndexMeta? _meta;

  ProviderIndexMeta? get meta {
    _meta ??= ProviderIndexMeta(
      index.name,
      index.keyPath,
      unique: index.unique,
      multiEntry: index.multiEntry,
    );

    return _meta;
  }

  final Index index;

  ProviderIndex(this.index);

  Future<int> count() => index.count();
}
