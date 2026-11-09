@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../example/sw.dart';

/// Sends [data] to the worker handler (run in the page) and returns the
/// response posted on the message port.
Future<Object?> send(Object data) async {
  var channel = web.MessageChannel();
  var completer = Completer<Object?>();
  channel.port1.onmessage = (web.MessageEvent event) {
    completer.complete(event.data.dartify());
  }.toJS;
  await handleMessageEvent(
    web.MessageEvent(
      'message',
      web.MessageEventInit(data: data.jsify(), ports: [channel.port2].toJS),
    ),
  );
  return completer.future.timeout(const Duration(seconds: 10));
}

void main() {
  test('an error is answered', () async {
    // The worker printed the error and never answered: the page waited
    // forever (review of 2026-11-09).
    var response = await send([
      commandVarSet,
      {'key': 1},
    ]);
    expect((response as Map)['error'], isNotNull);
  });
  test('set and get', () async {
    await send([
      commandVarSet,
      {'key': 'sw_handler_test', 'value': 1},
    ]);
    var response = await send([
      commandVarGet,
      {'key': 'sw_handler_test'},
    ]);
    expect(((response as Map)['result'] as Map)['value'], 1);
  }, testOn: '!wasm');
}
