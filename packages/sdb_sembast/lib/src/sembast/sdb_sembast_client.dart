import 'package:sembast/sembast.dart' as sembast;

/// Sembast client, the database or a transaction.
abstract class SdbClientSembast {
  /// The sembast client to use, the database itself or the transaction.
  sembast.DatabaseClient get sembastDatabaseClient;
}
