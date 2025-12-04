import 'package:db_client/src/core/db_request.dart';
import 'package:db_client/src/core/db_response.dart';

/// Abstract interface for database clients.
///
/// Implementations of this interface handle the connection and communication
/// with different database systems via ODBC.
abstract interface class DbClient {
  /// Sends a database request and returns the response.
  ///
  /// Example:
  /// ```dart
  /// final response = await client.send(
  ///   DbRequest.query('SELECT * FROM Users WHERE Id = ?', params: [1]),
  /// );
  /// ```
  Future<DbResponse> send(DbRequest request);

  /// Closes the database connection.
  ///
  /// Should be called when the client is no longer needed to release resources.
  Future<void> close();

  /// Returns true if the client is currently connected to the database.
  bool get isConnected;
}
