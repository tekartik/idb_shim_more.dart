# tekartik_sdb_sembast

Simple DB (`package:idb_shim/sdb.dart`) implementation on top of
[sembast](https://pub.dev/packages/sembast), without IndexedDB.

Experimental: it started as a proof of concept showing that the sdb API can be
backed by something else than IndexedDB. It passes the whole sdb test suite of
`idb_test` on the sembast memory, io and web factories.

## Dependencies

```yaml
dependencies:
  tekartik_sdb_sembast:
    git:
      url: https://github.com/tekartik/idb_shim_more.dart
      path: packages/sdb_sembast
```

## Usage

```dart
import 'package:sembast/sembast_memory.dart';
import 'package:tekartik_sdb_sembast/sdb_sembast.dart';

var factory = sdbFactorySembastFrom(databaseFactoryMemory);
var db = await factory.openDatabase('test.db');
await db.close();
```

`sdbFactorySembastFrom` accepts any sembast database factory (memory, io,
web). `sdbFactorySembastNewInMemory` creates a fresh in-memory one.

## How it works

- The schema (stores, key paths, auto increment, indexes) is kept in a sembast
  store named `_sdb_schema` and applied during the sembast version change.
- Values are stored encoded with the sdb codec. The idb native types
  (DateTime, Uint8List) are stored as sembast Timestamp and Blob.
- Indexes are emulated: the store is scanned and ordered by index key then
  primary key.
