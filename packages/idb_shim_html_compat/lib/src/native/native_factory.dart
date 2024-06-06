// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:html' as html;
import 'dart:indexed_db' as idb;
import 'dart:indexed_db' as native;

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/common/common_factory.dart';
import 'package:idb_shim/src/common/common_import.dart';
import 'package:idb_shim/src/utils/env_utils.dart';
import 'package:idb_shim/src/utils/value_utils.dart';
import 'package:idb_shim_html_compat/src/native/native_database.dart';
import 'package:idb_shim_html_compat/src/native/native_error.dart';
import 'package:idb_shim_html_compat/src/native/native_event.dart';

import 'browser_utils_html.dart';

IdbFactory? _idbFactoryNativeBrowserImpl;

IdbFactory get idbFactoryNativeBrowserImpl =>
    _idbFactoryNativeBrowserImpl ??= () {
      return nativeIdbFactoryBrowserWrapperImpl;
    }();

native.IdbFactory? get nativeBrowserIdbFactory => html.window.indexedDB;

// Single instance
IdbFactoryNativeBrowserWrapperImpl? _nativeIdbFactoryBrowserWrapperImpl;

IdbFactoryNativeBrowserWrapperImpl get nativeIdbFactoryBrowserWrapperImpl =>
    _nativeIdbFactoryBrowserWrapperImpl ??=
        IdbFactoryNativeBrowserWrapperImpl._();

/// Browser only
class IdbFactoryNativeBrowserWrapperImpl extends IdbFactoryNativeWrapperImpl {
  IdbFactoryNativeBrowserWrapperImpl._() : super(nativeBrowserIdbFactory!);

  static bool get supported {
    return idb.IdbFactory.supported;
  }
}

/// Wrapper for window.indexedDB and worker self.indexedDB
class IdbFactoryNativeWrapperImpl extends IdbFactoryBase {
  final native.IdbFactory nativeFactory;

  @override
  bool get persistent => true;

  IdbFactoryNativeWrapperImpl(this.nativeFactory);

  @override
  String get name => idbFactoryNameNative;

  @override
  Future<Database> open(String dbName,
      {int? version,
      OnUpgradeNeededFunction? onUpgradeNeeded,
      OnBlockedFunction? onBlocked}) {
    FutureOr? onUpdateNeededFutureOr;
    Object? onUpdateNeededException;
    void openOnUpgradeNeeded(idb.VersionChangeEvent e) {
      final event = VersionChangeEventNative(this, e);

      try {
        onUpdateNeededFutureOr = onUpgradeNeeded!(event);
      } catch (e) {
        onUpdateNeededException = e;
      }
    }

    void openOnBlocked(html.Event e) {
      if (onBlocked != null) {
        Event event = EventNative(e);
        onBlocked(event);
      } else {
        idbLog('blocked opening $dbName v $version');
      }
    }

    return nativeFactory
        .open(dbName,
            version: version,
            onUpgradeNeeded:
                onUpgradeNeeded == null ? null : openOnUpgradeNeeded,
            onBlocked: onBlocked == null && onUpgradeNeeded == null
                ? null
                : openOnBlocked)
        .then((idb.Database database) async {
      // Handle exception in onUpgradeNeeded
      if (onUpdateNeededFutureOr is Future && onUpdateNeededException == null) {
        try {
          await onUpdateNeededFutureOr;
        } catch (e) {
          onUpdateNeededException = e;
        }
      }
      if (onUpdateNeededException != null) {
        database.close();
        throw onUpdateNeededException!;
      }

      return DatabaseNative(this, database);
    });
  }

  @override
  Future<IdbFactory> deleteDatabase(String dbName,
      {OnBlockedFunction? onBlocked}) {
    void openOnBlocked(html.Event e) {
      if (isDebug) {
        idbLog('blocked deleting $dbName');
      }
      Event event = EventNative(e);
      onBlocked!(event);
    }

    return nativeFactory
        .deleteDatabase(dbName,
            onBlocked: onBlocked == null ? null : openOnBlocked)
        .then((_) {
      return this;
    });
  }

  @override
  bool get supportsDatabaseNames {
    // No longer supported on modern browsers. Always returns false
    return false;
  }

  @override
  Future<List<String>> getDatabaseNames() {
    // ignore: undefined_method
    throw DatabaseException('getDatabaseNames not supported');
  }

  @override
  int cmp(Object first, Object second) {
    return catchNativeError(() {
      if (first is List && (isIe || isEdge)) {
        return greaterThan(first, second)
            ? 1
            : (lessThan(first, second) ? -1 : 0);
      } else {
        return nativeFactory.cmp(first, second);
      }
    })!;
  }

  @override
  bool get supportsDoubleKey => false;
}
