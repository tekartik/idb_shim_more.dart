import 'package:idb_shim/sdb.dart';

class SchoolDb {
  final schoolStore = SdbStoreRef<String, SdbModel>('school');
  final studentStore = SdbStoreRef<int, SdbModel>('student');

  /// Index on studentStore for field 'schoolId'
  late final studentSchoolIndex = studentStore.index<String>(
    'school',
  ); // On field 'schoolId'
  late final schoolDbSchema = SdbDatabaseSchema(
    stores: [
      schoolStore.schema(),
      studentStore.schema(
        autoIncrement: true,
        indexes: [studentSchoolIndex.schema(keyPath: 'schoolId')],
      ),
    ],
  );
}
