import 'package:db_client/src/core/db_client_config.dart';
import 'package:db_client/src/core/db_client_interface.dart';
import 'package:db_client/src/core/db_request.dart';
import 'package:db_client/src/core/db_response.dart';
import 'package:db_client/src/odbc/odbc.dart';

/// SQL Server database client implementation using ODBC.
///
/// Example:
/// ```dart
/// final config = DbClientConfig(
///   server: 'localhost',
///   database: 'MyDatabase',
///   username: 'sa',
///   password: 'password',
/// );
///
/// final client = SqlDbClient(config);
///
/// final response = await client.send(
///   DbRequest.query('SELECT * FROM Users'),
/// );
///
/// if (response.success) {
///   for (final row in response.rows) {
///     print(row);
///   }
/// }
///
/// await client.close();
/// ```
class SqlDbClient implements DbClient {
  /// Creates a new SQL database client with the given configuration.
  SqlDbClient(this._config);

  final DbClientConfig _config;
  Odbc? _odbc;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  /// Ensures the client is connected to the database.
  ///
  /// Creates a new connection if not already connected.
  Future<void> _ensureConnected() async {
    if (_connected && _odbc != null) return;

    _odbc = Odbc();
    await _odbc!.connectWithConnectionString(_config.connectionString);
    _connected = true;
  }

  @override
  Future<DbResponse> send(DbRequest request) async {
    try {
      await _ensureConnected();

      final rows = await _odbc!.execute(
        request.query,
        params: request.params,
        columnConfig: request.columnConfig,
      );

      return DbResponse.ok(rows);
    } catch (e) {
      return DbResponse.fail('${request.errorMessage}: $e');
    }
  }

  @override
  Future<void> close() async {
    if (_connected && _odbc != null) {
      await _odbc!.disconnect();
      _connected = false;
      // ✅ v0.2.1 FIX (Option A): Do NOT set _odbc to null
      // Setting to null triggers GC which may try to free ODBC resources,
      // causing heap corruption. Keep the reference until process exit.
      // _odbc = null;
    }
  }
}
