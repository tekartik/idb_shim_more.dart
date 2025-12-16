import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

class SchoolDb {
  final scvSchoolStore = scvStringStoreFactory.store<DbSchoolRecord>('school');
  final scvStudentStore = scvIntStoreFactory.store<DbStudentRecord>('student');
  final schoolStore = SdbStoreRef<String, SdbModel>('school');
  final studentStore = SdbStoreRef<int, SdbModel>('student');

  /// Index on studentStore for field 'schoolId'
  late final studentSchoolIndex = studentStore.index<String>(
    'school',
  ); // On field 'schoolId'
  late final scvStudentSchoolIndex = scvStudentStore.index<String>(
    'school',
  ); // On field 'schoolId'
  late final schoolDbSchema = SdbDatabaseSchema(
    stores: [
      scvSchoolStore.schema(),
      scvStudentStore.schema(
        autoIncrement: true,
        indexes: [scvStudentSchoolIndex.schema(keyPath: 'schoolId')],
      ),
    ],
  );
  static void init() {
    cvAddConstructors([DbSchoolRecord.new, DbStudentRecord.new]);
  }
}

class DbSchoolRecord extends ScvStringRecordBase {
  final name = CvField<String>('name');

  @override
  CvFields get fields => [name];
}

class DbStudentRecord extends ScvIntRecordBase {
  final name = CvField<String>('name');
  final schoolId = CvField<String>('schoolId');

  @override
  CvFields get fields => [name, schoolId];
}
