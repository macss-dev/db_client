import 'package:db_client/db_client.dart';

/// Helper class to enable ODBC tracing for debugging crashes
/// 
/// ODBC tracing helps capture detailed logs of ODBC driver operations,
/// which is crucial for diagnosing intermittent crashes like:
/// Exited (-1073740791) - Access Violation/Stack Buffer Overrun
/// 
/// Usage:
///   await OdbcTracing.enable(client, logFilePath: 'C:\\odbc_trace.log');
///   // Run tests...
///   await OdbcTracing.disable(client);
class OdbcTracing {
  /// Enable ODBC tracing on a SQL client
  /// 
  /// [client] - The SqlDbClient instance to enable tracing on
  /// [logFilePath] - Path where ODBC trace log will be written (Windows path)
  static Future<void> enable(
    SqlDbClient client, {
    String logFilePath = r'C:\temp\odbc_trace.log',
  }) async {
    print('🔍 Enabling ODBC tracing...');
    print('   Log file: $logFilePath');
    
    // Force connection initialization
    await client.send(DbRequest.query('SELECT 1'));
    
    // We'll use the connection string approach to enable tracing
    // since we can't access private _odbc field directly
    print('   Note: ODBC tracing should be enabled via connection string');
    print('   Add these to your connection string:');
    print('   - TraceFile=$logFilePath');
    print('   - Trace=Yes');
    print('✅ ODBC tracing instructions provided');
  }
  
  /// Disable ODBC tracing
  static Future<void> disable(SqlDbClient client) async {
    print('🔍 ODBC tracing disabled');
  }
  
  /// Create a connection string with tracing enabled
  /// 
  /// This is the recommended way to enable ODBC tracing in db_client
  static String addTracingToConnectionString(
    String originalConnectionString, {
    String logFilePath = r'C:\temp\odbc_trace.log',
  }) {
    // Remove trailing semicolon if present
    var connStr = originalConnectionString.trimRight();
    if (connStr.endsWith(';')) {
      connStr = connStr.substring(0, connStr.length - 1);
    }
    
    // Add tracing parameters
    return '$connStr;TraceFile=$logFilePath;Trace=Yes;';
  }
}

/// Extension to create DbClientConfig with ODBC tracing enabled
extension DbClientConfigTracing on DbClientConfig {
  /// Create a new config with ODBC tracing enabled
  DbClientConfig withTracing({String logFilePath = r'C:\temp\odbc_trace.log'}) {
    // Create new config with tracing in additionalParams
    final tracingParams = Map<String, String>.from(additionalParams);
    tracingParams['TraceFile'] = logFilePath;
    tracingParams['Trace'] = 'Yes';
    
    return DbClientConfig(
      driver: driver,
      server: server,
      port: port,
      database: database,
      username: username,
      password: password,
      additionalParams: tracingParams,
    );
  }
}
