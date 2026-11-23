import 'package:idb_shim/sdb.dart';
import 'package:tekartik_sdb_sembast/sdb_sembast.dart';

/// The VM: sembast in memory.
final SdbFactory demoSdbFactory = sdbFactorySembastNewInMemory();

/// What [demoSdbFactory] stores in.
const demoSdbFactoryName = 'sembast in memory';
