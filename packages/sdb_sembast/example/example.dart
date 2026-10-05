import 'package:tekartik_sdb_sembast/src/sembast/sdb_sembast_factory.dart';

void main() async {
  var factory = sdbFactorySembastNewInMemory();
  var db = await factory.openDatabase('test');
  await db.close();
}
