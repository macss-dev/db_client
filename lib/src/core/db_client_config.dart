/// Configuration for database connection via ODBC.
class DbClientConfig {
  /// Creates a new database client configuration.
  ///
  /// [server] is the database server hostname or IP.
  /// [database] is the database name to connect to.
  /// [username] and [password] are credentials for SQL authentication.
  /// [driver] is the ODBC driver name (defaults to SQL Server driver).
  /// [port] is the server port (defaults to 1433 for SQL Server).
  /// [trustedConnection] enables Windows Authentication instead of SQL auth.
  /// [additionalParams] allows adding extra connection string parameters.
  DbClientConfig({
    required this.server,
    this.database,
    this.username,
    this.password,
    this.driver = 'ODBC Driver 17 for SQL Server',
    this.port = 1433,
    this.trustedConnection = false,
    this.additionalParams = const {},
  });

  /// Database server hostname or IP address.
  final String server;

  /// Database name to connect to.
  final String? database;

  /// Username for SQL authentication.
  final String? username;

  /// Password for SQL authentication.
  final String? password;

  /// ODBC driver name.
  final String driver;

  /// Server port number.
  final int port;

  /// Use Windows Authentication instead of SQL authentication.
  final bool trustedConnection;

  /// Additional connection string parameters.
  final Map<String, String> additionalParams;

  /// Generates the ODBC connection string from the configuration.
  String get connectionString {
    final parts = <String>[
      'DRIVER={$driver}',
      'SERVER=$server,$port', // SQL Server uses comma format
    ];

    if (database != null && database!.isNotEmpty) {
      parts.add('DATABASE=$database');
    }

    if (trustedConnection) {
      parts.add('Trusted_Connection=yes');
    } else {
      if (username != null) parts.add('UID=$username');
      if (password != null) parts.add('PWD=$password');
    }

    additionalParams.forEach((key, value) => parts.add('$key=$value'));

    return '${parts.join(';')};';
  }
}
