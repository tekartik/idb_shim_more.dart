import 'dart:async';
// ignore: deprecated_member_use

import 'package:idb_shim/idb_client_native_html.dart';
// ignore: implementation_imports
import 'package:sembast_web/src/jdb_factory_idb.dart';
// ignore: implementation_imports
import 'package:sembast_web/src/jdb_import.dart';
// ignore: implementation_imports
import 'package:sembast_web/src/web_defs.dart';
// ignore: implementation_imports
import 'package:sembast_web/src/web_interop.dart'
    show addNotificationRevision, notificationRevisionStream;

/// The native jdb factory
var jdbFactoryIdbNative = JdbFactoryWeb();

/// The sembast idb native factory with web.
var databaseFactoryWeb = DatabaseFactoryWeb();

/// Web jdb factory.
class JdbFactoryWeb extends JdbFactoryIdb {
  /// Web jdb factory.
  // ignore: deprecated_member_use
  JdbFactoryWeb() : super(idbFactoryNative);

  StreamSubscription? _revisionSubscription;

  @override
  void start() {
    stop();
    _revisionSubscription = notificationRevisionStream.listen((
      notificationRevision,
    ) {
      var list = databases[notificationRevision.name]!;
      for (var jdbDatabase in list) {
        jdbDatabase.addRevision(notificationRevision.revision);
      }
    });
  }

  @override
  void stop() {
    _revisionSubscription?.cancel();
    _revisionSubscription = null;
  }

  /// Notify other app (web only))
  @override
  void notifyRevision(NotificationRevision notificationRevision) {
    addNotificationRevision(notificationRevision);
  }
}

/// Web factory.
class DatabaseFactoryWeb extends DatabaseFactoryJdb {
  /// Web factory.
  DatabaseFactoryWeb() : super(jdbFactoryIdbNative);
}
