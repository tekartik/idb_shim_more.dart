import 'package:idb_shim/sdb.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:tekartik_sdb_sembast/sdb_sembast.dart';

/// A browser: sembast_web, in IndexedDB.
final SdbFactory demoSdbFactory = sdbFactorySembastFrom(databaseFactoryWeb);

/// What [demoSdbFactory] stores in.
const demoSdbFactoryName = 'sembast_web (IndexedDB)';
