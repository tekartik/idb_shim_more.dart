// ignore_for_file: public_member_api_docs

import 'package:sembast/sembast.dart' as sembast;
import 'package:tekartik_sdb_sembast/src/sembast/sdb_import.dart';

/// The sembast store holding the sdb schema: one record per store, keyed by
/// the store name.
const sdbSembastMetaStoreName = '_sdb_schema';

/// The schema store.
final sdbSembastMetaStore = sembast.StoreRef<String, Map<String, Object?>>(
  sdbSembastMetaStoreName,
);

Object? _keyPathToMap(SdbKeyPath? keyPath) {
  if (keyPath == null) {
    return null;
  }
  return keyPath.isSingle ? keyPath.keyPath : keyPath.keyPaths;
}

SdbKeyPath? _keyPathFromMap(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is List) {
    return sdbKeyPathFromAny(value.cast<String>());
  }
  return sdbKeyPathFromAny(value);
}

/// Index definition of a store.
class SdbIndexMetaSembast {
  final String name;
  final SdbKeyPath keyPath;
  final bool unique;

  SdbIndexMetaSembast({
    required this.name,
    required this.keyPath,
    required this.unique,
  });

  factory SdbIndexMetaSembast.fromMap(Map<Object?, Object?> map) =>
      SdbIndexMetaSembast(
        name: map['name'] as String,
        keyPath: _keyPathFromMap(map['keyPath'])!,
        unique: map['unique'] == true,
      );

  Map<String, Object?> toMap() => {
    'name': name,
    'keyPath': _keyPathToMap(keyPath),
    if (unique) 'unique': true,
  };

  @override
  String toString() => 'IndexMeta($name, $keyPath${unique ? ', unique' : ''})';
}

/// Store definition: key path, auto increment and indexes.
class SdbStoreMetaSembast {
  final String name;
  final SdbKeyPath? keyPath;
  final bool autoIncrement;

  /// Mutable, by name.
  final Map<String, SdbIndexMetaSembast> indexes;

  SdbStoreMetaSembast({
    required this.name,
    required this.keyPath,
    required this.autoIncrement,
    Map<String, SdbIndexMetaSembast>? indexes,
  }) : indexes = indexes ?? {};

  factory SdbStoreMetaSembast.fromMap(Map<Object?, Object?> map) {
    var indexList = (map['indexes'] as List?) ?? const [];
    var indexes = <String, SdbIndexMetaSembast>{};
    for (var item in indexList) {
      var index = SdbIndexMetaSembast.fromMap(item as Map<Object?, Object?>);
      indexes[index.name] = index;
    }
    return SdbStoreMetaSembast(
      name: map['name'] as String,
      keyPath: _keyPathFromMap(map['keyPath']),
      autoIncrement: map['autoIncrement'] == true,
      indexes: indexes,
    );
  }

  Map<String, Object?> toMap() => {
    'name': name,
    if (keyPath != null) 'keyPath': _keyPathToMap(keyPath),
    if (autoIncrement) 'autoIncrement': true,
    if (indexes.isNotEmpty)
      'indexes': indexes.values.map((index) => index.toMap()).toList(),
  };

  @override
  String toString() => 'StoreMeta(${toMap()})';
}

/// Read the schema, by store name.
Future<Map<String, SdbStoreMetaSembast>> sdbSembastReadMetas(
  sembast.DatabaseClient client,
) async {
  var snapshots = await sdbSembastMetaStore.find(client);
  return {
    for (var snapshot in snapshots)
      snapshot.key: SdbStoreMetaSembast.fromMap(snapshot.value),
  };
}

/// Write the whole schema.
Future<void> sdbSembastWriteMetas(
  sembast.DatabaseClient client,
  Map<String, SdbStoreMetaSembast> metas,
) async {
  await sdbSembastMetaStore.delete(client);
  for (var meta in metas.values) {
    await sdbSembastMetaStore.record(meta.name).put(client, meta.toMap());
  }
}
