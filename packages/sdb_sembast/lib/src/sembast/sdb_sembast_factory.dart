// ignore_for_file: implementation_imports, depend_on_referenced_packages

import 'package:idb_shim/sdb.dart';
import 'package:idb_shim/src/sdb/sdb_factory.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast/sembast_memory.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_database.dart';

/// Sembast based factory
abstract class SdbFactorySembast implements SdbFactory {}

/// Factory from idb factory.
SdbFactorySembast sdbFactorySembastFrom(
  sembast.DatabaseFactory sembastFactory,
) {
  return _SdbFactorySembast(sembastFactory);
}

/// Create a new in memory factory.
SdbFactorySembast sdbFactorySembastNewInMemory() =>
    sdbFactorySembastFrom(newDatabaseFactoryMemory());

/// Private extension
extension SdbFactorySembastPrv on SdbFactorySembast {
  _SdbFactorySembast get _impl => this as _SdbFactorySembast;

  /// Sembast database factory
  sembast.DatabaseFactory get sembastFactory => _impl._sembastFactory;
}

class _SdbFactorySembast
    with SdbFactoryDefaultMixin
    implements SdbFactorySembast {
  final sembast.DatabaseFactory _sembastFactory;
  @override
  final name = 'sembast';

  _SdbFactorySembast(this._sembastFactory);

  @override
  Future<SdbDatabase> openDatabase(
    String name, {
    int? version,
    SdbOnVersionChangeCallback? onVersionChange,
    SdbOpenDatabaseOptions? options,
    SdbDatabaseSchema? schema,
  }) async {
    options ??= SdbOpenDatabaseOptions();
    options = options.copyWith(
      schema: schema,
      version: version,
      onVersionChange: onVersionChange,
    );

    var db = SdbDatabaseSembastPrv(factory: this, name: name, options: options);
    await db.open();
    return db;
  }

  @override
  Future<void> deleteDatabase(String name) async {
    await _sembastFactory.deleteDatabase(name);
  }

  @override
  Future<String> getDatabaseFullPath(String name) {
    return Future.value(name);
  }
}
