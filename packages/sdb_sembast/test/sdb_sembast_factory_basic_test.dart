import 'package:sembast/sembast_memory.dart';
import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_factory.dart';
import 'package:test/test.dart';

//import '../idb_test_common.dart';

void main() {
  group('sdb_factory', () {
    test('init factory', () async {
      var factory = sdbFactorySembastFrom(newDatabaseFactoryMemory());
      var db = await factory.openDatabase('test.db');
      await db.close();
    });
  });
}
