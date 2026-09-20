---
name: sembast-web-html-compat-setup
description: >-
  Use when a legacy dart:html (dart2js, non-wasm) web app needs a sembast
  database on IndexedDB: package:sembast_web_html_compat/sembast_web_html.dart,
  its databaseFactoryWeb getter, building a factory by hand with
  JdbFactoryIdb(idbFactoryNativeHtml) + DatabaseFactoryJdb, why it throws
  UnimplementedError on the VM and under wasm, running the sembast_test suites
  on it, and when to move back to package:sembast_web.
---

# sembast on IndexedDB for dart:html apps (sembast_web_html_compat)

`sembast_web_html_compat` is a compatibility copy of `sembast_web`'s
`databaseFactoryWeb` whose implementation is selected on `dart.library.html`
instead of `dart.library.js_interop`, for applications that still compile with
`dart:html` in the graph (dart2js only). It exposes one getter; everything
above it is plain `sembast`. New code should depend on `sembast_web` instead.

## Guidelines

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    sembast_web_html_compat:
      git:
        url: https://github.com/tekartik/idb_shim_more.dart
        path: packages/sembast_web_html_compat
  ```
  It pulls `sembast`, `sembast_web`, `idb_shim` and `idb_shim_html_compat`.
* The whole public API is
  `import 'package:sembast_web_html_compat/sembast_web_html.dart';` ->
  `DatabaseFactory get databaseFactoryWeb`. It does not re-export `sembast`
  (unlike `package:sembast_web/sembast_web.dart`), so import
  `package:sembast/sembast.dart` as well for `Database`, `StoreRef`,
  `intMapStoreFactory`, `Finder`, transactions.
* Use it exactly like any sembast factory:
  `await databaseFactoryWeb.openDatabase('my_db.db')`, where the "path" is the
  IndexedDB database name (no directories); then `StoreRef`/`RecordRef` CRUD
  and queries as on the io factory. Deleting is
  `databaseFactoryWeb.deleteDatabase('my_db.db')`.
* Platform: a conditional export picks the real implementation only when
  `dart:html` exists; on the Dart VM / Flutter native and under dart2wasm the
  getter throws `UnimplementedError` ("use `sembast_sqflite` or `sembast` io
  implementation"). Importing the library is safe anywhere, so shared code
  compiles; only the access must be web-only. Compile the app with dart2js
  (`compilers: [dart2js]` in `dart_test.yaml`, tests guarded with
  `@TestOn('browser && !wasm')`).
* Under the hood it is a jdb database: `JdbFactoryIdb` over an idb_shim
  factory, wrapped in `DatabaseFactoryJdb`, with cross-tab revision
  notifications reused from `sembast_web`. Two consequences: several tabs stay
  in sync, and any `IdbFactory` can back a sembast database. To be really on
  the `dart:html` IndexedDB implementation (not the js_interop one), build the
  factory yourself from `idbFactoryNativeHtml` of `idb_shim_html_compat` - see
  the example below; that is also what this package's own browser test does.
* Testing: the `sembast_test` suites take a `DatabaseTestContextJdb` whose
  `factory` is your factory (`defineTests`, `defineJdbTests`); run them in
  Chrome with dart2js. There is no in-memory variant here: for VM unit tests
  of shared code use `databaseFactoryMemory` from `package:sembast/
  sembast_memory.dart`.
* Anti-patterns: calling `databaseFactoryWeb` on the VM or in a wasm build;
  passing a file path instead of a plain database name; adding this package to
  a project that can use `package:sembast_web` (js_interop, wasm ready,
  `databaseFactoryWebWorker` included); mixing both factories on the same
  database name in the same app.

## Examples

### Open a database and write a record

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast_web_html_compat/sembast_web_html.dart';

Future<void> main() async {
  var store = intMapStoreFactory.store('notes');
  var db = await databaseFactoryWeb.openDatabase('notes.db');

  var key = await store.add(db, {'title': 'first', 'done': false});
  await store.record(key).update(db, {'done': true});

  var records = await store.find(
    db,
    finder: Finder(filter: Filter.equals('done', true)),
  );
  for (var record in records) {
    print('${record.key}: ${record.value}');
  }
  await db.close();
}
```

### A factory really backed by the dart:html IndexedDB implementation

```dart
// ignore_for_file: deprecated_member_use
// Browser only (dart2js): dart:html is not available on the VM or wasm.
import 'package:idb_shim/idb_jdb.dart';
import 'package:idb_shim_html_compat/idb_client_native_html.dart';
import 'package:sembast/sembast.dart';

/// Same storage as [databaseFactoryWeb], but through dart:html.
DatabaseFactory get databaseFactoryWebHtml =>
    DatabaseFactoryJdb(JdbFactoryIdb(idbFactoryNativeHtml));

Future<Database> openHtmlDb() =>
    databaseFactoryWebHtml.openDatabase('legacy.db');
```

### Run the sembast test suites in the browser

```dart
@TestOn('browser && !wasm')
library;

// ignore_for_file: deprecated_member_use
import 'package:idb_shim/idb_jdb.dart';
import 'package:idb_shim_html_compat/idb_client_native_html.dart';
import 'package:sembast_test/all_jdb_test.dart' as all_jdb_test;
import 'package:sembast_test/all_test.dart';
import 'package:sembast_test/jdb_test_common.dart';
import 'package:test/test.dart';

Future<void> main() async {
  var factory = DatabaseFactoryJdb(JdbFactoryIdb(idbFactoryNativeHtml));
  var testContext = DatabaseTestContextJdb()..factory = factory;

  group('idb_native_html', () {
    defineTests(testContext);
    all_jdb_test.defineJdbTests(testContext);
  });
}
```

### Guarding the web-only access in shared code

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast_web_html_compat/sembast_web_html.dart';

/// Falls back to memory when the web factory is not available
/// (VM, wasm): the import itself is always safe.
DatabaseFactory get appDatabaseFactory {
  try {
    return databaseFactoryWeb;
  } on UnimplementedError catch (_) {
    return databaseFactoryMemory;
  }
}
```
