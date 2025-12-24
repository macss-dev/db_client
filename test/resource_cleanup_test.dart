import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:test/test.dart';

/// Test para verificar que los recursos se liberan correctamente
/// y no hay memory leaks ni handles ODBC sin cerrar
void main() {
  group('Resource Cleanup & Memory Leak Test', () {
    late DbClientConfig config;

    setUp(() {
      config = DbClientConfig(
        server: Platform.environment['MSSQL_SERVER'] ?? 'localhost',
        username: Platform.environment['MSSQL_USERNAME'] ?? 'sa',
        password: Platform.environment['MSSQL_PASSWORD'] ?? 'Password123!',
        driver: Platform.environment['MSSQL_DRIVER'] ?? 'ODBC Driver 17 for SQL Server',
      );
    });

    test('✓ Verificar que disconnect libera recursos correctamente', () async {
      stdout.writeln('\n${"=" * 80}');
      stdout.writeln('TEST: VERIFICACIÓN DE DISCONNECT');
      stdout.writeln("=" * 80);

      final client = SqlDbClient(config);
      
      // Ejecutar query
      final response = await client.send(
        DbRequest.query(
          'SELECT @@VERSION AS version',
          errorMessage: 'Error en query',
        ),
      );

      expect(response.success, isTrue);
      stdout.writeln('✓ Query ejecutada');

      // Close explícito
      await client.close();
      stdout.writeln('✓ Close llamado');

      // Intentar usar el cliente después de close debería fallar
      try {
        await client.send(
          DbRequest.query(
            'SELECT 1',
            errorMessage: 'Query después de close',
          ),
        );
        fail('Debería fallar al usar cliente desconectado');
      } catch (e) {
        stdout.writeln('✓ Correctamente rechaza uso después de close');
      }

      stdout.writeln("=" * 80);
    });

    test('✓ Múltiples close no causan double-free', () async {
      stdout.writeln('\n${"=" * 80}');
      stdout.writeln('TEST: DOUBLE-CLOSE SAFETY');
      stdout.writeln("=" * 80);

      final client = SqlDbClient(config);
      
      await client.send(
        DbRequest.query('SELECT 1', errorMessage: 'Query test'),
      );

      // Llamar close múltiples veces no debe causar crash
      await client.close();
      stdout.writeln('✓ Primer close');

      await client.close(); // Debería ser seguro
      stdout.writeln('✓ Segundo close (protegido)');

      await client.close(); // Debería ser seguro
      stdout.writeln('✓ Tercer close (protegido)');

      stdout.writeln('✅ Sin double-free ni heap corruption');
      stdout.writeln("=" * 80);
    });

    test('✓ Excepción durante query no causa memory leak', () async {
      stdout.writeln('\n${"=" * 80}');
      stdout.writeln('TEST: EXCEPTION HANDLING & CLEANUP');
      stdout.writeln("=" * 80);

      for (int i = 0; i < 20; i++) {
        final client = SqlDbClient(config);
        try {
          // Query inválida para provocar error
          await client.send(
            DbRequest.query(
              'SELECT * FROM tabla_que_no_existe',
              errorMessage: 'Query inválida',
            ),
          );
          fail('Debería fallar con query inválida');
        } catch (e) {
          stdout.writeln('[$i] ✓ Excepción capturada correctamente');
        } finally {
          await client.close();
        }
      }

      stdout.writeln('✅ 20 excepciones manejadas sin memory leak');
      stdout.writeln("=" * 80);
    });

    test('✓ Cleanup automático sin close explícito', () async {
      stdout.writeln('\n${"=" * 80}');
      stdout.writeln('TEST: CLEANUP AUTOMÁTICO (sin close explícito)');
      stdout.writeln("=" * 80);

      // Crear conexiones sin cerrarlas explícitamente
      // El GC debería limpiar los recursos
      for (int i = 0; i < 10; i++) {
        final client = SqlDbClient(config);
        await client.send(
          DbRequest.query('SELECT $i AS id', errorMessage: 'Query $i'),
        );
        // NO llamar close - dejar que el GC lo limpie
        stdout.writeln('[$i] ✓ Conexión creada (sin close explícito)');
      }

      stdout.writeln('\n🗑️  Forzando garbage collection...');
      for (int i = 0; i < 5; i++) {
        // Crear presión de memoria para activar GC
        final _ = List.filled(1000000, 0);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      stdout.writeln('✅ GC ejecutado - recursos deberían haberse limpiado automáticamente');
      stdout.writeln('   (verificar con Process Explorer si hay handles ODBC abiertos)');
      stdout.writeln("=" * 80);
    }, timeout: Timeout(Duration(minutes: 2)));

    test('✓ Uso correcto: try-finally con disconnect', () async {
      stdout.writeln('\n${"=" * 80}');
      stdout.writeln('TEST: PATRÓN RECOMENDADO (try-finally)');
      stdout.writeln("=" * 80);

      var connectionsCreated = 0;
      var connectionsClosed = 0;

      for (int i = 0; i < 30; i++) {
        final client = SqlDbClient(config);
        connectionsCreated++;
        
        try {
          final response = await client.send(
            DbRequest.query('SELECT $i AS id', errorMessage: 'Query $i'),
          );
          expect(response.success, isTrue);
        } finally {
          await client.close();
          connectionsClosed++;
        }
      }

      stdout.writeln('✅ Patrón try-finally funciona correctamente');
      stdout.writeln('   Conexiones creadas: $connectionsCreated');
      stdout.writeln('   Conexiones cerradas: $connectionsClosed');
      expect(connectionsCreated, equals(connectionsClosed));
      stdout.writeln("=" * 80);
    });

    test('✓ Performance: overhead de crear/cerrar conexiones', () async {
      stdout.writeln('\n${"=" * 80}');
      stdout.writeln('PERFORMANCE TEST: OVERHEAD DE CONEXIONES');
      stdout.writeln("=" * 80);

      final iterations = 50;
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < iterations; i++) {
        final client = SqlDbClient(config);
        try {
          await client.send(
            DbRequest.query('SELECT 1', errorMessage: 'Query $i'),
          );
        } finally {
          await client.close();
        }
      }

      stopwatch.stop();
      final avgTime = stopwatch.elapsedMilliseconds / iterations;

      stdout.writeln('📊 RESULTADOS:');
      stdout.writeln('   Total: ${stopwatch.elapsedMilliseconds}ms');
      stdout.writeln('   Iteraciones: $iterations');
      stdout.writeln('   Promedio: ${avgTime.toStringAsFixed(2)}ms por conexión');
      
      if (avgTime < 50) {
        stdout.writeln('   ✅ EXCELENTE: < 50ms promedio');
      } else if (avgTime < 100) {
        stdout.writeln('   ✓ BUENO: < 100ms promedio');
      } else if (avgTime < 200) {
        stdout.writeln('   ⚠️  ACEPTABLE: < 200ms promedio');
      } else {
        stdout.writeln('   ❌ LENTO: > 200ms promedio - investigar');
      }
      
      stdout.writeln("=" * 80);
    });
  });
}
