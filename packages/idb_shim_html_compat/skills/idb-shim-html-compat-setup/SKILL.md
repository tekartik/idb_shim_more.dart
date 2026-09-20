---
name: idb-shim-html-compat-setup
description: >-
  Use when an existing web app must keep using dart:html / dart:indexed_db for
  IndexedDB behind the idb_shim API: package:idb_shim_html_compat/
  idb_client_native_html.dart, idbFactoryNativeHtml, idbFactoryNativeSupported,
  idbFactoryFromIndexedDB(window.indexedDB or self.indexedDB), the deprecated
  idbFactoryNative alias, why it is dart2js only (no wasm), and how to migrate
  to the wasm-ready idb_shim web factory (idbFactoryWeb / idb_client_native).
---

# Legacy dart:html IndexedDB factory (idb_shim_html_compat)

`idb_shim_html_compat` is the pre-`package:web` implementation of `idb_shim`'s
`IdbFactory`, built on `dart:html` and `dart:indexed_db`. Its only library is
annotated `@Deprecated('Use idb_shim_web instead')`: keep it for apps still on
`dart:html`, and use `package:idb_shim/idb_client_native.dart`
(`idbFactoryWeb`, js_interop, wasm ready) for anything new.

## Guidelines

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    idb_shim_html_compat:
      git:
        url: https://github.com/tekartik/idb_shim_more.dart
        path: packages/idb_shim_html_compat
      version: '>=0.3.3'
  ```
  It depends on `idb_shim` itself, which stays the API you code against.
* The single public library is
  `package:idb_shim_html_compat/idb_client_native_html.dart`, exporting four
  names:
  * `idbFactoryNativeHtml` - the `IdbFactory` wrapping `window.indexedDB`.
  * `idbFactoryNativeSupported` - `false` when the browser has no IndexedDB;
    check it before touching the factory.
  * `idbFactoryFromIndexedDB(nativeIdbFactory)` - wraps an explicit native
    factory, e.g. `window.indexedDB!` or a service worker's `self.indexedDB`.
  * `idbFactoryNative` - deprecated alias of `idbFactoryNativeHtml`; prefer
    the explicit name.
  It does not re-export `idb_shim`, so add
  `import 'package:idb_shim/idb_shim.dart';` (or `idb_browser.dart`) for
  `IdbFactory`, `Database`, `VersionChangeEvent`, `idbModeReadWrite`...
* Everything after `open()` is plain `idb_shim`: the same `Database`,
  `Transaction`, `ObjectStore`, `Index`, `KeyRange` and cursors as any other
  factory (see the `idb-shim-database` and `idb-shim-sdb` skills of
  `idb_shim`). Only the factory selection is specific to this package.
* Platform: the library is a conditional export
  (`dart.library.html`). Importing it compiles everywhere, but off the web
  every getter throws (an unimplemented stub) - a VM test can only check that
  it compiles. Because `dart:html` has no wasm support, browser code using it
  must be compiled with dart2js: declare `compilers: [dart2js]` in
  `dart_test.yaml` and guard test files with `@TestOn('browser && !wasm')`.
* Databases are interoperable with the modern factory: a database created with
  `idbFactoryNativeHtml` opens unchanged with `idbFactoryWeb` /
  `idbFactoryNative` from `package:idb_shim/idb_client_native.dart`, values
  included (`DateTime`, `Uint8List`...). Migrating is a one-line factory swap
  plus dropping `dart:html` from the app; no data migration.
* Testing: build a `TestContext()..factory = idbFactoryNativeHtml` and feed it
  to the `idb_test` suites (`defineAllTests`, or a single suite such as
  `object_store_test.dart`); always inside an `idbFactoryNativeSupported`
  guard so an unsupported browser skips rather than fails.
* Anti-patterns: compiling to wasm (`dart compile wasm`, `-c dart2wasm`) with
  this package in the graph; accessing `idbFactoryNativeHtml` from VM/Flutter
  code; using `dart:indexed_db` objects directly instead of the returned
  `IdbFactory`; adding this package to a new project.

## Examples

### Open a database in a dart:html web app

```dart
import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim_html_compat/idb_client_native_html.dart';

const todoStore = 'todos';

Future<Database?> openTodoDb() async {
  if (!idbFactoryNativeSupported) {
    return null; // no IndexedDB in this browser
  }
  return idbFactoryNativeHtml.open(
    'com.example.todo',
    version: 1,
    onUpgradeNeeded: (VersionChangeEvent e) {
      e.database.createObjectStore(todoStore, autoIncrement: true);
    },
  );
}

Future<int> addTodo(Database db, String text) async {
  var txn = db.transaction(todoStore, idbModeReadWrite);
  var key = await txn.objectStore(todoStore).add({'text': text}) as int;
  await txn.completed;
  return key;
}
```

### Wrap an explicit native factory (window or service worker)

```dart
// ignore_for_file: deprecated_member_use
// Browser only (dart2js), this file must not be compiled for the VM or wasm.
library;

import 'dart:html' as html;

import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim_html_compat/idb_client_native_html.dart';

/// In a service worker, pass `self.indexedDB` instead.
IdbFactory windowIdbFactory() =>
    idbFactoryFromIndexedDB(html.window.indexedDB!);
```

### Run the shared idb_test suite on this factory

```dart
@TestOn('browser && !wasm')
library;

import 'package:idb_shim_html_compat/idb_client_native_html.dart';
import 'package:idb_test/idb_test_common.dart';
import 'package:idb_test/test_runner.dart';

void main() {
  group('native_html', () {
    if (idbFactoryNativeSupported) {
      var ctx = TestContext()..factory = idbFactoryNativeHtml;
      test('persistent', () {
        expect(ctx.factory.persistent, isTrue);
      });
      defineAllTests(ctx);
    } else {
      test('supported', () {}, skip: 'idb native html not supported');
    }
  });
}
```

### Check that non-web code still compiles

```dart
import 'package:idb_shim_html_compat/idb_client_native_html.dart';
import 'package:test/test.dart';

void main() {
  test('compile on io', () {
    try {
      idbFactoryNativeHtml; // throws off the web, but links fine
    } catch (_) {}
  });
}
```

### Migrating away

```dart
// Before (dart:html, dart2js only)
// import 'package:idb_shim_html_compat/idb_client_native_html.dart';
// var factory = idbFactoryNativeHtml;

// After (package:web + js_interop, dart2js and wasm)
import 'package:idb_shim/idb_client_native.dart';

final factory = idbFactoryWeb; // same IdbFactory API, same databases
```
