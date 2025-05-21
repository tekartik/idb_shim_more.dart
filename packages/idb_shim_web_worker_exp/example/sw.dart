import 'dart:async';
import 'dart:js_interop';

import 'package:idb_shim/idb_client_native.dart';
import 'package:web/web.dart' as web;

/// Counter simple test
const commandVarSet = 'varSet';
// key: value: integer
/// Counter simple test
const commandVarGet = 'varGet';

final scope = (globalContext as web.DedicatedWorkerGlobalScope);

final _store = 'values';
var _database = () async {
  final factory = idbFactoryWebWorker;
  // equivalent to: factory = idbFactoryFromIndexedDB(scope.indexedDB);
  return factory.open(
    'idb_shim_web_worker_exp_db',
    version: 1,
    onUpgradeNeeded: (VersionChangeEvent e) {
      var db = e.database;
      db.createObjectStore(_store);
    },
  );
}();
void _handleMessageEvent(web.Event event) async {
  var messageEvent = event as web.MessageEvent;
  var rawData = messageEvent.data.dartify();
  print('sw rawData $rawData');
  try {
    var jsPorts = messageEvent.ports;
    var ports = jsPorts.toDart;
    var port = ports.first;

    if (rawData is List) {
      var command = rawData[0];

      if (command == commandVarSet) {
        var data = rawData[1] as Map;
        var key = data['key'] as String;
        var value = data['value'] as int?;
        var db = await _database;
        var store = db
            .transaction(_store, idbModeReadWrite)
            .objectStore(_store);
        if (value != null) {
          await store.put(value, key);
        } else {
          await store.delete(key);
        }
        port.postMessage(null);
      } else if (command == commandVarGet) {
        var data = rawData[1] as Map;
        var key = data['key'] as String;
        var db = await _database;
        var store = db.transaction(_store, idbModeReadOnly).objectStore(_store);
        var value = await store.getObject(key);
        port.postMessage(
          {
            'result': {'key': key, 'value': value},
          }.jsify(),
        );
      } else {
        print('$command unknown');
        port.postMessage(null);
      }
    } else {
      print('rawData $rawData unknown');
      port.postMessage(null);
    }
  } catch (e) {
    print('error $e');
  }
}

void main(List<String> args) {
  var zone = Zone.current;

  print('Web worker started 1');

  /// Handle basic web workers
  /// dirty hack
  try {
    scope.onmessage =
        (web.MessageEvent event) {
          zone.run(() {
            _handleMessageEvent(event);
          });
        }.toJS;
  } catch (e) {
    print('onmessage error $e');
  }
}
