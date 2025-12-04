import 'package:db_client/src/odbc/helper.dart';

/// Represents a database request to be executed.
class DbRequest {
  /// Creates a new database request.
  ///
  /// [query] is the SQL query or stored procedure name.
  /// [params] are optional parameters for parameterized queries.
  /// [columnConfig] allows configuring column types for special data handling.
  /// [errorMessage] is a custom error message for failures.
  const DbRequest({
    required this.query,
    this.params,
    this.columnConfig = const {},
    this.errorMessage = 'Database error',
  });

  /// Creates a SELECT query request.
  ///
  /// Example:
  /// ```dart
  /// DbRequest.query(
  ///   'SELECT * FROM Users WHERE Id = ?',
  ///   params: [userId],
  /// )
  /// ```
  factory DbRequest.query(
    String sql, {
    List<dynamic>? params,
    Map<String, ColumnType> columnConfig = const {},
    String errorMessage = 'Query failed',
  }) {
    return DbRequest(
      query: sql,
      params: params,
      columnConfig: columnConfig,
      errorMessage: errorMessage,
    );
  }

  /// Creates an INSERT, UPDATE, or DELETE request.
  ///
  /// Example:
  /// ```dart
  /// DbRequest.execute(
  ///   'INSERT INTO Users (Name, Email) VALUES (?, ?)',
  ///   params: ['John', 'john@example.com'],
  /// )
  /// ```
  factory DbRequest.execute(
    String sql, {
    List<dynamic>? params,
    String errorMessage = 'Execute failed',
  }) {
    return DbRequest(
      query: sql,
      params: params,
      errorMessage: errorMessage,
    );
  }

  /// Creates a stored procedure call request.
  ///
  /// Automatically prepends 'EXEC ' to the procedure name.
  ///
  /// Example:
  /// ```dart
  /// DbRequest.storedProcedure(
  ///   'sp_GetUserById',
  ///   params: [userId],
  /// )
  /// ```
  factory DbRequest.storedProcedure(
    String name, {
    List<dynamic>? params,
    Map<String, ColumnType> columnConfig = const {},
    String errorMessage = 'Stored procedure failed',
  }) {
    return DbRequest(
      query: 'EXEC $name',
      params: params,
      columnConfig: columnConfig,
      errorMessage: errorMessage,
    );
  }

  /// The SQL query or command to execute.
  final String query;

  /// Parameters for parameterized queries.
  final List<dynamic>? params;

  /// Column configuration for special data types.
  final Map<String, ColumnType> columnConfig;

  /// Custom error message for this request.
  final String errorMessage;
}
