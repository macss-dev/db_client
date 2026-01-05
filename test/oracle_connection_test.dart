import 'dart:io';
import 'package:db_client/db_client.dart';
import 'package:test/test.dart';

/// Oracle Connection Test
/// 
/// Validates the Oracle connection pattern using DbClientConfig with DBQ parameter.
/// This test demonstrates the correct way to connect to Oracle using additionalParams.
void main() {
  late SqlDbClient oracle;
  
  setUpAll(() async {
    // Load environment variables from .env file
    final envVars = <String, String>{};
    final envFile = File('.env');
    if (envFile.existsSync()) {
      final lines = await envFile.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty || line.startsWith('#')) continue;
        final parts = line.split('=');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final value = parts[1].trim().replaceAll("'", '');
          envVars[key] = value;
        }
      }
    }
    
    print('Creating Oracle connection using DbClientConfig...');
    
    // ✅ CORRECT PATTERN for Oracle with DbClientConfig
    // Use empty server, port 0, and DBQ in additionalParams
    final oracleConfig = DbClientConfig(
      server: '',  // Empty - Oracle ignores this
      port: 0,     // 0 - not used for Oracle
      driver: envVars['ORACLE_DRIVER']!,
      username: envVars['ORACLE_USERNAME']!,
      password: envVars['ORACLE_PASSWORD']!,
      additionalParams: {
        'DBQ': envVars['ORACLE_SERVER']!,  // Oracle Easy Connect format: host:port/service
      },
    );
    
    oracle = SqlDbClient(oracleConfig);
    print('✅ Oracle connection established');
  });
  
  // Option A: NO tearDownAll - resources cleaned up by OS on process exit
  
  test('Oracle - Simple query', () async {
    print('\nExecuting Oracle query...');
    
    final result = await oracle.send(
      DbRequest.query('SELECT 1 FROM DUAL'),
    );
    
    expect(result.success, isTrue);
    expect(result.rows, isNotNull);
    expect(result.rows.length, equals(1));
    
    print('✅ Oracle query successful');
  });
  
  test('Oracle - Database name query', () async {
    print('\nQuerying Oracle database name...');
    
    final result = await oracle.send(
      DbRequest.query(
        "SELECT SYS_CONTEXT('USERENV', 'DB_NAME') AS db_name FROM DUAL",
      ),
    );
    
    expect(result.success, isTrue);
    expect(result.rows, isNotNull);
    expect(result.rows.length, equals(1));
    
    print('Database: ${result.rows[0]}');
    print('✅ Oracle metadata query successful');
  });
  
  test('Oracle - 20 sequential queries', () async {
    print('\n${'=' * 80}');
    print('ORACLE VALIDATION - 20 SEQUENTIAL QUERIES');
    print('${'=' * 80}\n');
    
    for (var i = 0; i < 20; i++) {
      final result = await oracle.send(
        DbRequest.query('SELECT $i AS iteration FROM DUAL'),
      );
      
      expect(result.success, isTrue);
      expect(result.rows, isNotNull);
      
      if (i % 5 == 0) {
        print('[$i/20] ✓ Queries completed');
      }
      
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    
    print('\n${'=' * 80}');
    print('✅ ALL 20 QUERIES SUCCESSFUL');
    print('${'=' * 80}');
  });
}
