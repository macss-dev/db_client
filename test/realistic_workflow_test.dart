import 'dart:io';
import 'package:db_client/db_client.dart';
import 'package:test/test.dart';
import 'helpers/odbc_tracing.dart';

/// Realistic workflow test - Replicates the exact pattern from mdm_api endpoint
///
/// This test reproduces the sequence of queries from /api/v1/desembolso/invoke-transferencia
/// that causes intermittent crashes with error: Exited (-1073740791)
///
/// Pattern:
/// 1. Query Oracle (getProductoInfoByIdPrestamo)
/// 2. Query SQL Server (getIdSolicitud)
/// 3. Query Oracle (getSaldoCuentaDesembolso)
/// 4. Query SQL Server (getDatosDesembolso)
/// 5. Repeat sequentially
///
/// The crash is intermittent - sometimes works, sometimes fails.
void main() {
  late SqlDbClient oracle;
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

    // Create connections with ODBC tracing enabled
    final oracleDriver = envVars['ORACLE_DRIVER']!;
    final oracleServer = envVars['ORACLE_SERVER']!;
    final oracleUser = envVars['ORACLE_USERNAME']!;
    final oraclePassword = envVars['ORACLE_PASSWORD']!;

    final mssqlDriver = envVars['MSSQL_DRIVER']!;
    final mssqlServer = envVars['MSSQL_SERVER']!;
    final mssqlUser = envVars['MSSQL_USERNAME']!;
    final mssqlPassword = envVars['MSSQL_PASSWORD']!;

    final oracleConfig = DbClientConfig(
      driver: oracleDriver,
      server: oracleServer.split(':')[0],
      port: 1521,
      username: oracleUser,
      password: oraclePassword,
    ).withTracing(logFilePath: r'C:\temp\odbc_trace_oracle.log');

    final mssqlConfig = DbClientConfig(
      driver: mssqlDriver,
      server: mssqlServer,
      username: mssqlUser,
      password: mssqlPassword,
      database: 'MICRO',
    ).withTracing(logFilePath: r'C:\temp\odbc_trace_mssql.log');

    print('Creating Oracle connection...');
    oracle = SqlDbClient(oracleConfig);

    print('Creating SQL Server connection...');
    mssql = SqlDbClient(mssqlConfig);

    print('🔍 ODBC Tracing enabled:');
    print(r'   Oracle log: C:\temp\odbc_trace_oracle.log');
    print(r'   SQL Server log: C:\temp\odbc_trace_mssql.log');

    // Warmup - initialize connections
    print('Warming up connections...');
    await oracle.send(DbRequest.query('SELECT 1 FROM DUAL'));
    await mssql.send(DbRequest.query('SELECT 1'));
    print('Connections ready');
  });

  tearDownAll(() async {
    // ✅ FIX TEST: Call disconnect() explicitly to test proper cleanup
    // In production, singleton pattern doesn't call close(), but for testing
    // we want to verify that proper cleanup prevents crashes
    print('Closing connections...');
    try {
      await oracle.close();
      print('  ✓ Oracle connection closed');
    } catch (e) {
      print('  ⚠️ Oracle close error: $e');
    }

    try {
      await mssql.close();
      print('  ✓ SQL Server connection closed');
    } catch (e) {
      print('  ⚠️ SQL Server close error: $e');
    }

    print('Test complete - connections closed properly');
  });

  group('Realistic Workflow Tests', () {
    test('Sequential queries - 10 iterations', () async {
      print('\n${'=' * 80}');
      print('REALISTIC WORKFLOW TEST - 10 SEQUENTIAL ITERATIONS');
      print('${'=' * 80}\n');

      for (var i = 0; i < 10; i++) {
        print('[$i] Starting iteration...');

        try {
          // Step 1: Query Oracle - getProductoInfoByIdPrestamo
          print('  [Step 1/4] Oracle: Query producto info...');
          final productoResult = await oracle.send(
            DbRequest.query(
              'SELECT IDPRODUCTO, IDTIPOPRESTAMO FROM VPRESTAMO WHERE IDPRESTAMO = 5562181',
            ),
          );
          expect(productoResult.success, isTrue);
          print('    ✓ Oracle query OK');

          // Small delay to simulate processing
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Step 2: Query SQL Server - getIdSolicitud
          print('  [Step 2/4] SQL Server: Query solicitud...');
          final solicitudResult = await mssql.send(
            DbRequest.query(
              'SELECT TOP 1 idSolicitud FROM solicitudDetalle WHERE idPrestamo = 5562181',
            ),
          );
          expect(solicitudResult.success, isTrue);
          print('    ✓ SQL Server query OK');

          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Step 3: Query Oracle - getSaldoCuentaDesembolso
          print('  [Step 3/4] Oracle: Query saldo cuenta...');
          final saldoResult = await oracle.send(
            DbRequest.query('''
SELECT c.SALDODISPONIBLE, p.MONTODESEMBOLSADO 
                 FROM VCUENTA c 
                 JOIN VPRESTAMO p ON c.IDCUENTA = p.IDCUENTADESEMBOLSO 
                 WHERE p.IDPRESTAMO = 5562181'''),
          );
          expect(saldoResult.success, isTrue);
          print('    ✓ Oracle query OK');

          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Step 4: Query SQL Server - getDatosDesembolso
          print('  [Step 4/4] SQL Server: Query datos desembolso...');
          final datosResult = await mssql.send(
            DbRequest.query('''
SELECT s.nroDni, s.nroCuenta 
                 FROM socio s 
                 JOIN solicitudDetalle sd ON s.idSocio = sd.idSocio 
                 WHERE sd.idPrestamo = 5562181'''),
          );
          expect(datosResult.success, isTrue);
          print('    ✓ SQL Server query OK');

          print('[$i] ✅ Iteration complete\n');

          // Small delay between iterations
          await Future<void>.delayed(const Duration(milliseconds: 50));
        } catch (e, stackTrace) {
          print('[$i] ❌ ERROR: $e');
          print('    Stack trace:');
          print(
              '    ${stackTrace.toString().split('\n').take(5).join('\n    ')}');
          rethrow;
        }
      }

      print('=' * 80);
      print('✅ TEST PASSED - No crashes detected');
      print('=' * 80);
    });

    test('Sequential queries with exception handling - 10 iterations',
        () async {
      print('\n${'=' * 80}');
      print('EXCEPTION HANDLING TEST - 10 ITERATIONS');
      print('${'=' * 80}\n');

      for (var i = 0; i < 10; i++) {
        print('[$i] Starting iteration with exception...');

        try {
          // Step 1: Query Oracle
          print('  [Step 1/3] Oracle query...');
          await oracle.send(
            DbRequest.query(
                'SELECT IDPRESTAMO FROM VPRESTAMO WHERE ROWNUM = 1'),
          );
          print('    ✓ Query OK');

          // Step 2: Query SQL Server
          print('  [Step 2/3] SQL Server query...');
          await mssql.send(
            DbRequest.query('SELECT TOP 1 idSolicitud FROM solicitud'),
          );
          print('    ✓ Query OK');

          // Step 3: Simulate external service error (like Ligo HTTP 400)
          print('  [Step 3/3] Simulating external service error...');
          throw Exception('Simulated external service error (HTTP 400)');
        } catch (e) {
          print('[$i] ⚠ Exception caught (expected): $e');
          // Don't rethrow - let GC clean up resources
        }

        // Force garbage collection
        List.filled(100000, 0);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        print('[$i] ✅ Exception handled, GC triggered\n');
      }

      print('=' * 80);
      print('✅ TEST PASSED - No crashes after exceptions');
      print('=' * 80);
    });

    test('Rapid sequential queries - 20 iterations', () async {
      print('\n${'=' * 80}');
      print('RAPID SEQUENTIAL TEST - 20 ITERATIONS');
      print('${'=' * 80}\n');

      for (var i = 0; i < 20; i++) {
        // Alternate between Oracle and SQL Server
        if (i % 2 == 0) {
          final result = await oracle.send(
            DbRequest.query('SELECT $i AS iteration FROM DUAL'),
          );
          expect(result.success, isTrue);
          print('[$i] Oracle query OK');
        } else {
          final result = await mssql.send(
            DbRequest.query('SELECT $i AS iteration'),
          );
          expect(result.success, isTrue);
          print('[$i] SQL Server query OK');
        }

        // Minimal delay
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      print('\n${'=' * 80}');
      print('✅ TEST PASSED - 20 rapid queries completed');
      print('=' * 80);
    });

    test('Database info queries - metadata operations', () async {
      print('\n${'=' * 80}');
      print('METADATA OPERATIONS TEST');
      print('${'=' * 80}\n');

      for (var i = 0; i < 5; i++) {
        print('[$i] Querying metadata...');

        // Oracle metadata
        print('  Oracle: database name...');
        final oracleDbName = await oracle.send(
          DbRequest.query(
              "SELECT SYS_CONTEXT('USERENV', 'DB_NAME') AS db_name FROM DUAL"),
        );
        expect(oracleDbName.success, isTrue);

        print('  Oracle: version...');
        final oracleVersion = await oracle.send(
          DbRequest.query(r'SELECT * FROM V$VERSION WHERE ROWNUM = 1'),
        );
        expect(oracleVersion.success, isTrue);

        // SQL Server metadata
        print('  SQL Server: database name...');
        final mssqlDbName = await mssql.send(
          DbRequest.query('SELECT DB_NAME() AS db_name'),
        );
        expect(mssqlDbName.success, isTrue);

        print('  SQL Server: version...');
        final mssqlVersion = await mssql.send(
          DbRequest.query('SELECT @@VERSION AS version'),
        );
        expect(mssqlVersion.success, isTrue);

        print('[$i] ✅ Metadata queries complete\n');

        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      print('=' * 80);
      print('✅ TEST PASSED - Metadata operations completed');
      print('=' * 80);
    });
  });
}
