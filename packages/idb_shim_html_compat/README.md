# idb_shim_html_compat

Legacy [idb_shim](https://pub.dev/packages/idb_shim) `IdbFactory` for the
browser built on `dart:html` and `dart:indexed_db`, for web apps that still
use `dart:html`.

For a new project use `idbFactoryWeb` of `package:idb_shim/idb_shim.dart`
(js_interop, dart2js and wasm) instead: it opens the same databases.

## Getting started

Add the git dependency (not on pub.dev), next to `idb_shim`:

```yaml
dependencies:
  idb_shim: ^2.11.3
  idb_shim_html_compat:
    git:
      url: https://github.com/tekartik/idb_shim_more.dart
      path: packages/idb_shim_html_compat
```

Open a database with `idbFactoryNativeHtml`, then use the `idb_shim` API:

```dart
// ignore_for_file: deprecated_member_use
import 'package:idb_shim/idb_shim.dart';
import 'package:idb_shim_html_compat/idb_client_native_html.dart';

Future<Database?> openTodoDb() async {
  if (!idbFactoryNativeSupported) {
    return null; // no IndexedDB in this browser
  }
  return idbFactoryNativeHtml.open(
    'todo.db',
    version: 1,
    onUpgradeNeeded: (VersionChangeEvent e) {
      e.database.createObjectStore('todos', autoIncrement: true);
    },
  );
}
```

The library is deprecated on purpose (a reminder to migrate): add the
`ignore_for_file: deprecated_member_use` line.

## Platforms

- Browser, compiled with dart2js only: `dart:html` has no wasm support. In
  tests, use `@TestOn('browser && !wasm')` and `compilers: [dart2js]`.
- Elsewhere (VM, Flutter native, wasm), the import compiles but every getter
  throws: use another `idb_shim` factory there.

## API

`package:idb_shim_html_compat/idb_client_native_html.dart` exports:

- `idbFactoryNativeHtml`: the factory of `window.indexedDB`.
- `idbFactoryNativeSupported`: `false` when the browser has no IndexedDB.
- `idbFactoryFromIndexedDB(nativeFactory)`: wraps another `dart:indexed_db`
  factory (for example in a worker).
- `idbFactoryNative`: deprecated alias of `idbFactoryNativeHtml`.

Everything after `open()` is the `idb_shim` API (`Database`, `Transaction`,
`ObjectStore`, `Index`, cursors). As in `idb_shim`, an `onUpgradeNeeded` that
throws (or whose future fails) aborts the upgrade: the database keeps its
previous version and `open()` throws that error.

## Migrating

```dart
import 'package:idb_shim/idb_shim.dart';

final factory = idbFactoryWeb; // same IdbFactory API, same databases
```

Replace `idbFactoryNativeHtml` by `idbFactoryWeb` and drop `dart:html` from
the app: the databases need no migration.

See [example/web](example/web) for a small todo app.
