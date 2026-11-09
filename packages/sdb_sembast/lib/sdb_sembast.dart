/// Simple DB (`package:idb_shim/sdb.dart`) on top of sembast, without
/// IndexedDB: [sdbFactorySembastFrom] (any sembast factory: memory, io,
/// web) and [sdbFactorySembastNewInMemory].
library;

export 'src/sembast/sdb_sembast_factory.dart'
    show sdbFactorySembastNewInMemory, SdbFactorySembast, sdbFactorySembastFrom;
