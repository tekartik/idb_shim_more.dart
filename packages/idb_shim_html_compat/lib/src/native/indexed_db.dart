// ignore: deprecated_member_use
import 'dart:async';
// ignore: deprecated_member_use
import 'dart:indexed_db' as idb;
// ignore: deprecated_member_use

import 'package:idb_shim/idb.dart';

/// IDB request helper
extension IDBRequestExt on idb.Request {
  /// On error helper.
  void handleOnError(Completer<Object?> completer) {
    onError.listen((Object error) {
      if (!completer.isCompleted) {
        completer.completeError(DatabaseError(error.toString()));
      }
    });
  }

  /// On success helper.
  void handleOnSuccess(Completer<Object?> completer) {
    onSuccess.listen((_) {
      var result = this.result as Object?;
      completer.complete(result);
    });
  }

  /// On success and error helper.
  void handleOnSuccessAndError(Completer<Object?> completer) {
    handleOnSuccess(completer);
    handleOnError(completer);
  }

  /// Future result
  Future<Object?> get future {
    var completer = Completer<Object?>.sync();
    handleOnSuccessAndError(completer);
    return completer.future;
  }
}
