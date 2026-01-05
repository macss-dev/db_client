import 'dart:io';
import 'package:db_client/db_client.dart';
import 'package:test/test.dart';

/// Test que replica EXACTAMENTE el patrón del API mdm_api
///
/// Patrón API:
/// - OracleRepository y MssqlRepository tienen _client static (singleton)
/// - Cada request crea NUEVAS instancias del repositorio
/// - Las instancias comparten el MISMO _client static
/// - NUNCA se llama close()
/// - El crash ocurre AL SALIR del proceso: Exited (-1073740940)
///
/// Este test reproduce:
/// 1. Singleton connection con lazy initialization
/// 2. Múltiples "requests" (iteraciones) que crean nuevas instancias del wrapper
/// 3. NO llamar close() - dejar que el OS limpie al salir
/// 4. Verificar si el crash ocurre al salir del test

// Simula OracleRepository con patrón singleton
class MockOracleRepository {
  static SqlDbClient? _client;
  static DbClientConfig? _config;

  static Future<SqlDbClient> get _db async {
    if (_client != null) return _client!;

    // Lazy initialization - solo primera vez
    print('  [Oracle] Initializing singleton connection...');
    _client = SqlDbClient(_getConfig());
    return _client!;
  }

  static DbClientConfig _getConfig() {
    if (_config != null) return _config!;

    final envVars = _loadEnv();
    final oracleServer = envVars['ORACLE_SERVER']!;

    _config = DbClientConfig(
      driver: envVars['ORACLE_DRIVER']!,
      server: '',
      username: envVars['ORACLE_USERNAME']!,
      password: envVars['ORACLE_PASSWORD']!,
      port: 0,
      additionalParams: {
        'DBQ': oracleServer,
      },
    );
    return _config!;
  }

  Future<List<Map<String, dynamic>>> query(String sql) async {
    final response = await (await _db).send(
      DbRequest.query(sql, errorMessage: 'Query failed'),
    );
    if (!response.success) throw Exception(response.error);
    return response.rows;
  }
}

// Simula MssqlRepository con patrón singleton
class MockMssqlRepository {
  static SqlDbClient? _client;
  static DbClientConfig? _config;

  static Future<SqlDbClient> get _db async {
    if (_client != null) return _client!;

    print('  [MSSQL] Initializing singleton connection...');
    _client = SqlDbClient(_getConfig());
    return _client!;
  }

  static DbClientConfig _getConfig() {
    if (_config != null) return _config!;

    final envVars = _loadEnv();

    _config = DbClientConfig(
      driver: envVars['MSSQL_DRIVER']!,
      server: envVars['MSSQL_SERVER']!,
      username: envVars['MSSQL_USERNAME']!,
      password: envVars['MSSQL_PASSWORD']!,
      database: 'MICRO',
    );
    return _config!;
  }

  Future<List<Map<String, dynamic>>> query(String sql) async {
    final response = await (await _db).send(
      DbRequest.query(sql, errorMessage: 'Query failed'),
    );
    if (!response.success) throw Exception(response.error);
    return response.rows;
  }
}

Map<String, String> _loadEnv() {
  final envVars = <String, String>{};
  final envFile = File('.env');
  if (envFile.existsSync()) {
    final lines = envFile.readAsLinesSync();
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
  return envVars;
}

void main() {
  group('Singleton Pattern Test - Replicate API Behavior', () {
    test('Multiple requests with singleton connections - NO close()', () async {
      print('\n${'=' * 80}');
      print('SINGLETON PATTERN TEST - REPLICATING API BEHAVIOR');
      print('${'=' * 80}\n');
      print('Pattern:');
      print('  ✓ Static singleton DbClient (shared across requests)');
      print('  ✓ New repository instances per request');
      print('  ✓ NO close() calls (connections persist until process exit)');
      print('  ✓ Test if crash occurs on exit: -1073740940\n');

      const numRequests = 5;

      for (int i = 0; i < numRequests; i++) {
        print('[$i] Simulating request $i...');

        // ✅ CRITICAL: Create NEW instances per request (like API does)
        // But they share the SAME static _client
        final oracle = MockOracleRepository();
        final mssql = MockMssqlRepository();

        try {
          // Query 1: Oracle - getProductoInfoByIdPrestamo
          print('  [$i] Oracle: Query producto info...');
          final productoResult = await oracle.query(
              'SELECT IDPRODUCTO, IDTIPOPRESTAMO FROM VPRESTAMO WHERE IDPRESTAMO = 5562181');
          expect(productoResult, isNotEmpty);
          print('    ✓ OK');

          // Query 2: SQL Server - getIdSolicitud
          print('  [$i] MSSQL: Query solicitud...');
          final solicitudResult = await mssql.query(
              'SELECT TOP 1 idSolicitud FROM solicitudDetalle WHERE idPrestamoBestErp = 5562181');
          expect(solicitudResult, isNotEmpty);
          print('    ✓ OK');

          // Query 3: Oracle - getSaldoCuentaDesembolso
          print('  [$i] Oracle: Query saldo...');
          final saldoResult = await oracle.query(
              'SELECT MTOCAP FROM VAHORRO WHERE IDAHORRO IN (SELECT IDCUENTADESEMBOLSO FROM VPRESTAMO WHERE IDPRESTAMO = 5562181)');
          expect(saldoResult, isNotEmpty);
          print('    ✓ OK');

          // Query 4: SQL Server - getDatosDesembolso
          print('  [$i] MSSQL: Query datos desembolso...');
          final datosResult = await mssql.query(
              'SELECT TOP 1 dni, nroCuenta FROM solicitudDetalle WHERE idPrestamoBestErp = 5562181');
          expect(datosResult, isNotEmpty);
          print('    ✓ OK');

          print('[$i] ✅ Request completed\n');
        } catch (e, stackTrace) {
          print('[$i] ❌ Error: $e');
          print(stackTrace);
          rethrow;
        }

        // Pequeña pausa entre "requests"
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      print('${'=' * 80}');
      print('✅ ALL REQUESTS COMPLETED SUCCESSFULLY');
      print('   Processed: $numRequests requests');
      print('   Singleton connections: Still open (never closed)');
      print('${'=' * 80}\n');
      print('⚠️  CRITICAL TEST:');
      print('   If test exits with code -1073740940 → singleton pattern issue');
      print('   If test exits with code 0 → all good!\n');

      // ✅ KEY DIFFERENCE: NO close() calls
      // Connections stay open until process terminates
      // This replicates production API behavior
      print('⏳ Exiting test - connections will be cleaned by OS...\n');
    });

    test('Multiple requests with EXPLICIT close() - Control Test', () async {
      print('\n${'=' * 80}');
      print('CONTROL TEST - WITH EXPLICIT close()');
      print('${'=' * 80}\n');

      const numRequests = 3;

      for (int i = 0; i < numRequests; i++) {
        print('[$i] Simulating request $i...');

        final oracle = MockOracleRepository();
        // final mssql = MockMssqlRepository();

        // Simple query
        final result = await oracle.query('SELECT 1 FROM DUAL');
        expect(result, isNotEmpty);
        print('[$i] ✅ Request completed\n');

        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      // Now explicitly close connections
      print('🔒 Explicitly closing singleton connections...');
      if (MockOracleRepository._client != null) {
        await MockOracleRepository._client!.close();
        print('  ✓ Oracle closed');
      }
      if (MockMssqlRepository._client != null) {
        await MockMssqlRepository._client!.close();
        print('  ✓ MSSQL closed');
      }

      print('\n⏳ Exiting test after explicit close()...\n');
    }, skip: true); // Skip by default - only run for comparison
  });
}
