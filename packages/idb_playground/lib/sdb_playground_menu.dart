import 'dart:core' as core;
import 'dart:core';

import 'package:path/path.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:tekartik_app_dev_menu/dev_menu.dart';

class PlaygoundNotesDb {
  final void Function(Object? object) _print;
  final SdbDatabase db;

  PlaygoundNotesDb({void Function(Object? object)? print, required this.db})
    : _print = print ?? core.print {
    cvAddConstructors([DbNote.new]);
  }

  static Future<PlaygoundNotesDb> open(SdbFactory factory, String name) async {
    var db = await factory.openDatabaseOnDowngradeDelete(
      name,
      options: dbOpenOptions,
    );
    return PlaygoundNotesDb(db: db);
  }

  Future<void> generateNotes(int count) async {
    for (var i = 0; i < count; i++) {
      await dbNoteStore.add(
        db,
        DbNote()
          ..timestamp.v = SdbTimestamp.now()
          ..title.v = 'note ${i + 1}',
      );
    }
    await dumpNotes(limit: 5);
    _print('Added $count notes');
  }

  Future<void> dumpNotes({int? limit}) async {
    var found = 0;
    var notes = await dbNoteStore.findRecords(
      db,
      options: SdbFindOptions(descending: true, limit: limit),
    );
    for (var note in notes) {
      _print('note: $note');
      if (++found >= 15) {
        break;
      }
    }
    _print(
      'found ${notes.length} notes${limit != null ? ', limit: $limit' : ''}, showing last $found',
    );
  }

  Future<void> close() async {
    await db.close();
  }
}

void main(List<String> args) {
  mainMenu(args, () {
    sdbPlaygroundMenu(sdbFactoryMemory, path: join('.local', 'playground'));
  });
}

/// Record with an int key
class DbNote extends ScvIntRecordBase {
  final title = CvField<String>('title');
  final description = CvField<String>('description');
  final timestamp = CvField<SdbTimestamp>('timestamp');

  @override
  List<CvField> get fields => [title, description, timestamp];
}

final dbNoteStore = scvIntStoreFactory.store<DbNote>('note');
final dbTimestampIndex = dbNoteStore.index<SdbTimestamp>('timestamp_index');
var dbSchema = SdbDatabaseSchema(
  stores: [
    dbNoteStore.schema(
      autoIncrement: true,
      indexes: [dbTimestampIndex.schema(keyPath: 'timestamp')],
    ),
  ],
);
final dbOpenOptions = SdbOpenDatabaseOptions(schema: dbSchema, version: 1);

extension DbNoteExt on SdbDatabase {
  Future<List<DbNote>> getNotes() => dbNoteStore.findRecords(this);
}

void sdbPlaygroundMenu(SdbFactory sdbFactory, {String? path}) {
  cvAddConstructors([DbNote.new]);
  String fixDbName(String name) {
    if (path != null) {
      return join(path, name);
    }

    return name;
  }

  menu('note manager', () async {
    late SdbDatabase db;
    late PlaygoundNotesDb notesDb;
    Future<void> dbClose() async {
      await db.close();
      write('closed ${db.name}');
    }

    Future<void> dbOpen() async {
      var dbName = fixDbName('notes.db');
      db = await sdbFactory.openDatabaseOnDowngradeDelete(
        dbName,
        options: dbOpenOptions,
      );
      notesDb = PlaygoundNotesDb(db: db, print: (msg) => write(msg));
      write('opened $dbName');
    }

    enter(() async {
      await dbOpen();
    });
    leave(() async {
      await dbClose();
    });
    item('db info', () async {
      print('db: $db');
      print('factory: ${db.factory}');
      print('name: ${db.name}');
      print('version: ${db.version}');
    });
    item('reopen', () async {
      await dbClose();
      await dbOpen();
    });
    item('dump_notes', () async {
      await notesDb.dumpNotes();
    });
    item('count', () async {
      write('count: ${await dbNoteStore.count(db)}');
    });

    item('dump_last_15', () async {
      await notesDb.dumpNotes(limit: 15);
    });

    item('add note', () async {
      await dbNoteStore.add(
        db,
        DbNote()
          ..timestamp.v = SdbTimestamp.now()
          ..title.v = 'note 1',
      );
      await notesDb.dumpNotes();
    });
    item('prompt count and create X notes', () async {
      var count = int.tryParse(await prompt('How many notes?')) ?? 0;
      await notesDb.generateNotes(count);
    });
  });
  menu('open', () async {
    item('open downgrade', () async {
      var name = fixDbName('open_downgrade.db');
      await sdbFactory.deleteDatabase(name);
      var db = await sdbFactory.openDatabase(
        name,
        options: dbOpenOptions.copyWith(version: 2),
      );
      await db.close();
      try {
        db = await sdbFactory.openDatabase(name, options: dbOpenOptions);
        await db.close();
      } catch (e) {
        write('error type: ${e.runtimeType}');
        write('error: $e');
      }
    });
    item('openOnDowngradeDelete downgrade', () async {
      var name = fixDbName('sdb_openOnDowngradeDelete_downgrade.db');
      await sdbFactory.deleteDatabase(name);
      write('open version 2');
      var db = await sdbFactory.openDatabase(
        name,
        options: dbOpenOptions.copyWith(
          version: 2,
          onVersionChange: (SdbVersionChangeEvent e) async {
            var txn = e.transaction;
            await dbNoteStore.add(
              txn,
              DbNote()
                ..timestamp.v = SdbTimestamp.now()
                ..title.v = 'note 2'
                ..description.v = 'description 2',
            );
          },
        ),
      );
      Future<void> dumpRows() async {
        write('opened ${db.version}');
        var notes = await dbNoteStore.findRecords(db);

        for (var note in notes) {
          write('row: $note');
        }
        write('found ${notes.length} notes');
      }

      await dumpRows();
      await db.close();
      write('open version 1');
      try {
        db = await sdbFactory.openDatabaseOnDowngradeDelete(
          name,
          options: dbOpenOptions.copyWith(
            onVersionChange: (SdbVersionChangeEvent e) async {
              var txn = e.transaction;
              await dbNoteStore.add(
                txn,
                DbNote()
                  ..timestamp.v = SdbTimestamp.now()
                  ..title.v = 'note 1'
                  ..description.v = 'description 1',
              );
            },
          ),
        );
        await dumpRows();
        await db.close();
      } catch (e) {
        write('error type: ${e.runtimeType}');
        write('error: $e');
      }
    });
  });
}
