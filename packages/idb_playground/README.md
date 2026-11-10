# Playground for idb_shim

Dev menus (tekartik_app_dev_menu) to try idb_shim and its sdb layer by hand
on each factory: downgrade errors, `openOnDowngradeDelete`, a small notes
database (cv records on sdb: add, count, list, bulk create); plus the idb
test suite run on sembast over idb over sembast (`test/idb_deep_*`).

## Run

From this folder (a package of the repository workspace):

```sh
dart run bin/main_memory.dart     # idb in memory
dart run bin/main_io.dart         # idb on sembast io, .local/sembast_io_playground/
dart run bin/main_sqflite.dart    # idb on sqflite (ffi), .local/sqflite_playground/
dart run bin/main.dart            # the three above in one menu
dart pub global run webdev serve web:8080   # the browser IndexedDB
dart test                         # the deep idb suites and the sdb schema tests
```

Console: type the number of an entry, `.` goes back (and exits from the top
menu), `?` shows the menu again. Arguments are typed first:
`dart run bin/main_memory.dart 0 2 . .` runs "openOnDowngradeDelete
downgrade" and exits. An item that prompts takes its answer from the next
argument (with dev_build 1.2.2 the arguments after that answer do not wait
for the item to end: end the arguments with the answer).

`test/*_test_manual.dart` are stress runs (up to 100000 notes), never run by
`dart test`: run one file at a time, `dart test test/sdb_stress_test_manual.dart`.

## Use the menus elsewhere

```yaml
dependencies:
  tekartik_idb_playground:
    git:
      url: https://github.com/tekartik/idb_shim_more.dart
      path: packages/idb_playground
```

`idbPlaygroundMenu(idbFactory, path: ...)` (lib/idb_playground_menu.dart) and
`sdbPlaygroundMenu(sdbFactory, path: ...)` (lib/sdb_playground_menu.dart)
declare the menus inside your `mainMenu`.
