import 'dart:async';
// ignore: deprecated_member_use

import 'package:idb_shim/idb_client_native_interop.dart';
import 'package:idb_shim/idb_jdb.dart';
// ignore: implementation_imports
import 'package:sembast_web/src/web_interop.dart'
    show addNotificationRevision, notificationRevisionStream;
// ignore: implementation_imports
import 'package:idb_shim/src/jdb/web_defs.dart' show NotificationRevision;

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
      // null when the database is not open in this tab (another tab wrote
      // another database), as sembast_web (sembast.dart#408).
      var list = databases[notificationRevision.name];
      if (list != null) {
        for (var jdbDatabase in list) {
          jdbDatabase.addRevision(notificationRevision.revision);
        }
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
