/// Represents the response from a database operation.
class DbResponse {
  /// Creates a new database response.
  const DbResponse({
    required this.success,
    required this.rows,
    this.rowsAffected = 0,
    this.error,
  });

  /// Creates a successful response with rows.
  factory DbResponse.ok(List<Map<String, dynamic>> rows) {
    return DbResponse(
      success: true,
      rows: rows,
      rowsAffected: rows.length,
    );
  }

  /// Creates a failed response with an error message.
  factory DbResponse.fail(String error) {
    return DbResponse(
      success: false,
      rows: const [],
      error: error,
    );
  }

  /// Whether the operation was successful.
  final bool success;

  /// The rows returned by the query.
  final List<Map<String, dynamic>> rows;

  /// Number of rows affected by the operation.
  final int rowsAffected;

  /// Error message if the operation failed.
  final String? error;

  /// Returns the first row or null if no rows were returned.
  Map<String, dynamic>? get firstOrNull => rows.isNotEmpty ? rows.first : null;

  /// Returns the last row or null if no rows were returned.
  Map<String, dynamic>? get lastOrNull => rows.isNotEmpty ? rows.last : null;

  /// Returns true if there are no rows.
  bool get isEmpty => rows.isEmpty;

  /// Returns true if there are rows.
  bool get isNotEmpty => rows.isNotEmpty;

  /// Returns a scalar value from the first column of the first row.
  ///
  /// Useful for queries like `SELECT COUNT(*) FROM Users`.
  ///
  /// Example:
  /// ```dart
  /// final count = response.scalar<int>() ?? 0;
  /// ```
  T? scalar<T>() {
    if (rows.isEmpty) return null;
    final first = rows.first;
    if (first.isEmpty) return null;
    final value = first.values.first;
    if (value is T) return value;
    // Try to convert string to the requested type
    if (value is String) {
      if (T == int) return int.tryParse(value) as T?;
      if (T == double) return double.tryParse(value) as T?;
      if (T == bool) return (value.toLowerCase() == 'true') as T?;
    }
    return value as T?;
  }

  @override
  String toString() {
    if (success) {
      return 'DbResponse.ok(rows: ${rows.length}, rowsAffected: $rowsAffected)';
    }
    return 'DbResponse.fail(error: $error)';
  }
}
