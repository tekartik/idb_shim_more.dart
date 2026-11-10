@TestOn('browser && !wasm')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:sembast/sembast.dart';
import 'package:sembast_web_html_compat/sembast_web_html.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

/// The channel sembast_web (and this package) use between tabs.
const _channelName = 'sembast_web_storage_revision';

void main() {
  group('revision notification', () {
    test('another tab writes a database not open here', () async {
      var db = await databaseFactoryWeb.openDatabase(
        'html_compat_revision_open.db',
      );
      var store = StoreRef<int, String>.main();
      await store.record(1).put(db, 'a');

      // What another tab writing another database sends. A channel does not
      // receive its own messages, so the observer tells when the message
      // reached the channels of this page.
      var sender = web.BroadcastChannel(_channelName);
      var observer = web.BroadcastChannel(_channelName);
      var received = Completer<void>();
      observer.onmessage = (web.MessageEvent _) {
        if (!received.isCompleted) {
          received.complete();
        }
      }.toJS;
      try {
        sender.postMessage(
          <JSAny?>['html_compat_revision_other_tab.db'.toJS, 3.toJS].toJS,
        );
        await received.future.timeout(const Duration(seconds: 5));
        // Let the factory listener run (an error there fails the test).
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(await store.record(1).get(db), 'a');
      } finally {
        sender.close();
        observer.close();
        await db.close();
      }
    }, timeout: const Timeout(Duration(seconds: 20)));
  });
}
