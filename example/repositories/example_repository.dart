import 'package:db_client/db_client.dart';

import 'utils.dart';

/// Example repository demonstrating the DbClient pattern.
///
/// This pattern allows you to:
/// - Define database configuration once (loaded from .env)
/// - Use lazy initialization for the connection
/// - Execute queries through a clean API
class ExampleRepository {
  static DbClient? _client;
  static DbClientConfig? _config;

  /// Gets the database configuration from .env file
  static DbClientConfig get _dbConfig {
    if (_config != null) return _config!;

    final env = loadDotEnv('.env');
    _config = DbClientConfig(
      server: env['SERVER'] ?? 'localhost',
      database: env['DATABASE'],
      username: env['USERNAME'],
      password: env['PASSWORD'],
      driver: env['DRIVER'] ?? 'ODBC Driver 17 for SQL Server',
    );
    return _config!;
  }

  /// Lazy initialization of the DbClient
  /// Db client instance
  static DbClient get _db {
    _client ??= SqlDbClient(_dbConfig);
    return _client!;
  }

  /// Gets the current database name.
  static Future<String> getDatabaseName() async {
    final response = await _db.send(
      DbRequest.query(
        'SELECT DB_NAME() AS database_name',
        errorMessage: 'Failed to get database name',
      ),
    );

    if (!response.success) {
      throw Exception(response.error);
    }

    return response.firstOrNull?['database_name'] as String? ?? 'Unknown';
  }

  /// Gets the SQL Server version.
  static Future<String> getVersion() async {
    final response = await _db.send(
      DbRequest.query(
        'SELECT @@VERSION AS version',
        errorMessage: 'Failed to get SQL Server version',
      ),
    );

    if (!response.success) {
      throw Exception(response.error);
    }

    return response.firstOrNull?['version'] as String? ?? 'Unknown';
  }

  /// Gets all tables from the current database.
  static Future<List<Map<String, dynamic>>> getTables() async {
    final response = await _db.send(
      DbRequest.query(
        '''
        SELECT 
          TABLE_SCHEMA as [schema],
          TABLE_NAME as [name],
          TABLE_TYPE as [type]
        FROM INFORMATION_SCHEMA.TABLES
        ORDER BY TABLE_SCHEMA, TABLE_NAME
        ''',
        errorMessage: 'Failed to fetch tables',
      ),
    );

    if (!response.success) {
      throw Exception(response.error);
    }

    return response.rows;
  }

  /// Gets a table by name.
  static Future<Map<String, dynamic>?> getTableByName(String tableName) async {
    final response = await _db.send(
      DbRequest.query(
        '''
        SELECT 
          TABLE_SCHEMA as [schema],
          TABLE_NAME as [name],
          TABLE_TYPE as [type]
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_NAME = ?
        ''',
        params: [tableName],
        errorMessage: 'Failed to fetch table',
      ),
    );

    if (!response.success) {
      throw Exception(response.error);
    }

    return response.firstOrNull;
  }

  /// Counts records in a table.
  static Future<int> countRecords(String tableName) async {
    final response = await _db.send(
      DbRequest.query(
        'SELECT COUNT(*) AS cnt FROM [$tableName]',
        errorMessage: 'Failed to count records',
      ),
    );

    if (!response.success) {
      throw Exception(response.error);
    }

    return response.scalar<int>() ?? 0;
  }

  /// Closes the database connection.
  static Future<void> close() async {
    await _client?.close();
    _client = null;
  }
}
