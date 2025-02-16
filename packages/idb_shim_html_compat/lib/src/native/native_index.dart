// ignore_for_file: public_member_api_docs, deprecated_member_use

import 'dart:async';
import 'dart:indexed_db' as idb;

import 'package:idb_shim/idb.dart';
import 'package:idb_shim_html_compat/src/native/native_cursor.dart';
import 'package:idb_shim_html_compat/src/native/native_error.dart';
import 'package:idb_shim_html_compat/src/native/native_interop.dart';
import 'package:idb_shim_html_compat/src/native/native_key_range.dart';

class IndexNative extends Index {
  idb.Index idbIndex;

  IndexNative(this.idbIndex);

  @override
  Future get(dynamic key) {
    return catchAsyncNativeError(() {
      return idbIndex.get(key);
    });
  }

  @override
  Future getKey(dynamic key) {
    return catchAsyncNativeError(() {
      return idbIndex.getKey(key);
    });
  }

  @override
  Future<int> count([keyOrRange]) {
    Future<int> countFuture;
    return catchAsyncNativeError(() {
      if (keyOrRange == null) {
        countFuture = idbIndex.count();
        /*
            .catchError((e) {
          // as of SDK 1.12 count() without argument crashes
          // so let's count manually
          if (e.toString().contains('DataError')) {
            int count = 0;
            // count manually
            return idbIndex.openKeyCursor(autoAdvance: true).listen((_) {
              count++;
            }).asFuture(count);
          } else {
            throw e;
          }
        });
        */
      } else if (keyOrRange is KeyRange) {
        final idbKeyRange = toNativeKeyRange(keyOrRange);
        countFuture = idbIndex.count(idbKeyRange);
      } else {
        countFuture = idbIndex.count(keyOrRange);
      }
      return countFuture;
    });
  }

  @override
  Stream<Cursor> openKeyCursor(
      {key, KeyRange? range, String? direction, bool? autoAdvance}) {
    final ctlr = CursorControllerNative(idbIndex.openKeyCursor(
        key: key,
        range: range == null ? null : toNativeKeyRange(range),
        direction: direction,
        autoAdvance: autoAdvance));
    return ctlr.stream;
  }

  /// Same implementation than for the Store
  @override
  Stream<CursorWithValue> openCursor(
      {key, KeyRange? range, String? direction, bool? autoAdvance}) {
    final ctlr = CursorWithValueControllerNative(idbIndex.openCursor(
        key: key,
        range: range == null ? null : toNativeKeyRange(range),
        direction: direction,
        autoAdvance: autoAdvance));

    return ctlr.stream;
  }

  @override
  Future<List<Object>> getAll([Object? query, int? count]) {
    return catchAsyncNativeError(() {
      final nativeQuery = toNativeQuery(query);
      var results = indexGetAll(idbIndex, nativeQuery, count);
      return results;
    });
  }

  @override
  Future<List<Object>> getAllKeys([Object? query, int? count]) {
    return catchAsyncNativeError(() {
      final nativeQuery = toNativeQuery(query);
      var results = indexGetAllKeys(idbIndex, nativeQuery, count);
      return results;
    });
  }

  @override
  Object get keyPath => idbIndex.keyPath as Object;

  @override
  bool get unique => idbIndex.unique!;

  @override
  bool get multiEntry => idbIndex.multiEntry!;

  @override
  int get hashCode => idbIndex.hashCode;

  @override
  String get name => idbIndex.name!;

  @override
  bool operator ==(other) {
    if (other is IndexNative) {
      return idbIndex == other.idbIndex;
    }
    return false;
  }
}
