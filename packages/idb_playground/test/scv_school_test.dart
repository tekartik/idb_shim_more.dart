import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/sdb_test.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:tekartik_idb_playground/scv_school_schema.dart';

void main() {
  idbSchemaSdbTest(idbMemoryContext);
}

void idbSchemaSdbTest(TestContext ctx) {
  var factory = sdbFactoryFromIdb(ctx.factory);
  schemaSdbTest(SdbTestContext(factory));
}

/// Simple SDB test
void schemaSdbTest(SdbTestContext ctx) {
  SchoolDb.init();
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
          var schoolRecord = DbSchoolRecord()..name.v = 'My School';
          var schoolKey = 'school1';
          await schoolDb.scvSchoolStore
              .record(schoolKey)
              .put(txn, schoolRecord);
          var schools = await schoolDb.scvSchoolStore.findRecords(txn);
          print('Schools: $schools');
          expect(schools.first.ref.key, 'school1');
          var studentRecord1 = DbStudentRecord()
            ..name.v = 'Alice'
            ..schoolId.v = schoolKey;
          var studentRecord2 = SdbModel.of({
            'name': 'Bob',
            'schoolId': schoolKey,
          });
          var studentRecord3 = SdbModel.of({
            'name': 'John',
            'schoolId': 'school2',
          });
          await schoolDb.scvStudentStore.add(txn, studentRecord1);
          await schoolDb.studentStore.add(txn, studentRecord2);
          await schoolDb.studentStore.add(txn, studentRecord3);

          var students = await schoolDb.scvStudentSchoolIndex
              .record(schoolKey)
              .findRecords(txn);
          expect(students.length, 2);
          for (var student in students) {
            print('Student: $student');
          }
        },
      );
    });
  });
}
