import 'package:idb_shim/sdb.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/sdb_test.dart';

import 'school_db.dart';

void main() {
  idbSchemaSdbTest(idbMemoryContext);
}

var testStore1 = SdbStoreRef<int, SdbModel>('store1');
var testIndex1 = testStore1.index<int>('index1'); // On field 'field1'
final testSchemaIndex1 = testIndex1.schema(keyPath: 'field1');
final testSchemaIndex1bis = testIndex1.schema(keyPath: 'field2');

void idbSchemaSdbTest(TestContext ctx) {
  var factory = sdbFactoryFromIdb(ctx.factory);
  schemaSdbTest(SdbTestContext(factory));
}

/// Simple SDB test
void schemaSdbTest(SdbTestContext ctx) {
  var factory = ctx.factory;

  group('sdb_schema', () {
    test('complex 1 school', () async {
      var dbName = 'sdb_schema_complex_1_school.db';
      await factory.deleteDatabase(dbName);
      var schoolDb = SchoolDb();
      var db = await factory.openDatabase(
        dbName,
        version: 1,
        schema: schoolDb.schoolDbSchema,
      );
      await db.inStoresTransaction(
        [schoolDb.schoolStore, schoolDb.studentStore],
        SdbTransactionMode.readWrite,
        (txn) async {
          var schoolRecord = SdbModel.of({'name': 'My School'});
          var schoolKey = 'school1';
          await schoolDb.schoolStore.record(schoolKey).put(txn, schoolRecord);
          var studentRecord1 = SdbModel.of({
            'name': 'Alice',
            'schoolId': schoolKey,
          });
          var studentRecord2 = SdbModel.of({
            'name': 'Bob',
            'schoolId': schoolKey,
          });
          var studentRecord3 = SdbModel.of({
            'name': 'John',
            'schoolId': 'school2',
          });
          await schoolDb.studentStore.add(txn, studentRecord1);
          await schoolDb.studentStore.add(txn, studentRecord2);
          await schoolDb.studentStore.add(txn, studentRecord3);

          var students = await schoolDb.studentSchoolIndex
              .record(schoolKey)
              .findRecords(txn);
          expect(students.length, 2);
          for (var student in students) {
            print('Student: $student');
          }
        },
      );
    });
    test('migration', () async {
      var dbName = 'sdb_schema_test.db';
      await factory.deleteDatabase(dbName);
      var db = await factory.openDatabase(
        dbName,
        version: 1,
        schema: SdbDatabaseSchema(stores: [testStore.schema()]),
      );
      expect(
        await db.readSchemaDef(),
        equals(
          SdbDatabaseSchemaDef(
            stores: [SdbStoreSchemaDef(name: testStore.name)],
          ),
        ),
      );
      await db.close();

      await expectLater(() async {
        await factory.openDatabase(
          dbName,
          version: 1,
          schema: SdbDatabaseSchema(
            stores: [
              testStore.schema(indexes: [testSchemaIndex1]),
            ],
          ),
        );
      }, throwsA(isA<StateError>()));

      db = await factory.openDatabase(
        dbName,
        version: 2,
        schema: SdbDatabaseSchema(
          stores: [
            testStore.schema(indexes: [testSchemaIndex1]),
          ],
        ),
      );
      expect((await db.readSchemaDef()).toDebugMap(), {
        'stores': {
          'test': {
            'indexes': {
              'index1': {'keyPath': 'field1'},
            },
          },
        },
      });
      await db.close();
      await expectLater(() async {
        await factory.openDatabase(
          dbName,
          schema: SdbDatabaseSchema(
            stores: [
              testStore.schema(indexes: [testSchemaIndex1bis]),
            ],
          ),
        );
      }, throwsA(isA<StateError>()));
      //await db.close();
    });
  });
}
