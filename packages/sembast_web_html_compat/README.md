# sembast_web_html_compat

A sembast `databaseFactoryWeb` (IndexedDB, synchronized between tabs) whose
implementation is selected on `dart.library.html` instead of
`dart.library.js_interop`. It exists for legacy apps that still compile with
`dart:html` (dart2js). New code: use
[sembast_web](https://pub.dev/packages/sembast_web), which also runs on wasm.

The storage is the same as sembast_web's (the js_interop IndexedDB of
`idb_shim`, same BroadcastChannel between tabs), not the `dart:html`
IndexedDB of `idb_shim_html_compat` (see the skill to build that one).

## Getting started

Git package, not on pub.dev:

```yaml
dependencies:
  sembast_web_html_compat:
    git:
      url: https://github.com/tekartik/idb_shim_more.dart
      path: packages/sembast_web_html_compat
  sembast: '>=3.10.1'
```

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast_web_html_compat/sembast_web_html.dart';

Future<void> main() async {
  // The "path" is the IndexedDB database name.
  var db = await databaseFactoryWeb.openDatabase('notes.db');
  var store = intMapStoreFactory.store('notes');
  var key = await store.add(db, {'title': 'first'});
  print(await store.record(key).get(db)); // {title: first}
  await db.close();
}
```

## Platforms

| Platform | `databaseFactoryWeb` |
|---|---|
| web, dart2js | IndexedDB |
| web, dart2wasm | throws `UnimplementedError` (no `dart:html`): use sembast_web |
| Dart VM, Flutter native | throws `UnimplementedError`: use sembast io or sembast_sqflite |

Importing the library is safe everywhere; only reading `databaseFactoryWeb`
throws outside dart2js.

## Common pitfalls

* It requires sembast 3.10.1 (changes of another tab seen by listeners after
  a full reload, upgrade retried after another tab wrote).
* Do not open the same database name with sembast_web's factory and this one
  in one app: they do not notify each other inside a tab.
* The library does not re-export sembast: import `package:sembast/sembast.dart`.

Agent skill: [skills/sembast-web-html-compat-setup](skills/sembast-web-html-compat-setup/SKILL.md).
