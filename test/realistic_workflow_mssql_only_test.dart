import 'dart:io';
import 'package:db_client/db_client.dart';
import 'package:test/test.dart';

/// Realistic workflow test - SQL Server only
/// Testing if Option A (no resource cleanup) prevents crashes
void main() {
  late SqlDbClient mssql;
  
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
    
    final mssqlDriver = envVars['MSSQL_DRIVER']!;
    final mssqlServer = envVars['MSSQL_SERVER']!;
    final mssqlUser = envVars['MSSQL_USERNAME']!;
    final mssqlPassword = envVars['MSSQL_PASSWORD']!;
    
    final mssqlConfig = DbClientConfig(
      driver: mssqlDriver,
      server: mssqlServer,
      username: mssqlUser,
      password: mssqlPassword,
      database: 'MICRO',
    );
    
    print('Creating SQL Server connection...');
    mssql = SqlDbClient(mssqlConfig);
    
    print('Warming up connection...');
    await mssql.send(DbRequest.query('SELECT 1'));
    print('Connection ready');
  });
  
  // tearDownAll() commented out - Option A strategy: let OS clean up
  // tearDownAll() async {
  //   print('Closing connection...');
  //   await mssql.close();
  //   print('Connection closed');
  // }
  
  test('Sequential queries - 20 iterations', () async {
    print('\n${'=' * 80}');
    print('SQL SERVER WORKFLOW TEST - 20 ITERATIONS');
    print('${'=' * 80}\n');
    
    for (var i = 0; i < 20; i++) {
      print('[$i] Query iteration...');
      
      try {
        final result = await mssql.send(
          DbRequest.query('SELECT TOP 1 idSolicitud FROM solicitud'),
        );
        expect(result.success, isTrue);
        print('  ✓ Query OK');
        
        await Future<void>.delayed(const Duration(milliseconds: 10));
        
      } catch (e, stackTrace) {
        print('[$i] ❌ ERROR: $e');
        print('    Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n    ')}');
        rethrow;
      }
    }
    
    print('\n${'=' * 80}');
    print('✅ TEST PASSED - 20 iterations completed');
    print('${'=' * 80}');
  });
}
