import 'dart:io';
import 'package:db_client/db_client.dart';
import 'package:test/test.dart';

/// Option A Validation Test
/// 
/// This test validates that v0.2.1 Option A solution eliminates heap corruption
/// by running 50 sequential queries without crashes.
/// 
/// Expected behavior:
/// - All queries execute successfully
/// - Process exits with code 0 (no heap corruption)
/// - NO tearDownAll / close() calls needed (Option A pattern)
void main() {
  late SqlDbClient db;
  
  setUpAll(() async {
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
    
    final config = DbClientConfig(
      driver: envVars['MSSQL_DRIVER']!,
      server: envVars['MSSQL_SERVER']!,
      username: envVars['MSSQL_USERNAME']!,
      password: envVars['MSSQL_PASSWORD']!,
      database: 'MICRO',
    );
    
    db = SqlDbClient(config);
    print('✅ Connection established');
  });
  
  // Option A: NO tearDownAll - let OS clean up
  
  test('50 sequential queries - Option A validation', () async {
    const iterations = 50;
    print('\n${'=' * 80}');
    print('OPTION A VALIDATION - $iterations QUERIES');
    print('Expected: Exit code 0 (no heap corruption)');
    print('${'=' * 80}\n');
    
    for (var i = 0; i < iterations; i++) {
      final result = await db.send(
        DbRequest.query('SELECT $i AS iteration'),
      );
      
      expect(result.success, isTrue);
      expect(result.rows, isNotNull);
      expect(result.rows.length, equals(1));
      
      if (i % 10 == 0) {
        print('[$i/$iterations] ✓ Queries completed');
      }
    }
    
    print('\n${'=' * 80}');
    print('✅ ALL $iterations QUERIES SUCCESSFUL');
    print('Option A validation: PASSED');
    print('${'=' * 80}');
  });
}
