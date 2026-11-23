@TestOn('vm')
library;

import 'package:tekartik_common_build/headless_chrome.dart';
import 'package:tekartik_common_build/web_run.dart';
import 'package:test/test.dart';

import '../example/sdb_demo.dart' as demo;

/// Why the browser runs are skipped, null when Chrome is found.
String? get _noChrome {
  try {
    findChromeExecutable();
    return null;
  } on StateError catch (e) {
    return e.message;
  }
}

void main() {
  test('the demo on the VM (sembast in memory)', () async {
    await demo.main();
  });

  for (var compiler in WebRunCompiler.values) {
    test(
      'the demo in Chrome (${compiler.name}, sembast_web in IndexedDB)',
      () async {
        var out = <String>[];
        await webRun(
          'example/sdb_demo.dart',
          compiler: compiler,
          onOut: out.add,
        );
        expect(out, [
          'factory: sembast_web (IndexedDB)',
          'note 1: {title: Hello}',
          '2 notes',
        ]);
      },
      skip: _noChrome,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
