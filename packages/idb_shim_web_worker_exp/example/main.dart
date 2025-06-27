import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'sw.dart';
import 'ui.dart';

/*
Future incrementNoWebWorker() async {
  await incrementSqfliteValueInDatabaseFactory(
      databaseFactoryWebNoWebWorkerLocal,
      tag: 'ui');
}
*/
Future<void> main() async {
  // sqliteFfiWebDebugWebWorker = true;
  initUi();

  //write('$_shc running $_debugVersion');
  // devWarning(incrementVarInSharedWorker());
  // await devWarning(bigInt());
  // await devWarning(exceptionWork());
  // await devWarning(incrementWork());
  // await devWarning(incrementPrebuilt());
  await incrementVarInWorker();
  // await incrementSqfliteValueInDatabaseFactory(
  // databaseFactoryWebNoWebWorkerLocal);
  // await incrementSqfliteValueInDatabaseFactory(databaseFactoryWebLocal);
  // await devWarning(
  //  incrementSqfliteValueInDatabaseFactory(databaseFactoryWebPrebuilt));
}

var sharedWorkerUri = Uri.parse('sw.dart.js');
late web.Worker worker;
var _webContextRegisterAndReady = () async {
  worker = web.Worker(sharedWorkerUri.toString().toJS);
}();

var key = 'testValue';

/// Returns response
Future<Object?> sendRawMessage(Object message) {
  var completer = Completer<Object?>();
  // This wraps the message posting/response in a promise, which will resolve if the response doesn't
  // contain an error, and reject with the error if it does. If you'd prefer, it's possible to call
  // controller.postMessage() and set up the onmessage handler independently of a promise, but this is
  // a convenient wrapper.
  var messageChannel = web.MessageChannel();
  //var receivePort =ReceivePort();

  final zone = Zone.current;
  messageChannel.port1.onmessage = (web.MessageEvent event) {
    zone.run(() {
      var data = event.data.dartify();

      completer.complete(data);
    });
  }.toJS;

  // This sends the message data as well as transferring messageChannel.port2 to the worker.
  // The worker can then use the transferred port to reply via postMessage(), which
  // will in turn trigger the onmessage handler on messageChannel.port1.
  // See https://html.spec.whatwg.org/multipage/workers.html#dom-worker-postmessage
  print('posting $message response ${messageChannel.port2}');
  worker.postMessage(
    message.jsify(),
    messagePortToPortMessageOption(messageChannel.port2),
  );
  return completer.future;
}

/// message port parameter
JSObject messagePortToPortMessageOption(web.MessagePort messagePort) {
  return [messagePort].toJS;
}

Future<int?> getTestValue() async {
  var response =
      await sendRawMessage([
            commandVarGet,
            {'key': key},
          ])
          as Map;
  return (response['result'] as Map)['value'] as int?;
}

Future<void> setTestValue(int? value) async {
  await sendRawMessage([
    commandVarSet,
    {'key': key, 'value': value},
  ]);
}

Future<void> incrementVarInWorker() async {
  await _webContextRegisterAndReady;
  write('shared worker ready');
  var value = await getTestValue();
  write('var before $value');
  if (value is! int) {
    value = 0;
  }

  await setTestValue(value + 1);
  value = await getTestValue();
  write('var after $value');
}

void initUi() {
  addButton('increment var worker', () async {
    await incrementVarInWorker();
  });
}
